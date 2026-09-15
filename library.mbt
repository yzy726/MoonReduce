///|
/// Synchronous pure-driver evaluation contract. Each call is one uncached trial.
/// Return Unresolved for inconclusive observations, Err for execution failures.
pub(open) trait CandidateEvaluator {
  fn evaluate(Self, @manifest.Snapshot) -> Result[@stability.Decision, String]
}

///|
/// Immutable versioned observation delivered in deterministic candidate order.
pub(all) struct Event {
  schema_version : Int
  candidate_id : Int
  phase : String
  trial : Int
  decision : @stability.Decision
} derive(ToJson)

///|
/// Event delivery is synchronous; sinks may record evidence or update a UI.
pub(open) trait EventSink {
  fn emit(Self, Event) -> Unit
}

///|
priv struct NoEvents {}

///|
impl EventSink for NoEvents with fn emit(_, _) {
  ()
}

///|
/// Pure reduction options. Native CLI time/process controls belong to app.Config.
pub(all) struct ReduceConfig {
  max_tests : Int
  repeat : Int
  quorum : Int
  consecutive : Bool
  final_repeat : Int
  final_quorum : Int
  score : String
  includes : Array[String]
  protects : Array[String]
  ignores : Array[String]
  pass_include : Array[String]
  pass_exclude : Array[String]
  extra_passes : Array[&@pass_api.ReductionPass]
}

///|
/// Defaults match the deterministic project engine: 2 baseline, 3 final trials.
pub fn default_config() -> ReduceConfig {
  {
    max_tests: 2500,
    repeat: 1,
    quorum: 1,
    consecutive: false,
    final_repeat: 3,
    final_quorum: 3,
    score: "bytes",
    includes: [],
    protects: [],
    ignores: [],
    pass_include: [],
    pass_exclude: [],
    extra_passes: [],
  }
}

///|
/// Built-in pure passes, in the same order as the native project CLI.
pub fn default_passes() -> Array[&@pass_api.ReductionPass] {
  @project.default_passes()
}

///|
fn session(
  original : @manifest.Snapshot,
  c : ReduceConfig,
) -> Result[@project.Session, String] {
  @project.Session::new(
    original,
    c.includes,
    c.protects,
    c.ignores,
    max_tests=c.max_tests,
    repeat=c.repeat,
    quorum=c.quorum,
    consecutive=c.consecutive,
    final_repeat=c.final_repeat,
    final_quorum=c.final_quorum,
    score=c.score,
    pass_include=c.pass_include,
    pass_exclude=c.pass_exclude,
    extra_passes=c.extra_passes,
  )
}

///|
fn drive(
  s : @project.Session,
  evaluator : &CandidateEvaluator,
  c : ReduceConfig,
  sink : &EventSink,
  baseline_only : Bool,
) -> Result[Unit, String] {
  while s.phase() != "stopped" {
    if baseline_only && s.phase() != "baseline" {
      break
    }
    let batch = s.next_batch()
    if batch.is_empty() {
      break
    }
    let phase = s.phase()
    for candidate in batch {
      let trials : Array[Bool?] = []
      let count = if phase == "reducing" { c.repeat } else { 1 }
      for trial in 0..<count {
        let decision = match evaluator.evaluate(candidate.snapshot) {
          Ok(d) => d
          Err(e) => return Err(e)
        }
        sink.emit({
          schema_version: 1,
          candidate_id: candidate.id,
          phase,
          trial: trial + 1,
          decision,
        })
        trials.push(
          match decision {
            Interesting => Some(true)
            Uninteresting => Some(false)
            Unresolved => None
          },
        )
      }
      let matched = if phase == "reducing" {
        let policy = @stability.Policy::new(
          c.repeat,
          c.quorum,
          consecutive=c.consecutive,
        ).unwrap()
        match policy.decide(trials) {
          Interesting => Some(true)
          Uninteresting => Some(false)
          Unresolved => None
        }
      } else {
        trials[0]
      }
      match s.record_result(candidate.id, matched, cost=count) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
/// Validate only the baseline; no pass runs and no original data is changed.
pub fn check(
  original : @manifest.Snapshot,
  evaluator : &CandidateEvaluator,
  config? : ReduceConfig = default_config(),
  sink? : &EventSink = NoEvents::{  },
) -> Result[@stability.Statistics, String] {
  let s = match session(original, config) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  match drive(s, evaluator, config, sink, true) {
    Err(e) => Err(e)
    Ok(_) => Ok(s.baseline_statistics())
  }
}

///|
/// Reduce immutable input using the same cached deterministic engine as the CLI.
/// Baseline and final trials always bypass the candidate cache.
pub fn reduce(
  original : @manifest.Snapshot,
  evaluator : &CandidateEvaluator,
  config? : ReduceConfig = default_config(),
  sink? : &EventSink = NoEvents::{  },
) -> Result[@project.ResultSummary, String] {
  let s = match session(original, config) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  match drive(s, evaluator, config, sink, false) {
    Err(e) => Err(e)
    Ok(_) => Ok(s.result())
  }
}
