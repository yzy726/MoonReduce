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
  priv max_tests : Int
  priv mut state : Int
  priv mut pass_index : Int
  priv names : Array[String]
  priv mut queue : Iter[@manifest.Snapshot]
  priv mut ready : Bool
  priv pending : Array[Candidate]
  priv answers : Map[Int, Bool]
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
) -> Result[Session, String] {
  if max_tests < 5 {
    return Err("MR_CFG_BUDGET: at least five attempts required")
  }
  let targets = match @manifest.select(original, includes, protects, ignores) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let names = ["file"]
  names.append(
    @structured.names().filter(n => n != "format").map(n => "struct:" + n),
  )
  names.append(@text.names().map(n => "text:" + n))
  names.append(@token.names().map(n => "token:" + n))
  Ok({
    best: original,
    targets,
    max_tests,
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
fn score(snapshot : @manifest.Snapshot) -> (Int, Int) {
  let files = snapshot.files()
  let mut size = 0
  for file in files {
    size += file.1.length()
  }
  (size, files.length())
}

///|
fn better(a : @manifest.Snapshot, b : @manifest.Snapshot) -> Bool {
  let sa = score(a)
  let sb = score(b)
  sa.0 < sb.0 || (sa.0 == sb.0 && sa.1 < sb.1)
}

///|
fn candidates(
  name : String,
  snapshot : @manifest.Snapshot,
  targets : Array[String],
) -> Iter[@manifest.Snapshot] {
  let files = snapshot.files().filter(f => targets.contains(f.0))
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
      let proposals = if name.has_prefix("struct:") {
        @structured.propose_iter(name[7:].to_owned(), source)
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
    if self.evaluations >= self.max_tests - 3 {
      self.status = BudgetExhausted
      self.state = 2
      break
    }
    if self.pass_index >= self.names.length() {
      self.state = 2
      break
    }
    if !self.ready {
      self.queue = candidates(
        self.names[self.pass_index],
        self.best,
        self.targets,
      )
      self.ready = true
    }
    let width = (4).min(self.max_tests - 3 - self.evaluations)
    while self.pending.length() < width {
      let candidate = match self.queue.next() {
        Some(s) => s
        None => break
      }
      if !better(candidate, self.best) {
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
pub fn Session::record(
  self : Session,
  id : Int,
  matched : Bool,
) -> Result[Unit, String] {
  if self.state == 3 ||
    !self.pending.iter().any(c => c.id == id) ||
    self.answers.contains(id) {
    return Err("MR_ENGINE_REPLY: unknown or duplicate candidate")
  }
  self.answers[id] = matched
  self.evaluations += 1
  if self.answers.length() < self.pending.length() {
    return Ok(())
  }
  if self.state == 0 {
    if matched {
      self.baseline += 1
      if self.baseline == 2 {
        self.state = 1
      }
    } else {
      self.status = if self.baseline == 0 {
        BaselineFailed
      } else {
        BaselineUnstable
      }
      self.state = 3
    }
  } else if self.state == 2 {
    if matched {
      self.finals += 1
      if self.finals == 3 {
        self.state = 3
      }
    } else {
      self.status = FinalFailed
      self.state = 3
    }
  } else {
    let mut chosen : @manifest.Snapshot? = None
    for c in self.pending {
      let result = self.answers.get(c.id).unwrap_or(false)
      self.cache[c.snapshot.key()] = result
      if result && better(c.snapshot, self.best) {
        match chosen {
          None => chosen = Some(c.snapshot)
          Some(previous) if better(c.snapshot, previous) =>
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
