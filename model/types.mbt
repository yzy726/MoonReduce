///|
/// Stable failure class. Output rules are ANDed with this condition.
#derive(Debug, Eq, ToJson)
pub(all) enum FailureKind {
  ExitCode(Int32)
  NonZero
  Timeout
}

///|
/// Match one normalized stream; negative rules reject contained text.
#derive(Debug, Eq, ToJson)
pub(all) struct OutputRule {
  text : String
  negate : Bool
  ignore_case : Bool
}

///|
/// Direct argv execution and bounded predicate settings.
#derive(Debug, ToJson)
pub(all) struct PredicateSpec {
  command : Array[String]
  cwd : String
  failure : FailureKind
  stdout_rules : Array[OutputRule]
  stderr_rules : Array[OutputRule]
  timeout_ms : Int32
  output_limit : Int32
  strip_locations : Bool
  environment : Map[String, String]
}

///|
/// All command attempts count, including the two baseline and three final runs.
#derive(Debug, Eq, ToJson)
pub(all) struct Budget {
  max_tests : Int32
  max_time_ms : Int64
}

///|
/// Platform independent process observation. Spawn errors must be returned separately.
#derive(Debug, Eq, ToJson)
pub(all) struct Evaluation {
  exit_code : Int32
  timed_out : Bool
  stdout : String
  stderr : String
  stdout_truncated : Bool
  stderr_truncated : Bool
  duration_ms : Int64
}

///|
/// Terminal result, retaining the best known matching candidate on interruption.
#derive(Debug, Eq, ToJson)
pub(all) enum RunStatus {
  Completed
  BaselineFailed
  BaselineUnstable
  BudgetExhausted
  Cancelled
  ExecutionFailed
  FinalFailed
}

///|
/// CLI status mapping specified by the initial acceptance contract.
pub fn RunStatus::exit_code(self : RunStatus) -> Int32 {
  match self {
    Completed => 0
    BaselineFailed => 2
    BaselineUnstable => 3
    BudgetExhausted => 4
    Cancelled => 5
    ExecutionFailed => 6
    FinalFailed => 7
  }
}

///|
/// Default budget, with enough room for baseline and final verification.
pub fn default_budget() -> Budget {
  { max_tests: 1500, max_time_ms: 600000L, }
}

///|
/// Construct a predicate with conservative finite resource limits.
pub fn default_predicate(command : Array[String]) -> PredicateSpec {
  {
    command,
    cwd: ".",
    failure: NonZero,
    stdout_rules: [],
    stderr_rules: [],
    timeout_ms: 10000,
    output_limit: 1048576,
    strip_locations: false,
    environment: {},
  }
}

///|
pub extend Budget with @debug.Debug::{to_repr}

///|
pub extend Budget with @json.ToJson::{to_json}

///|
pub extend Budget with Eq::{not_equal, equal}

///|
pub extend Evaluation with @debug.Debug::{to_repr}

///|
pub extend Evaluation with @json.ToJson::{to_json}

///|
pub extend Evaluation with Eq::{not_equal, equal}

///|
pub extend FailureKind with @debug.Debug::{to_repr}

///|
pub extend FailureKind with @json.ToJson::{to_json}

///|
pub extend FailureKind with Eq::{not_equal, equal}

///|
pub extend OutputRule with @debug.Debug::{to_repr}

///|
pub extend OutputRule with @json.ToJson::{to_json}

///|
pub extend OutputRule with Eq::{not_equal, equal}

///|
pub extend PredicateSpec with @debug.Debug::{to_repr}

///|
pub extend PredicateSpec with @json.ToJson::{to_json}

///|
pub extend RunStatus with @debug.Debug::{to_repr}

///|
pub extend RunStatus with @json.ToJson::{to_json}

///|
pub extend RunStatus with Eq::{not_equal, equal}
