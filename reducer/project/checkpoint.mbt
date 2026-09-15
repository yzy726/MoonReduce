///|
priv struct SavedFile {
  path : String
  bytes : Array[Int]
} derive(ToJson, @json.FromJson)

///|
priv struct Checkpoint {
  score_mode : String
  names : Array[String]
  policies : Array[Int]
  consecutive : Bool
  baseline_trials : Array[Bool?]
  schema_version : Int
  engine_version : String
  original_key : String
  context : String
  targets : Array[String]
  files : Array[SavedFile]
  state : Int
  pass_index : Int
  sequence : Int
  evaluations : Int
  hits : Int
  baseline : Int
  finals : Int
  status : String
  cache : Array[(String, Bool)]
} derive(ToJson, @json.FromJson)

///|
/// Serialize a settled batch boundary. The caller supplies a canonical context
/// containing predicate configuration and toolchain identity. Pending work must
/// finish or use the previously saved boundary; it is never marked evaluated.
pub fn Session::checkpoint(
  self : Session,
  original : @manifest.Snapshot,
  context : String,
) -> Result[Json, String] {
  if !self.pending.is_empty() {
    return Err("MR_CHECKPOINT_PENDING: settle batch before saving")
  }
  let saved : Checkpoint = {
    score_mode: self.score_mode,
    names: self.names.copy(),
    policies: [
      self.candidate_policy.repeat,
      self.candidate_policy.quorum,
      self.final_policy.repeat,
      self.final_policy.quorum,
      self.command_cost,
    ],
    consecutive: self.candidate_policy.consecutive,
    baseline_trials: self.baseline_trials.copy(),
    schema_version: 4,
    engine_version: "project-v4",
    original_key: original.key(),
    context,
    targets: self.targets.copy(),
    files: self.best
    .files()
    .map(f => { path: f.0, bytes: f.1.iter().map(b => b.to_int()).to_array() }),
    state: self.state,
    pass_index: self.pass_index,
    sequence: self.sequence,
    evaluations: self.evaluations,
    hits: self.hits,
    baseline: self.baseline,
    finals: self.finals,
    status: self.status.to_json().stringify(),
    cache: self.cache.iter().to_array(),
  }
  Ok(ToJson::to_json(saved))
}

///|
/// Restore validated state and rebuild its lazy pass iterator. Completed cache
/// entries suppress re-execution; final verification is always performed anew.
/// The supplied total budget may be enlarged, but must cover work already done.
pub fn Session::restore(
  document : Json,
  original : @manifest.Snapshot,
  includes : Array[String],
  protects : Array[String],
  ignores : Array[String],
  context : String,
  max_tests? : Int = 2500,
  repeat? : Int = 1,
  quorum? : Int = 1,
  consecutive? : Bool = false,
  final_repeat? : Int = 3,
  final_quorum? : Int = 3,
  command_cost? : Int = 1,
  score? : String = "bytes",
  pass_include? : Array[String] = [],
  pass_exclude? : Array[String] = [],
  extra_passes? : Array[&@pass_api.ReductionPass] = [],
) -> Result[Session, String] {
  let saved : Checkpoint = @json.from_json(document) catch {
    _ => return Err("MR_CHECKPOINT_FORMAT: malformed checkpoint")
  }
  if saved.schema_version != 4 || saved.engine_version != "project-v4" {
    return Err("MR_CHECKPOINT_VERSION: incompatible checkpoint")
  }
  if saved.original_key != original.key() || saved.context != context {
    return Err(
      "MR_CHECKPOINT_CONTEXT: input, configuration or toolchain changed",
    )
  }
  let session = match
    Session::new(
      original,
      includes,
      protects,
      ignores,
      max_tests~,
      repeat~,
      quorum~,
      consecutive~,
      final_repeat~,
      final_quorum~,
      command_cost~,
      score~,
      pass_include~,
      pass_exclude~,
      extra_passes~,
    ) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  if saved.policies !=
    [repeat, quorum, final_repeat, final_quorum, command_cost] ||
    saved.consecutive != consecutive {
    return Err("MR_CHECKPOINT_CONTEXT: stability policy changed")
  }
  if saved.score_mode != score || saved.names != session.names {
    return Err("MR_CHECKPOINT_CONTEXT: score or passes changed")
  }
  if saved.targets != session.targets {
    return Err("MR_CHECKPOINT_CONTEXT: selection changed")
  }
  if saved.state < 0 ||
    saved.state > 3 ||
    saved.pass_index < 0 ||
    saved.pass_index > session.names.length() ||
    saved.evaluations < 0 ||
    saved.evaluations > max_tests - final_repeat * command_cost ||
    saved.sequence < 0 ||
    saved.sequence > 100000000 ||
    saved.hits < 0 ||
    saved.baseline < 0 ||
    saved.baseline > session.baseline_policy.repeat ||
    saved.finals < 0 ||
    saved.finals > final_repeat ||
    saved.cache.length() > saved.evaluations ||
    saved.files.length() > 1000 {
    return Err("MR_CHECKPOINT_STATE: invalid state or insufficient budget")
  }
  if saved.baseline_trials.length() > session.baseline_policy.repeat ||
    saved.baseline_trials.filter(v => v == Some(true)).length() !=
    saved.baseline {
    return Err("MR_CHECKPOINT_STATE: invalid baseline evidence")
  }
  let baseline_complete = session.baseline_policy.decide(saved.baseline_trials) ==
    Interesting
  if !baseline_complete &&
    max_tests <
    saved.evaluations +
    (session.baseline_policy.repeat + final_repeat) * command_cost {
    return Err("MR_CHECKPOINT_STATE: insufficient baseline retry budget")
  }
  let files : Array[(String, Bytes)] = []
  let mut size = 0
  for f in saved.files {
    size += f.bytes.length()
    if f.bytes.length() > 1048576 || size > 16777216 {
      return Err("MR_CHECKPOINT_SIZE: snapshot exceeds limits")
    }
    let bytes : Array[Byte] = Array::make(f.bytes.length(), 0)
    for i in 0..<f.bytes.length() {
      if f.bytes[i] < 0 || f.bytes[i] > 255 {
        return Err("MR_CHECKPOINT_FORMAT: invalid byte")
      }
      bytes[i] = f.bytes[i].to_byte()
    }
    files.push((f.path, Bytes::from_array(bytes)))
  }
  let best = match @manifest.Snapshot::new(files) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let initial = original.files()
  for f in best.files() {
    if !initial.iter().any(o => o.0 == f.0) {
      return Err("MR_CHECKPOINT_PATH: unknown file")
    }
  }
  for f in initial {
    if !session.targets.contains(f.0) && !best.files().contains(f) {
      return Err("MR_CHECKPOINT_PROTECTED: protected content changed")
    }
  }
  if best.key() != original.key() && !better(score, best, original) {
    return Err("MR_CHECKPOINT_SCORE: snapshot is not reduced")
  }
  session.best = best
  session.pass_index = saved.pass_index
  session.sequence = saved.sequence
  session.evaluations = saved.evaluations
  session.hits = saved.hits
  session.baseline = saved.baseline
  session.finals = 0
  // Interrupted baseline is repeated; completed baseline is preserved.
  session.state = if !baseline_complete {
    0
  } else if saved.state == 2 {
    2
  } else if saved.state == 3 &&
    saved.status == @model.RunStatus::Completed.to_json().stringify() {
    2
  } else {
    1
  }
  if session.state == 0 {
    session.baseline = 0
  } else {
    session.baseline_trials.append(saved.baseline_trials)
  }
  for entry in saved.cache {
    if session.cache.contains(entry.0) {
      return Err("MR_CHECKPOINT_CACHE: duplicate key")
    }
    session.cache[entry.0] = entry.1
  }
  Ok(session)
}
