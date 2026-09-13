///|
/// Per-pass counters use the same order as the deterministic registry.
pub(all) struct PassStats {
  name : String
  attempts : Int
  accepted : Int
  removed_bytes : Int
} derive(Debug, Eq, ToJson)

///|
/// Immutable result snapshot; best is retained even when final verification fails.
pub(all) struct ReductionResult {
  status : @model.RunStatus
  original : String
  best : String
  evaluations : Int
  cache_hits : Int
  baseline_passed : Int
  final_passed : Int
  accepted_sizes : Array[Int]
  passes : Array[PassStats]
} derive(Debug, ToJson)

///|
/// Pure request/response machine. The native driver owns time and process IO.
pub struct Session {
  original : String
  mut best : String
  mut phase : Int
  mut pending : String?
  mut evaluations : Int
  mut baseline : Int
  mut finals : Int
  mut status : @model.RunStatus
  mut pass_index : Int
  mut groups : Int
  mut queue : Iter[String]
  mut queue_ready : Bool
  sizes : Array[Int]
  stats : Array[PassStats]
  budget : @model.Budget
  cache : Map[String, Bool]
  mut hits : Int
}

///|
/// Construct a baseline-first session. No command is executed by this package.
pub fn Session::new(
  original : String,
  budget? : @model.Budget = @model.default_budget(),
) -> Session {
  let names = ["ddmin"]
  names.append(@text.names())
  names.append(@token.names())
  {
    original,
    budget,
    cache: Map([]),
    hits: 0,
    best: original,
    phase: 0,
    pending: None,
    evaluations: 0,
    baseline: 0,
    finals: 0,
    status: Completed,
    pass_index: 0,
    groups: 2,
    queue: [].iter(),
    queue_ready: false,
    sizes: [@source.encode(original).length()],
    stats: names.map(name => {
      name,
      attempts: 0,
      accepted: 0,
      removed_bytes: 0,
    }),
  }
}

///|
/// Human-readable phase for event streams and evaluator adapters.
pub fn Session::phase_name(self : Session) -> String {
  match self.phase {
    0 => "baseline"
    1 => "reducing"
    2 => "final"
    _ => "stopped"
  }
}

///|
fn Session::fill_queue(self : Session) -> Unit {
  self.queue_ready = true
  if self.pass_index == 0 {
    let ls = @text.lines(self.best)
    self.queue = @ddmin.partitions(ls.length(), self.groups)
      .iter()
      .map(p => {
        self.best[:ls[p.0].0].to_owned() + self.best[ls[p.1 - 1].1:].to_owned()
      })
  } else if self.pass_index <= @text.names().length() {
    self.queue = @text.propose_iter(self.stats[self.pass_index].name, self.best)
  } else {
    self.queue = @token.propose_iter(
      self.stats[self.pass_index].name,
      self.best,
    )
  }
}

///|
/// Request the next candidate. A second call before record returns the same request.
pub fn Session::next(self : Session) -> String? {
  if self.pending is Some(_) {
    return self.pending
  }
  if self.phase == 3 {
    return None
  }
  if self.evaluations >= self.budget.max_tests {
    self.stop(BudgetExhausted)
    return None
  }
  if self.phase == 1 && self.evaluations >= self.budget.max_tests - 3 {
    self.status = BudgetExhausted
    self.phase = 2
  }
  if self.phase == 0 || self.phase == 2 {
    self.pending = Some(self.best)
    return self.pending
  }
  while self.pass_index < self.stats.length() {
    if !self.queue_ready {
      self.fill_queue()
    }
    while self.queue.next() is Some(candidate) {
      if @source.encode(candidate).length() < @source.encode(self.best).length() {
        if self.cache.contains(candidate) {
          self.hits += 1
          continue
        }
        self.pending = Some(candidate)
        return self.pending
      }
    }
    let count = @text.lines(self.best).length()
    if self.pass_index == 0 && self.groups < count {
      self.groups = (self.groups * 2).min(count)
    } else {
      self.pass_index += 1
    }
    self.queue = [].iter()
    self.queue_ready = false
  }
  self.phase = 2
  self.pending = Some(self.best)
  self.pending
}

///|
/// Supply the predicate verdict for the pending candidate; no pending request is a no-op.
pub fn Session::record(self : Session, matched : Bool) -> Unit {
  guard self.pending is Some(candidate) else { return }
  self.pending = None
  self.evaluations += 1
  match self.phase {
    0 =>
      if matched {
        self.baseline += 1
        if self.baseline == 2 {
          self.phase = 1
        }
      } else {
        self.status = if self.baseline == 0 {
          BaselineFailed
        } else {
          BaselineUnstable
        }
        self.phase = 3
      }
    1 => {
      self.cache[candidate] = matched
      let stat = self.stats[self.pass_index]
      let removed = if matched {
        @source.encode(self.best).length() - @source.encode(candidate).length()
      } else {
        0
      }
      self.stats[self.pass_index] = {
        ..stat,
        attempts: stat.attempts + 1,
        accepted: stat.accepted + (if matched { 1 } else { 0 }),
        removed_bytes: stat.removed_bytes + removed,
      }
      if matched {
        self.best = candidate
        self.sizes.push(@source.encode(candidate).length())
        self.groups = (self.groups - 1).max(2)
        self.pass_index = 0
        self.queue = [].iter()
        self.queue_ready = false
      }
    }
    2 =>
      if matched {
        self.finals += 1
        if self.finals == 3 {
          self.phase = 3
        }
      } else {
        self.status = FinalFailed
        self.phase = 3
      }
    _ => ()
  }
}

///|
/// Snapshot counters and the last matching source, with explicit final verification count.
pub fn Session::result(self : Session) -> ReductionResult {
  {
    status: self.status,
    original: self.original,
    best: self.best,
    evaluations: self.evaluations,
    cache_hits: self.hits,
    baseline_passed: self.baseline,
    final_passed: self.finals,
    accepted_sizes: self.sizes.copy(),
    passes: self.stats.copy(),
  }
}
