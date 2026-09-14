///|
async fn probe_path() -> String {
  @fs.realpath(
    @env.get_env_var("MR_PROCESS_PROBE").unwrap_or(
      "_build/native/debug/build/tools/process_probe/process_probe.exe",
    ),
  )
}

///|
async test "e2e_timeout_preserves_original_and_final_verification" {
  let c = failure_fixture(
    "reduce",
    [probe_path(), "heartbeat", "heartbeat.txt"],
    "timeout",
  )
  let c = { ..c, predicate: { ..c.predicate, timeout_ms: 300 } }
  let r = @app.execute(c)
  assert_eq(r.result.status, BudgetExhausted)
  assert_eq(r.result.baseline_passed, 2)
  assert_eq(r.result.final_passed, 3)
  assert_preserved(c, r)
}

///|
async test "e2e_cancel_preserves_original_and_exports_interrupted_report" {
  let c = failure_fixture(
    "reduce",
    [probe_path(), "heartbeat", "heartbeat.txt"],
    "timeout",
  )
  let cancelled = @async.with_timeout_opt(600, () => @app.execute(c))
  assert_true(cancelled is None)
  assert_eq(
    @fs.read_file(c.workspace + "/a.mbt").text(),
    "// preserved original\n",
  )
  assert_eq(
    @fs.read_file(c.workspace + "/support.txt").text(),
    "support stays unchanged\n",
  )
  assert_eq(
    @fs.read_file(c.output + "/reduced/a.mbt").text(),
    "// preserved original\n",
  )
  let report = @json.parse(@fs.read_file(c.output + "/report.json").text()).stringify()
  assert_true(report.contains("\"status\":\"Cancelled\""))
  assert_true(report.contains("\"original_unchanged\":true"))
  assert_true(report.contains("\"completed\":false"))
}
