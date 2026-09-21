///|
/// Size metrics are explicit: UTF8 bytes, significant tokens, physical lines.
pub fn metrics(text : String) -> Json {
  {
    "bytes": @source.encode(text).length(),
    "tokens": @token.significant(text).length(),
    "lines": @text.lines(text).length(),
    "hash": @source.digest(@source.encode(text)),
    "hash_algorithm": "fnv1a64",
  }
}

///|
/// Configuration summary without environment values. The schema is versioned.
pub fn config_summary(c : @config.Config) -> Json {
  let env_names = c.predicate.environment.keys().to_array()
  env_names.sort()
  {
    "command": c.predicate.command,
    "cwd": c.predicate.cwd,
    "target": c.target,
    "failure": c.predicate.failure.to_json(),
    "stdout_rules": c.predicate.stdout_rules.to_json(),
    "stderr_rules": c.predicate.stderr_rules.to_json(),
    "timeout_ms": c.predicate.timeout_ms,
    "output_limit": c.predicate.output_limit,
    "budget": c.budget.to_json(),
    "strip_locations": c.predicate.strip_locations,
    "redacted_environment": env_names,
    "cache": "v1/run-scoped-full-content",
    "ignored": c.ignore,
    "protected": c.protect,
  }
}

///|
/// Machine-readable summary. Evidence records are supplied by the native driver.
pub fn render_json(
  c : @config.Config,
  r : @engine.ReductionResult,
  elapsed_ms : Int64,
  unchanged : Bool,
  evidence? : Array[Json] = [],
  attempted_commands? : Int? = None,
) -> Json {
  {
    "schema_version": 1,
    "tool": "MoonReduce",
    "version": "0.2.0",
    "status": r.status.to_json(),
    "exit_code": r.status.exit_code(),
    "completed": r.status == Completed && r.final_passed == 3 && unchanged,
    "original": metrics(r.original),
    "reduced": metrics(r.best),
    "baseline_passed": r.baseline_passed,
    "final_passed": r.final_passed,
    "evaluations": r.evaluations,
    "attempted_commands": attempted_commands.unwrap_or(r.evaluations),
    "cache_hits": r.cache_hits,
    "duration_ms": elapsed_ms,
    "original_unchanged": unchanged,
    "accepted_sizes": r.accepted_sizes,
    "passes": r.passes.to_json(),
    "config": config_summary(c),
    "evidence": evidence,
  }
}

///|
/// Human-readable report with explicit verification and interruption state.
pub fn markdown(
  c : @config.Config,
  r : @engine.ReductionResult,
  elapsed_ms : Int64,
  unchanged : Bool,
) -> String {
  let out = StringBuilder()
  out.write_string("# MoonReduce 0.2.0\n\n")
  out.write_string(
    "Target: `" + c.target.replace_all(old="`", new="\\`") + "`\n\n",
  )
  out.write_string("Status: " + r.status.to_json().stringify() + "\n\n")
  out.write_string(
    "Baseline verification: \{r.baseline_passed}/2\n\nFinal verification: \{r.final_passed}/3\n\n",
  )
  out.write_string("Original unchanged: \{unchanged}\n\n")
  out.write_string("| Metric | Original | Reduced |\n|---|---:|---:|\n")
  out.write_string(
    "| UTF8 bytes | \{@source.encode(r.original).length()} | \{@source.encode(r.best).length()} |\n",
  )
  out.write_string(
    "| Tokens | \{@token.significant(r.original).length()} | \{@token.significant(r.best).length()} |\n",
  )
  out.write_string(
    "| Lines | \{@text.lines(r.original).length()} | \{@text.lines(r.best).length()} |\n\n",
  )
  out.write_string(
    "Executions: \{r.evaluations}; cache hits: \{r.cache_hits}; elapsed: \{elapsed_ms} ms.\n\n",
  )
  out.write_string(
    "| Pass | Attempts | Accepted | Removed bytes |\n|---|---:|---:|---:|\n",
  )
  for p in r.passes {
    out.write_string(
      "| \{p.name} | \{p.attempts} | \{p.accepted} | \{p.removed_bytes} |\n",
    )
  }
  out.write_string(
    "\nSee report.json for evidence and reproduce.txt for argv. A result with fewer than three final checks is not a completed reduction.\n",
  )
  out.to_string()
}

///|
fn patch_lines(out : StringBuilder, prefix : String, s : String) -> Unit {
  for span in @text.lines(s) {
    let line = s[span.0:span.1].to_owned()
    out.write_string(prefix + line)
    if !line.has_suffix("\n") {
      out.write_string("\n\\ No newline at end of file\n")
    }
  }
}

///|
/// A valid single-hunk unified patch, including no-final-newline markers.
pub fn unified_diff(
  target : String,
  original : String,
  best : String,
) -> String {
  if original == best {
    return ""
  }
  let old_lines = @text.lines(original).length()
  let new_lines = @text.lines(best).length()
  let old_start = if old_lines == 0 { 0 } else { 1 }
  let new_start = if new_lines == 0 { 0 } else { 1 }
  let out = StringBuilder()
  out.write_string(
    "--- a/\{target}\n+++ b/\{target}\n@@ -\{old_start},\{old_lines} +\{new_start},\{new_lines} @@\n",
  )
  patch_lines(out, "-", original)
  patch_lines(out, "+", best)
  out.to_string()
}

///|
/// Reproduction is recorded as argv JSON, avoiding platform-specific shell quoting.
pub fn reproduce(c : @config.Config) -> String {
  "MoonReduce 0.2.0 reproduction\n\n" +
  "Working directory: reduced/" +
  c.predicate.cwd +
  "\n" +
  "argv JSON: " +
  c.predicate.command.to_json().stringify() +
  "\n" +
  "Launch argv[0] directly with the remaining arguments; no shell is required.\n" +
  "Restore the environment overrides listed (values redacted) in report.json.\n" +
  "Predicate: " +
  config_summary(c).stringify() +
  "\n" +
  "Run only trusted commands. The isolated copy is not a security sandbox.\n"
}
