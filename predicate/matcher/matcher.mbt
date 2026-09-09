///|
/// Normalize line endings, the explicitly supplied workspace and optional :line:column.
pub fn normalize(
  text : String,
  workspace : String,
  strip_locations : Bool,
) -> String {
  let mut s = text.replace_all(old="\r\n", new="\n")
  if workspace != "" {
    s = s.replace_all(old=workspace, new="<workspace>")
    let alternate = workspace.replace_all(old="\\", new="/")
    s = s.replace_all(old=alternate, new="<workspace>")
  }
  if !strip_locations {
    return s
  }
  let out = StringBuilder()
  let mut i = 0
  while i < s.length() {
    if s[i] == 58 && i + 1 < s.length() && s[i + 1] >= 48 && s[i + 1] <= 57 {
      out.write_string(":<n>")
      i += 1
      while i < s.length() && s[i] >= 48 && s[i] <= 57 {
        i += 1
      }
    } else {
      out.write_string(s[i:i + 1].to_owned())
      i += 1
    }
  }
  out.to_string()
}

///|
fn stream_matches(
  rules : Array[@model.OutputRule],
  text : String,
  truncated : Bool,
  workspace : String,
  strip : Bool,
) -> Bool {
  let text = normalize(text, workspace, strip)
  for rule in rules {
    // Absence cannot be established when the tail of a stream was discarded.
    if rule.negate && truncated {
      return false
    }
    let needle = normalize(rule.text, workspace, strip)
    let found = if rule.ignore_case {
      text.to_lower().contains(needle.to_lower())
    } else {
      text.contains(needle)
    }
    if found == rule.negate {
      return false
    }
  }
  true
}

///|
/// Require the failure class and every stream rule, without reading clock or IO.
pub fn matches(
  spec : @model.PredicateSpec,
  evaluation : @model.Evaluation,
  workspace : String,
) -> Bool {
  let failure = match spec.failure {
    ExitCode(n) => !evaluation.timed_out && evaluation.exit_code == n
    NonZero => !evaluation.timed_out && evaluation.exit_code != 0
    Timeout => evaluation.timed_out
  }
  failure &&
  stream_matches(
    spec.stdout_rules,
    evaluation.stdout,
    evaluation.stdout_truncated,
    workspace,
    spec.strip_locations,
  ) &&
  stream_matches(
    spec.stderr_rules,
    evaluation.stderr,
    evaluation.stderr_truncated,
    workspace,
    spec.strip_locations,
  )
}
