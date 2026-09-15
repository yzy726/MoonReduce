///|
/// Snapshot request with a stable run-local sequence number.
pub(all) struct Candidate {
  id : Int
  snapshot : @manifest.Snapshot
}

///|
pub(all) struct ResultSummary {
  best : @manifest.Snapshot
  status : @model.RunStatus
  evaluations : Int
  cache_hits : Int
  baseline_passed : Int
  final_passed : Int
}

///|
/// Pure deterministic project session. Batch width is always four regardless
/// of worker count; all replies are committed together, by score then id.
pub struct Session {
  priv mut best : @manifest.Snapshot
  priv targets : Array[String]
  priv score_mode : String
  priv command_cost : Int
  priv max_tests : Int
  priv candidate_policy : @stability.Policy
  priv baseline_policy : @stability.Policy
  priv final_policy : @stability.Policy
  priv baseline_trials : Array[Bool?]
  priv final_trials : Array[Bool?]
  priv mut state : Int
  priv mut pass_index : Int
  priv names : Array[String]
  priv extensions : Map[String, &@pass_api.ReductionPass]
  priv mut queue : Iter[@manifest.Snapshot]
  priv mut ready : Bool
  priv pending : Array[Candidate]
  priv answers : Map[Int, Bool?]
  priv cache : Map[String, Bool]
  priv mut sequence : Int
  priv mut evaluations : Int
  priv mut hits : Int
  priv mut baseline : Int
  priv mut finals : Int
  priv mut status : @model.RunStatus
}

///|
pub fn Session::new(
  original : @manifest.Snapshot,
  includes : Array[String],
  protects : Array[String],
  ignores : Array[String],
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
  if command_cost < 1 || command_cost > 2 {
    return Err("MR_CFG_COST: expected one or two commands")
  }
  let candidate_policy = match
    @stability.Policy::new(repeat, quorum, consecutive~) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let baseline_policy = match
    @stability.Policy::new(
      repeat.max(2),
      if repeat == 1 {
        2
      } else {
        quorum
      },
      consecutive~,
    ) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  if final_repeat < 3 {
    return Err(
      "MR_CFG_STABILITY: final verification needs at least three executions",
    )
  }
  let final_policy = match
    @stability.Policy::new(final_repeat, final_quorum, consecutive~) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  if max_tests < (baseline_policy.repeat + final_repeat) * command_cost {
    return Err("MR_CFG_BUDGET: insufficient baseline and final budget")
  }
  let targets = match @manifest.select(original, includes, protects, ignores) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  if !["bytes", "tokens", "lines"].contains(score) {
    return Err("MR_CFG_SCORE: invalid strategy")
  }
  let available = pass_names()
  let extensions : Map[String, &@pass_api.ReductionPass] = Map([])
  for pass in extra_passes {
    let name = pass.name()
    if name.is_empty() || name.length() > 128 || extensions.contains(name) {
      return Err("MR_CFG_PASS: invalid or duplicate extension name")
    }
    extensions[name] = pass
    if !available.contains(name) {
      available.push(name)
    }
  }
  for name in pass_include + pass_exclude {
    if !available.contains(name) {
      return Err("MR_CFG_PASS: unknown pass " + name)
    }
  }
  let names = available.filter(name => {
    (if pass_include.is_empty() {
      name != "struct:format" && name != "manifest"
    } else {
      pass_include.contains(name)
    }) &&
    !pass_exclude.contains(name)
  })
  if names.contains("package") || names.contains("manifest") {
    match
      @manifest.select_manifests(
        original,
        includes,
        protects,
        ignores,
        include_root=names.contains("manifest"),
      ) {
      Ok(paths) => targets.append(paths)
      Err(e) => return Err(e)
    }
  }
  Ok({
    best: original,
    extensions,
    targets,
    max_tests,
    command_cost,
    score_mode: score,
    candidate_policy,
    baseline_policy,
    final_policy,
    baseline_trials: [],
    final_trials: [],
    names,
    state: 0,
    pass_index: 0,
    queue: [].iter(),
    ready: false,
    pending: [],
    answers: Map([]),
    cache: Map([]),
    sequence: 0,
    evaluations: 0,
    hits: 0,
    baseline: 0,
    finals: 0,
    status: Completed,
  })
}

///|
pub fn pass_names() -> Array[String] {
  let names = ["package", "file", "manifest"]
  names.append(@structured.names().map(n => "struct:" + n))
  names.append(@text.names().map(n => "text:" + n))
  names.append(@token.names().map(n => "token:" + n))
  names
}

///|
fn better(
  strategy : String,
  a : @manifest.Snapshot,
  b : @manifest.Snapshot,
) -> Bool {
  @score.compare(strategy, @score.measure(a), @score.measure(b)) == Ok(-1)
}

///|
fn candidates(
  name : String,
  snapshot : @manifest.Snapshot,
  targets : Array[String],
) -> Iter[@manifest.Snapshot] {
  if name == "package" {
    return package_candidates(snapshot, targets)
  }
  let files = snapshot
    .files()
    .filter(f => {
      targets.contains(f.0) &&
      (if name == "manifest" {
        !f.0.has_suffix(".mbt")
      } else {
        f.0.has_suffix(".mbt")
      })
    })
  files
  .iter()
  .flat_map(file => {
    if name == "file" {
      match snapshot.remove(file.0) {
        Ok(s) => [s].iter()
        Err(_) => [].iter()
      }
    } else {
      let source = match @source.decode(file.1) {
        Ok(s) => s
        Err(_) => ""
      }
      let proposals = if name == "manifest" {
        let parts = file.0.split("/").to_array()
        @manifest_pass.propose(parts[parts.length() - 1].to_owned(), source).iter()
      } else if name.has_prefix("struct:") {
        @structured.propose_iter(
          name[7:].to_owned(),
          source,
          allow_format=name == "struct:format",
        )
      } else if name.has_prefix("text:") {
        @text.propose_iter(name[5:].to_owned(), source)
      } else {
        @token.propose_iter(name[6:].to_owned(), source)
      }
      proposals.filter_map(s => {
        match snapshot.replace(file.0, @source.encode(s)) {
          Ok(s) => Some(s)
          Err(_) => None
        }
      })
    }
  })
}

///|
pub fn Session::phase(self : Session) -> String {
  match self.state {
    0 => "baseline"
    1 => "reducing"
    2 => "final"
    _ => "stopped"
  }
}

///|
fn Session::issue(self : Session, snapshot : @manifest.Snapshot) -> Unit {
  self.sequence += 1
  self.pending.push({ id: self.sequence, snapshot })
}

///|
/// Get the stable pending batch. Native drivers may evaluate it sequentially
/// or with workers, but must return every issued result before the next batch.
pub fn Session::next_batch(self : Session) -> Array[Candidate] {
  if self.state == 3 {
    return []
  }
  if !self.pending.is_empty() {
    return self.pending.copy()
  }
  if self.state == 0 || self.state == 2 {
    self.issue(self.best)
    return self.pending.copy()
  }
  while self.state == 1 {
    if self.evaluations + self.candidate_policy.repeat * self.command_cost >
      self.max_tests - self.final_policy.repeat * self.command_cost {
      self.status = BudgetExhausted
      self.state = 2
      break
    }
    if self.pass_index >= self.names.length() {
      self.state = 2
      break
    }
    if !self.ready {
      let name = self.names[self.pass_index]
      self.queue = match self.extensions.get(name) {
        Some(pass) =>
          pass
          .propose(self.best, self.targets.copy())
          .filter(s => allowed_edit(self.best, s, self.targets))
        None => candidates(name, self.best, self.targets)
      }
      self.ready = true
    }
    let width = (4).min(
      (
        self.max_tests -
        self.final_policy.repeat * self.command_cost -
        self.evaluations
      ) /
      (self.candidate_policy.repeat * self.command_cost),
    )
    while self.pending.length() < width {
      let candidate = match self.queue.next() {
        Some(s) => s
        None => break
      }
      if !better(self.score_mode, candidate, self.best) {
        continue
      }
      let key = candidate.key()
      if self.cache.get(key) is Some(matched) {
        self.hits += 1
        if matched {
          self.best = candidate
          self.ready = false
          break
        }
        continue
      }
      if self.pending.iter().any(c => c.snapshot.key() == key) {
        continue
      }
      self.issue(candidate)
    }
    if !self.pending.is_empty() {
      return self.pending.copy()
    }
    if self.ready {
      self.pass_index += 1
      self.ready = false
    }
  }
  if self.state == 2 {
    self.issue(self.best)
  }
  self.pending.copy()
}

///|
/// Reject unknown/duplicate replies. A batch's completion order never decides
/// its winner; the smallest score wins, then the first stable candidate id.
pub fn Session::record_result(
  self : Session,
  id : Int,
  matched : Bool?,
  cost? : Int = 1,
) -> Result[Unit, String] {
  let expected_cost = if self.state == 1 {
    self.candidate_policy.repeat * self.command_cost
  } else {
    self.command_cost
  }
  if cost != expected_cost {
    return Err("MR_ENGINE_COST: inconsistent command count")
  }
  if self.state == 3 ||
    !self.pending.iter().any(c => c.id == id) ||
    self.answers.contains(id) {
    return Err("MR_ENGINE_REPLY: unknown or duplicate candidate")
  }
  self.answers[id] = matched
  self.evaluations += cost
  if self.answers.length() < self.pending.length() {
    return Ok(())
  }
  if self.state == 0 || self.state == 2 {
    let baseline = self.state == 0
    let policy = if baseline { self.baseline_policy } else { self.final_policy }
    let trials = if baseline { self.baseline_trials } else { self.final_trials }
    trials.push(matched)
    if matched == Some(true) {
      if baseline {
        self.baseline += 1
      } else {
        self.finals += 1
      }
    }
    let padded = trials.copy()
    while padded.length() < policy.repeat {
      padded.push(None)
    }
    let decision = policy.decide(padded)
    if decision == Uninteresting || trials.length() == policy.repeat {
      if decision == Interesting {
        self.state = if baseline { 1 } else { 3 }
      } else {
        self.status = if !baseline {
          FinalFailed
        } else if self.baseline == 0 {
          BaselineFailed
        } else {
          BaselineUnstable
        }
        self.state = 3
      }
    }
  } else {
    let mut chosen : @manifest.Snapshot? = None
    for c in self.pending {
      let result = self.answers.get(c.id).unwrap_or(None)
      if result is Some(value) {
        self.cache[c.snapshot.key()] = value
      }
      if result == Some(true) && better(self.score_mode, c.snapshot, self.best) {
        match chosen {
          None => chosen = Some(c.snapshot)
          Some(previous) if better(self.score_mode, c.snapshot, previous) =>
            chosen = Some(c.snapshot)
          _ => ()
        }
      }
    }
    if chosen is Some(snapshot) {
      self.best = snapshot
      self.ready = false
    }
  }
  self.pending.clear()
  self.answers.clear()
  Ok(())
}

///|
pub fn Session::stop(self : Session, status : @model.RunStatus) -> Unit {
  self.status = status
  self.state = 3
  self.pending.clear()
  self.answers.clear()
}

///|
pub fn Session::result(self : Session) -> ResultSummary {
  {
    best: self.best,
    status: self.status,
    evaluations: self.evaluations,
    cache_hits: self.hits,
    baseline_passed: self.baseline,
    final_passed: self.finals,
  }
}

///|
/// Compatibility adapter for deterministic evaluators. In repeated mode the
/// caller is responsible for evaluating the configured number of commands.
pub fn Session::record(
  self : Session,
  id : Int,
  matched : Bool,
) -> Result[Unit, String] {
  self.record_result(
    id,
    Some(matched),
    cost=(if self.state == 1 { self.candidate_policy.repeat } else { 1 }) *
      self.command_cost,
  )
}

///|
/// Baseline success rate and confidence from actual command observations.
pub fn Session::baseline_statistics(self : Session) -> @stability.Statistics {
  @stability.summarize(self.baseline_trials)
}

///|
/// Final success rate; restored sessions re-collect this evidence uncached.
pub fn Session::final_statistics(self : Session) -> @stability.Statistics {
  @stability.summarize(self.final_trials)
}

///|
fn package_candidates(
  snapshot : @manifest.Snapshot,
  targets : Array[String],
) -> Iter[@manifest.Snapshot] {
  let files = snapshot.files()
  let directories : Array[String] = []
  for file in files {
    if !targets.contains(file.0) || !file.0.has_suffix(".mbt") {
      continue
    }
    let parts = file.0.split("/").map(s => s.to_owned()).to_array()
    ignore(parts.pop())
    while !parts.is_empty() {
      let dir = parts.join("/") + "/"
      if !directories.contains(dir) {
        directories.push(dir)
      }
      ignore(parts.pop())
    }
  }
  directories
  .iter()
  .filter_map(dir => {
    if files.iter().any(f => f.0.has_prefix(dir) && !targets.contains(f.0)) {
      return None
    }
    match @manifest.Snapshot::new(files.filter(f => !f.0.has_prefix(dir))) {
      Ok(s) => Some(s)
      Err(_) => None
    }
  })
}

///|
fn allowed_edit(
  before : @manifest.Snapshot,
  after : @manifest.Snapshot,
  targets : Array[String],
) -> Bool {
  let original = before.files()
  let proposed = after.files()
  proposed.iter().all(f => original.iter().any(o => o.0 == f.0)) &&
  original.iter().all(f => targets.contains(f.0) || proposed.contains(f))
}

///|
priv struct BuiltinPass {
  pass_name : String
}

///|
impl @pass_api.ReductionPass for BuiltinPass with fn name(self) {
  self.pass_name
}

///|
impl @pass_api.ReductionPass for BuiltinPass with fn propose(
  self,
  snapshot,
  targets,
) {
  candidates(self.pass_name, snapshot, targets)
}

///|
/// Default pure passes in deterministic order; formatting and manifest edits are
/// excluded unless explicitly enabled. Callers can compose these with extensions.
pub fn default_passes() -> Array[&@pass_api.ReductionPass] {
  pass_names()
  .filter(n => n != "struct:format" && n != "manifest")
  .map(n => BuiltinPass::{ pass_name: n })
}
