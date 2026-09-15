///|
/// Additive versioned predicates; all specified conditions must match.
pub(all) struct Spec {
  schema_version : Int
  stdout_regex : Array[String]
  stderr_regex : Array[String]
  crash : String
  diagnostic_codes : Array[String]
  test_names : Array[String]
  normalize : Bool
  differential : String
  wrapper : Bool
  timeout_ms : Int
  timeout_tolerance_ms : Int
} derive(Debug, ToJson, @json.FromJson)

///|
pub fn defaults() -> Spec {
  {
    schema_version: 1,
    stdout_regex: [],
    stderr_regex: [],
    crash: "",
    diagnostic_codes: [],
    test_names: [],
    normalize: false,
    differential: "",
    wrapper: false,
    timeout_ms: 10000,
    timeout_tolerance_ms: 0,
  }
}

///|
pub fn Spec::validate(self : Spec) -> Result[Unit, String] {
  if self.schema_version != 1 {
    return Err("MR_PREDICATE_VERSION: expected version 1")
  }
  if ![
      "", "any", "memory", "abort", "arithmetic", "illegal-instruction", "signal",
      "panic",
    ].contains(self.crash) ||
    !["", "stdout", "stderr", "exit", "any"].contains(self.differential) {
    return Err("MR_PREDICATE_KIND: unsupported crash or differential class")
  }
  if self.timeout_ms <= 0 ||
    self.timeout_tolerance_ms < 0 ||
    self.timeout_tolerance_ms >= self.timeout_ms {
    return Err("MR_PREDICATE_TIMEOUT: invalid tolerance")
  }
  let expressions = self.stdout_regex + self.stderr_regex
  if expressions.length() +
    self.diagnostic_codes.length() +
    self.test_names.length() >
    128 {
    return Err("MR_PREDICATE_SIZE: maximum 128 rules")
  }
  for pattern in expressions {
    match @regex.Regex::compile(pattern) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  for text in self.diagnostic_codes + self.test_names {
    if text == "" || text.length() > 1024 {
      return Err("MR_PREDICATE_SIZE: empty or oversized fingerprint")
    }
  }
  Ok(())
}

///|
/// Decode and validate a versioned predicate configuration.
pub fn Spec::from_json(value : Json) -> Result[Spec, String] {
  let spec : Spec = @json.from_json(value) catch {
    _ => return Err("MR_PREDICATE_FORMAT: malformed specification")
  }
  match spec.validate() {
    Ok(_) => Ok(spec)
    Err(e) => Err(e)
  }
}

///|
/// POSIX negative signal numbers follow moonbitlang/async's process contract.
/// Known Windows NTSTATUS values map to the same categories; ordinary nonzero
/// exit codes remain `none`, and timeouts never count as crashes.
pub fn crash_class(e : @model.Evaluation) -> String {
  if e.timed_out {
    return "timeout"
  }
  match e.exit_code {
    -11 | -7 | -1073741819 | -1073741571 => "memory"
    -6 | -1073740791 => "abort"
    -8 | -1073741676 | -1073741682 => "arithmetic"
    -4 | -1073741795 => "illegal-instruction"
    n if n < 0 && n >= -127 => "signal"
    n if n != 0 &&
      (
        e.stderr.to_lower().contains("panic") ||
        e.stdout.to_lower().contains("panic")
      ) => "panic"
    _ => "none"
  }
}

///|
fn word(c : UInt16) -> Bool {
  (c >= 48 && c <= 57) ||
  (c >= 65 && c <= 90) ||
  (c >= 97 && c <= 122) ||
  c == 95
}

///|
/// Extract distinct E/W-prefixed diagnostic tokens and bracketed numeric codes.
pub fn diagnostic_codes(text : String) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  while i < text.length() {
    let start = i
    if (text[i] == 69 || text[i] == 87) && (i == 0 || !word(text[i - 1])) {
      i += 1
      let digits = i
      while i < text.length() && text[i] >= 48 && text[i] <= 57 {
        i += 1
      }
      if i > digits && (i == text.length() || !word(text[i])) {
        let code = text[start:i].to_owned()
        if !result.contains(code) {
          result.push(code)
        }
      }
    } else if text[i] == 91 {
      i += 1
      let digits = i
      while i < text.length() && text[i] >= 48 && text[i] <= 57 {
        i += 1
      }
      if i - digits == 4 && i < text.length() && text[i] == 93 {
        let code = text[digits:i].to_owned()
        if !result.contains(code) {
          result.push(code)
        }
      }
    }
    i = i.max(start + 1)
  }
  result
}

///|
/// Extract quoted names after a standalone `test` label in tool output.
pub fn test_names(text : String) -> Array[String] {
  let names : Array[String] = []
  let mut i = 0
  while i + 5 < text.length() {
    if text[i] == 116 &&
      text[i + 1] == 101 &&
      text[i + 2] == 115 &&
      text[i + 3] == 116 &&
      text[i + 4] == 32 &&
      (i == 0 || !word(text[i - 1])) {
      i += 5
      while i < text.length() && text[i] == 32 {
        i += 1
      }
      if i < text.length() && (text[i] == 34 || text[i] == 39) {
        let quote = text[i]
        i += 1
        let start = i
        while i < text.length() && text[i] != quote && text[i] != 10 {
          i += 1
        }
        if i < text.length() && text[i] == quote {
          let name = text[start:i].to_owned()
          if !names.contains(name) {
            names.push(name)
          }
        }
      }
    }
    i += 1
  }
  names
}

///|
fn hex(c : UInt16) -> Bool {
  (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
}

///|
/// Explicit normalization pipeline: root paths, CRLF, source locations, ANSI
/// CSI escapes, nonprinting controls and long hexadecimal pointer addresses.
pub fn normalize(text : String, workspace : String) -> String {
  let text = @matcher.normalize(text, workspace, true)
  let output = StringBuilder()
  let mut i = 0
  while i < text.length() {
    if text[i] == 27 && i + 1 < text.length() && text[i + 1] == 91 {
      i += 2
      while i < text.length() && !(text[i] >= 64 && text[i] <= 126) {
        i += 1
      }
      if i < text.length() {
        i += 1
      }
      continue
    }
    if i + 2 < text.length() && text[i] == 48 && text[i + 1] == 120 {
      let mut end = i + 2
      while end < text.length() && hex(text[end]) {
        end += 1
      }
      if end - i >= 8 {
        output.write_string("<address>")
        i = end
        continue
      }
    }
    let width = if text[i] >= 0xD800 && text[i] <= 0xDBFF { 2 } else { 1 }
    if text[i] >= 32 || text[i] == 10 || text[i] == 9 {
      output.write_string(text[i:i + width].to_owned())
    }
    i += width
  }
  output.to_string()
}

///|
/// Apply the optional pipeline consistently to legacy and advanced rules.
pub fn prepare(
  spec : Spec,
  e : @model.Evaluation,
  workspace : String,
) -> @model.Evaluation {
  if spec.normalize {
    {
      ..e,
      stdout: normalize(e.stdout, workspace),
      stderr: normalize(e.stderr, workspace),
    }
  } else {
    e
  }
}

///|
fn regex_rules(
  patterns : Array[String],
  text : String,
  truncated : Bool,
) -> Bool? {
  if !patterns.is_empty() && truncated {
    return None
  }
  for pattern in patterns {
    let expression = match @regex.Regex::compile(pattern) {
      Ok(r) => r
      Err(_) => return None
    }
    match expression.matches(text) {
      Ok(true) => ()
      Ok(false) => return Some(false)
      Err(_) => return None
    }
  }
  Some(true)
}

///|
/// Evaluate additive conditions. Missing, malformed, truncated, budget-limited
/// or timeout-boundary evidence is inconclusive and must never enter a cache as
/// a definitive negative. The legacy exit/output predicate remains separate.
pub fn matches(
  spec : Spec,
  primary : @model.Evaluation,
  reference : @model.Evaluation?,
  primary_root : String,
  reference_root : String,
) -> Bool? {
  if spec.validate() is Err(_) {
    return None
  }
  let primary = prepare(spec, primary, primary_root)
  if spec.timeout_tolerance_ms > 0 &&
    (primary.duration_ms - spec.timeout_ms.to_int64()).abs() <=
    spec.timeout_tolerance_ms.to_int64() {
    return None
  }
  if spec.crash != "" {
    let kind = crash_class(primary)
    if (spec.crash == "any" && (kind == "none" || kind == "timeout")) ||
      (spec.crash != "any" && kind != spec.crash) {
      return Some(false)
    }
  }
  for
    result in [
      regex_rules(spec.stdout_regex, primary.stdout, primary.stdout_truncated),
      regex_rules(spec.stderr_regex, primary.stderr, primary.stderr_truncated),
    ] {
    if result != Some(true) {
      return result
    }
  }
  let text = primary.stdout + "\n" + primary.stderr
  let codes = diagnostic_codes(text)
  let names = test_names(text)
  for code in spec.diagnostic_codes {
    if !codes.contains(code) {
      return if primary.stdout_truncated || primary.stderr_truncated {
        None
      } else {
        Some(false)
      }
    }
  }
  for name in spec.test_names {
    if !names.contains(name) {
      return if primary.stdout_truncated || primary.stderr_truncated {
        None
      } else {
        Some(false)
      }
    }
  }
  if spec.wrapper {
    if primary.timed_out || primary.exit_code != 0 || primary.stdout_truncated {
      return None
    }
    let value = @json.parse(primary.stdout) catch { _ => return None }
    match value {
      { "schema_version": 1, "interesting": True, .. } => ()
      { "schema_version": 1, "interesting": False, .. } => return Some(false)
      _ => return None
    }
  }
  if spec.differential != "" {
    guard reference is Some(reference) else { return None }
    let reference = prepare(spec, reference, reference_root)
    if primary.timed_out || reference.timed_out {
      return None
    }
    let exit_diff = primary.exit_code != reference.exit_code
    if spec.differential == "exit" {
      return Some(exit_diff)
    }
    if primary.stdout_truncated ||
      primary.stderr_truncated ||
      reference.stdout_truncated ||
      reference.stderr_truncated {
      return None
    }
    return Some(
      match spec.differential {
        "stdout" => primary.stdout != reference.stdout
        "stderr" => primary.stderr != reference.stderr
        _ =>
          exit_diff ||
          primary.stdout != reference.stdout ||
          primary.stderr != reference.stderr
      },
    )
  }
  Some(true)
}
