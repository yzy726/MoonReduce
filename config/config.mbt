///|
/// Validated initial CLI configuration. Relative target/cwd are workspace-relative.
pub(all) struct Config {
  project : Bool
  includes : Array[String]
  jobs : Int
  action : String
  workspace : String
  target : String
  output : String
  predicate : @model.PredicateSpec
  budget : @model.Budget
  quiet : Bool
  verbose : Bool
  json_events : Bool
  ignore : Array[String]
  protect : Array[String]
} derive(Debug, ToJson)

///|
priv suberror ConfigError {
  ConfigError(String)
}

///|
fn string_value(
  m : Map[String, Json],
  key : String,
  fallback : String,
) -> String raise {
  match m.get(key) {
    None => fallback
    Some(String(s)) => s
    _ => raise ConfigError("MR_CFG_TYPE: " + key + " must be string")
  }
}

///|
fn bool_value(m : Map[String, Json], key : String) -> Bool raise {
  match m.get(key) {
    None => false
    Some(True) => true
    Some(False) => false
    _ => raise ConfigError("MR_CFG_TYPE: " + key + " must be boolean")
  }
}

///|
fn strings(m : Map[String, Json], key : String) -> Array[String] raise {
  match m.get(key) {
    None => []
    Some(Array(a)) =>
      a.map(j => {
        match j {
          String(s) => s
          _ =>
            raise ConfigError(
              "MR_CFG_TYPE: " + key + " entries must be strings",
            )
        }
      })
    _ => raise ConfigError("MR_CFG_TYPE: " + key + " must be an array")
  }
}

///|
fn integer(m : Map[String, Json], key : String, fallback : Int) -> Int raise {
  let n = match m.get(key) {
    None => fallback
    Some(String(s)) => @string.parse_int(s)
    Some(Number(n, ..)) => {
      if n < 0.0 || n > 2147483647.0 || n != n.to_int().to_double() {
        raise ConfigError("MR_CFG_NUMBER: " + key)
      }
      n.to_int()
    }
    _ => raise ConfigError("MR_CFG_TYPE: " + key + " must be integer")
  }
  if n <= 0 {
    raise ConfigError("MR_CFG_NUMBER: " + key + " must be positive")
  }
  n
}

///|
fn duration(m : Map[String, Json], key : String, fallback : Int) -> Int raise {
  match m.get(key) {
    Some(String(s)) => {
      let (value, factor) = if s.has_suffix("ms") {
        (s[:s.length() - 2].to_owned(), 1)
      } else if s.has_suffix("s") {
        (s[:s.length() - 1].to_owned(), 1000)
      } else {
        (s, 1)
      }
      let n = @string.parse_int(value)
      if n <= 0 || n > 2147483647 / factor {
        raise ConfigError("MR_CFG_DURATION: " + key)
      }
      n * factor
    }
    _ => integer(m, key, fallback)
  }
}

///|
fn parse_inner(argv : Array[String], json : Json?) -> Config raise {
  let m : Map[String, Json] = match json {
    None => Map([])
    Some(Object(m)) => m.copy()
    _ => raise ConfigError("MR_CFG_TYPE: configuration must be an object")
  }
  let known = [
    "workspace", "target", "output", "cwd", "expect", "command", "timeout", "max_time",
    "max_tests", "output_limit", "stdout_contains", "stderr_contains", "stdout_not_contains",
    "stderr_not_contains", "ignore_case", "strip_locations", "quiet", "verbose",
    "json_events", "environment", "ignore", "protect", "project", "include", "jobs",
  ]
  for key, _ in m {
    if !known.contains(key) {
      raise ConfigError("MR_CFG_UNKNOWN: " + key)
    }
  }
  let action = if argv.is_empty() {
    "help"
  } else if argv[0] == "--help" || argv[0] == "-h" {
    "help"
  } else {
    argv[0]
  }
  if !["help", "passes", "check", "reduce", "explain"].contains(action) {
    raise ConfigError("MR_CFG_COMMAND: " + action)
  }
  let seen : Map[String, Bool] = Map([])
  let mut i = 1
  let mut positional = ""
  while i < argv.length() {
    let arg = argv[i]
    if arg == "--" {
      m["command"] = argv[i + 1:].to_owned().to_json()
      break
    }
    if action == "explain" && !arg.has_prefix("--") && positional == "" {
      positional = arg
      i += 1
      continue
    }
    if arg == "--help" {
      return parse_inner(["help"], None)
    }
    if !arg.has_prefix("--") {
      raise ConfigError("MR_CFG_ARGUMENT: " + arg)
    }
    let key = arg[2:].to_owned().replace_all(old="-", new="_")
    if key == "config" {
      if i + 1 >= argv.length() || seen.contains(key) {
        raise ConfigError("MR_CFG_ARGUMENT: --config")
      }
      seen[key] = true
      i += 2
      continue
    }
    if !known.contains(key) {
      raise ConfigError("MR_CFG_UNKNOWN: " + arg)
    }
    let array_option = [
      "stdout_contains", "stderr_contains", "stdout_not_contains", "stderr_not_contains",
      "ignore", "protect", "include",
    ].contains(key)
    if seen.contains(key) && !array_option {
      raise ConfigError("MR_CFG_DUPLICATE: " + arg)
    }
    let first = !seen.contains(key)
    seen[key] = true
    if [
        "quiet", "verbose", "json_events", "ignore_case", "strip_locations", "project",
      ].contains(key) {
      m[key] = true
      i += 1
      continue
    }
    if key == "environment" || key == "command" {
      raise ConfigError(
        "MR_CFG_ARGUMENT: use JSON environment and argv after --",
      )
    }
    if i + 1 >= argv.length() {
      raise ConfigError("MR_CFG_ARGUMENT: missing value for " + arg)
    }
    let value = argv[i + 1]
    if array_option {
      let values = if first { [] } else { strings(m, key) }
      values.push(value)
      m[key] = values.to_json()
    } else {
      m[key] = value.to_json()
    }
    i += 2
  }
  let project = bool_value(m, "project")
  let includes = strings(m, "include")
  let jobs = integer(m, "jobs", 1)
  if jobs > 64 {
    raise ConfigError("MR_CFG_JOBS: maximum 64 workers")
  }
  if !project && (jobs != 1 || !includes.is_empty()) {
    raise ConfigError("MR_CFG_PROJECT: --jobs/--include require --project")
  }
  let workspace = string_value(m, "workspace", ".")
  let target = string_value(m, "target", "")
  let output = if action == "explain" {
    positional
  } else {
    string_value(m, "output", "")
  }
  let command = strings(m, "command")
  if action == "check" || action == "reduce" {
    if !project {
      match @source.validate_path(target) {
        Err(e) => raise ConfigError(e)
        _ => ()
      }
      if !target.has_suffix(".mbt") {
        raise ConfigError("MR_CFG_TARGET: target must end in .mbt")
      }
    }
    if command.is_empty() || command[0] == "" {
      raise ConfigError("MR_CFG_COMMAND: argv required after --")
    }
    if action == "reduce" && output == "" {
      raise ConfigError("MR_CFG_OUTPUT: explicit output required")
    }
  }
  if action == "explain" && output == "" {
    raise ConfigError("MR_CFG_REPORT: report path required")
  }
  let cwd = string_value(m, "cwd", ".")
  if cwd != "." {
    match @source.validate_path(cwd) {
      Err(e) => raise ConfigError(e)
      _ => ()
    }
  }
  let expect = string_value(m, "expect", "nonzero")
  let failure = match expect {
    "nonzero" => @model.NonZero
    "timeout" => Timeout
    _ => ExitCode(@string.parse_int(expect))
  }
  let ignore_case = bool_value(m, "ignore_case")
  let out = strings(m, "stdout_contains").map(text => @model.OutputRule::{
    text,
    negate: false,
    ignore_case,
  })
  out.append(
    strings(m, "stdout_not_contains").map(text => {
      text,
      negate: true,
      ignore_case,
    }),
  )
  let err = strings(m, "stderr_contains").map(text => @model.OutputRule::{
    text,
    negate: false,
    ignore_case,
  })
  err.append(
    strings(m, "stderr_not_contains").map(text => {
      text,
      negate: true,
      ignore_case,
    }),
  )
  let env : Map[String, String] = Map([])
  match m.get("environment") {
    None => ()
    Some(Object(values)) =>
      for k, v in values {
        if k == "" || k.contains("=") || k.contains("\u0000") {
          raise ConfigError("MR_CFG_ENV: invalid name")
        }
        match v {
          String(s) => env[k] = s
          _ => raise ConfigError("MR_CFG_ENV: value must be string")
        }
      }
    _ => raise ConfigError("MR_CFG_ENV: expected object")
  }
  for arg in command {
    if arg.contains("\u0000") {
      raise ConfigError("MR_CFG_COMMAND: NUL in argv")
    }
  }
  let max_tests = integer(m, "max_tests", 1500)
  if max_tests < 5 {
    raise ConfigError("MR_CFG_BUDGET: at least five executions required")
  }
  let ignore = strings(m, "ignore")
  let protect = strings(m, "protect")
  for p in ignore + protect + includes {
    if project {
      match @glob.matches(p, "validation.mbt") {
        Err(e) => raise ConfigError(e)
        _ => ()
      }
      continue
    }
    match @source.validate_path(p) {
      Err(e) => raise ConfigError(e)
      _ => ()
    }
  }
  if !project && protect.contains(target) {
    raise ConfigError("MR_CFG_TARGET: target is protected")
  }
  {
    project,
    includes,
    jobs,
    action,
    workspace,
    target: target.replace_all(old="\\", new="/"),
    output,
    predicate: {
      command,
      cwd,
      failure,
      stdout_rules: out,
      stderr_rules: err,
      timeout_ms: duration(m, "timeout", 10000),
      output_limit: integer(m, "output_limit", 1048576),
      strip_locations: bool_value(m, "strip_locations"),
      environment: env,
    },
    budget: {
      max_tests,
      max_time_ms: duration(m, "max_time", 600000).to_int64(),
    },
    quiet: bool_value(m, "quiet"),
    verbose: bool_value(m, "verbose"),
    json_events: bool_value(m, "json_events"),
    ignore,
    protect,
  }
}

///|
/// Parse JSON defaults with explicit CLI overrides and strict unknown-key checking.
pub fn parse(argv : Array[String], json : Json?) -> Result[Config, String] {
  Ok(parse_inner(argv, json)) catch {
    ConfigError(message) => Err(message)
    e => Err("MR_CFG_VALUE: " + e.to_string())
  }
}
