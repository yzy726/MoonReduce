///|
async fn project_fixture(jobs : Int) -> @config.Config {
  let root = @fs.tmpdir(prefix="moonreduce-project-e2e-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(
    input + "/keep.mbt",
    "// noise\nfn keep() { KEEP }\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    input + "/noise.mbt",
    "fn unused() { 10000 }\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    input + "/README.md",
    "protected support",
    create_mode=CreateNew,
  )
  @config.parse(
    [
      "reduce",
      "--project",
      "--workspace",
      input,
      "--output",
      root + "/out",
      "--jobs",
      jobs.to_string(),
      "--quiet",
      "--expect",
      "0",
      "--stdout-contains",
      "KEEP",
      "--max-tests",
      "40",
      "--",
      probe_path(),
      "contains",
      "keep.mbt",
    ],
    None,
  ).unwrap()
}

///|
async test "project/e2e CLI reduces multiple files and preserves support" {
  let c = project_fixture(1)
  let code = @app.run([
    "reduce",
    "--project",
    "--workspace",
    c.workspace,
    "--output",
    c.output,
    "--quiet",
    "--expect",
    "0",
    "--stdout-contains",
    "KEEP",
    "--max-tests",
    "40",
    "--",
    probe_path(),
    "contains",
    "keep.mbt",
  ])
  assert_true(code == 0 || code == 4)
  assert_true(!@fs.exists(c.output + "/reduced/noise.mbt"))
  assert_true(
    @fs.read_file(c.output + "/reduced/keep.mbt").text().contains("KEEP"),
  )
  assert_eq(
    @fs.read_file(c.output + "/reduced/README.md").text(),
    "protected support",
  )
  assert_true(@fs.exists(c.workspace + "/noise.mbt"))
  let report = @fs.read_file(c.output + "/report.json").text()
  assert_true(report.contains("\"final_passed\": 3"))
}

///|
async test "project/e2e worker counts choose identical snapshots" {
  let c1 = project_fixture(1)
  let c4 = project_fixture(4)
  let r1 = @app.execute_project(c1)
  let r4 = @app.execute_project(c4)
  assert_eq(r1.result.best.key(), r4.result.best.key())
  assert_eq(r1.result.final_passed, 3)
  assert_eq(r4.result.final_passed, 3)
}

///|
async test "project/e2e missing command records failure without modifying input" {
  let c = project_fixture(1)
  let c = {
    ..c,
    predicate: { ..c.predicate, command: ["moonreduce-command-does-not-exist"] },
  }
  let r = @app.execute_project(c)
  assert_eq(r.result.status, ExecutionFailed)
  assert_true(r.error is Some(_))
  assert_eq(
    @fs.read_file(c.workspace + "/keep.mbt").text(),
    "// noise\nfn keep() { KEEP }\n",
  )
  assert_true(@fs.exists(c.output + "/report.json"))
}

///|
async test "project/e2e resume preserves best and revalidates finals" {
  let c = project_fixture(1)
  let limited = { ..c, budget: { ..c.budget, max_tests: 5 } }
  let first = @app.execute_project(limited)
  assert_eq(first.result.status, BudgetExhausted)
  assert_true(@fs.exists(c.output + "/checkpoint.json"))
  let result = @app.run([
    "resume",
    c.output + "/checkpoint.json",
    "--output",
    c.output + "-resumed",
    "--max-tests",
    "80",
    "--quiet",
  ])
  assert_true(result == 0 || result == 4)
  let report = @fs.read_file(c.output + "-resumed/report.json").text()
  assert_true(report.contains("\"final_passed\": 3"))
  assert_true(
    @fs.read_file(c.output + "-resumed/reduced/keep.mbt")
    .text()
    .contains("KEEP"),
  )
  assert_true(@fs.exists(c.workspace + "/noise.mbt"))
}

///|
async test "project/e2e resume refuses changed original" {
  let c = project_fixture(1)
  ignore(@app.execute_project({ ..c, budget: { ..c.budget, max_tests: 5 } }))
  @fs.write_file(c.workspace + "/noise.mbt", "changed")
  let rejected = try {
    let code = @app.run([
      "resume",
      c.output + "/checkpoint.json",
      "--output",
      c.output + "-resumed",
      "--max-tests",
      "80",
    ])
    code != 0 && code != 4
  } catch {
    _ => true
  }
  assert_true(rejected)
}
