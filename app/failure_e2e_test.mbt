///|
async fn failure_fixture(
  action : String,
  command : Array[String],
  expect : String,
) -> @config.Config {
  let root = @fs.tmpdir(prefix="moonreduce-failure-e2e-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(
    input + "/a.mbt",
    "// preserved original\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    input + "/support.txt",
    "support stays unchanged\n",
    create_mode=CreateNew,
  )
  @config.parse(
    [action],
    Some({
      "workspace": input,
      "target": "a.mbt",
      "output": root + "/output",
      "command": command,
      "expect": expect,
      "max_tests": 5,
      "quiet": true,
    }),
  ).unwrap()
}

///|
async fn assert_preserved(c : @config.Config, r : @app.Run) -> Unit {
  assert_eq(
    @fs.read_file(c.workspace + "/a.mbt").text(),
    "// preserved original\n",
  )
  assert_eq(
    @fs.read_file(c.workspace + "/support.txt").text(),
    "support stays unchanged\n",
  )
  assert_eq(@fs.read_file(r.output + "/reduced/a.mbt").text(), r.result.best)
  assert_eq(
    @fs.read_file(r.output + "/reduced/support.txt").text(),
    "support stays unchanged\n",
  )
  let report = @json.parse(@fs.read_file(r.output + "/report.json").text()).stringify()
  assert_true(report.contains("\"original_unchanged\":true"))
  assert_true(report.contains("\"completed\":false"))
}

///|
async test "e2e/baseline mismatch preserves original and exports uncertified result" {
  let c = failure_fixture("reduce", ["moon", "version"], "nonzero")
  let r = @app.execute(c)
  assert_eq(r.result.status, BaselineFailed)
  assert_eq(r.result.evaluations, 1)
  assert_eq(r.result.baseline_passed, 0)
  assert_eq(r.result.final_passed, 0)
  assert_preserved(c, r)
}

///|
async test "e2e/spawn failure preserves original and writes explicit error" {
  let c = failure_fixture(
    "reduce",
    ["moonreduce-missing-executable-5a7cf"],
    "nonzero",
  )
  let r = @app.execute(c)
  assert_eq(r.result.status, ExecutionFailed)
  assert_eq(r.result.evaluations, 0)
  assert_true(r.error is Some(_))
  assert_true(
    @fs.read_file(r.output + "/error.txt").text().contains("MR_EXEC_FAILURE"),
  )
  assert_preserved(c, r)
}

///|
async test "e2e/execution budget reserves final checks and preserves original" {
  let c = failure_fixture("reduce", ["moon", "version"], "0")
  let r = @app.execute(c)
  assert_eq(r.result.status, BudgetExhausted)
  assert_eq(r.result.evaluations, 5)
  assert_eq(r.result.baseline_passed, 2)
  assert_eq(r.result.final_passed, 3)
  assert_eq(r.result.best, r.result.original)
  assert_preserved(c, r)
}

///|
async test "e2e/check stops after baseline without certifying a reduction" {
  let c = failure_fixture("check", ["moon", "version"], "0")
  let r = @app.execute(c)
  assert_eq(r.result.status, Completed)
  assert_eq(r.result.evaluations, 2)
  assert_eq(r.result.baseline_passed, 2)
  assert_eq(r.result.final_passed, 0)
  assert_preserved(c, r)
}
