///|
/// Stable failure class. Output rules are ANDed with this condition.
pub(all) enum FailureKind {
  ExitCode(Int)
  NonZero
  Timeout
} derive(Debug, Eq, ToJson)

///|
/// Match one normalized stream; negative rules reject contained text.
pub(all) struct OutputRule {
  text : String
  negate : Bool
  ignore_case : Bool
} derive(Debug, Eq, ToJson)

///|
/// Direct argv execution and bounded predicate settings.
pub(all) struct PredicateSpec {
  command : Array[String]
  cwd : String
  failure : FailureKind
  stdout_rules : Array[OutputRule]
  stderr_rules : Array[OutputRule]
  timeout_ms : Int
  output_limit : Int
  strip_locations : Bool
  environment : Map[String, String]
} derive(Debug, ToJson)

///|
/// All command attempts count, including the two baseline and three final runs.
pub(all) struct Budget {
  max_tests : Int
  max_time_ms : Int64
} derive(Debug, Eq, ToJson)

///|
/// Platform independent process observation. Spawn errors must be returned separately.
pub(all) struct Evaluation {
  exit_code : Int
  timed_out : Bool
  stdout : String
  stderr : String
  stdout_truncated : Bool
  stderr_truncated : Bool
  duration_ms : Int64
} derive(Debug, Eq, ToJson)

///|
/// Terminal result, retaining the best known matching candidate on interruption.
pub(all) enum RunStatus {
  Completed
  BaselineFailed
  BaselineUnstable
  BudgetExhausted
  Cancelled
  ExecutionFailed
  FinalFailed
} derive(Debug, Eq, ToJson)

///|
/// CLI status mapping specified by the initial acceptance contract.
pub fn RunStatus::exit_code(self : RunStatus) -> Int {
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
  { max_tests: 1500, max_time_ms: 600000L }
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
