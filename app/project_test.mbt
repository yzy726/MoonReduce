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

///|
async test "project/e2e repeated predicates count commands and final quorum" {
  let base = project_fixture(1)
  let c = {
    ..base,
    repeat: 3,
    quorum: 2,
    final_repeat: 5,
    final_quorum: 4,
    budget: { ..base.budget, max_tests: 30 },
  }
  let result = @app.execute_project(c)
  assert_true(result.error is None)
  assert_eq(result.result.final_passed, 5)
  assert_true(result.result.evaluations <= 30)
  let report = @fs.read_file(c.output + "/report.json").text()
  assert_true(report.contains("\"repeat\": 3"))
  assert_true(report.contains("baseline_statistics"))
  let saved = @fs.read_file(c.output + "/checkpoint.json").text()
  assert_true(saved.contains("\"quorum\":2"))
}

///|
async test "project/e2e repeated destructive commands use fresh copies" {
  let base = project_fixture(4)
  let c = {
    ..base,
    repeat: 3,
    quorum: 3,
    predicate: {
      ..base.predicate,
      command: [probe_path(), "consume", "keep.mbt"],
    },
    budget: { ..base.budget, max_tests: 30 },
  }
  let result = @app.execute_project(c)
  assert_true(result.error is None)
  assert_eq(result.result.final_passed, 3)
  assert_true(@fs.read_file(c.workspace + "/keep.mbt").text().contains("KEEP"))
  assert_true(
    @fs.read_file(c.output + "/reduced/keep.mbt").text().contains("KEEP"),
  )
}

///|
async test "project/e2e resume retains repeated predicate policy" {
  let base = project_fixture(1)
  let c = {
    ..base,
    repeat: 3,
    quorum: 2,
    final_repeat: 5,
    final_quorum: 4,
    budget: { ..base.budget, max_tests: 8 },
  }
  ignore(@app.execute_project(c))
  let code = @app.run([
    "resume",
    c.output + "/checkpoint.json",
    "--output",
    c.output + "-again",
    "--max-tests",
    "30",
    "--quiet",
  ])
  assert_true(code == 0 || code == 4)
  let report = @fs.read_file(c.output + "-again/report.json").text()
  assert_true(report.contains("\"final_passed\": 5"))
  assert_true(report.contains("\"repeat\": 3"))
}

///|
async test "project/e2e advanced regex rejects unrelated output" {
  let base = project_fixture(1)
  let c = { ..base, advanced: { ..base.advanced, stdout_regex: ["UNRELATED"] } }
  let result = @app.execute_project(c)
  assert_eq(result.result.baseline_passed, 0)
  assert_eq(result.result.status, BaselineFailed)
}

///|
async test "project/e2e malformed wrapper is inconclusive" {
  let base = project_fixture(1)
  let result = @app.execute_project({
    ..base,
    advanced: { ..base.advanced, wrapper: true },
  })
  assert_eq(result.result.baseline_passed, 0)
  let report = @fs.read_file(base.output + "/report.json").text()
  assert_true(report.contains("\"resolved\": 0"))
}

///|
async test "project/e2e differential runs both commands within budget" {
  let base = project_fixture(2)
  let c = {
    ..base,
    reference: [probe_path(), "silent", "keep.mbt"],
    advanced: { ..base.advanced, differential: "stdout" },
    budget: { ..base.budget, max_tests: 30 },
  }
  let result = @app.execute_project(c)
  assert_true(result.error is None)
  assert_eq(result.result.final_passed, 3)
  assert_true(
    result.result.evaluations <= 30 && result.result.evaluations % 2 == 0,
  )
  let report = @fs.read_file(c.output + "/report.json").text()
  assert_true(report.contains("\"commands_per_trial\": 2"))
}

///|
async test "project/e2e equal differential results reject baseline" {
  let base = project_fixture(1)
  let c = {
    ..base,
    reference: base.predicate.command.copy(),
    advanced: { ..base.advanced, differential: "stdout" },
  }
  let result = @app.execute_project(c)
  assert_eq(result.result.baseline_passed, 0)
}

///|
async test "project/e2e valid wrapper preserves interesting candidates" {
  let base = project_fixture(1)
  let c = {
    ..base,
    predicate: {
      ..base.predicate,
      command: [probe_path(), "wrapper", "keep.mbt"],
      stdout_rules: [],
    },
    advanced: { ..base.advanced, wrapper: true },
  }
  let result = @app.execute_project(c)
  assert_eq(result.result.final_passed, 3)
  assert_true(result.result.best.files().iter().any(f => f.0 == "keep.mbt"))
}

///|
async test "project/e2e diagnostic and test fingerprint remain present" {
  let base = project_fixture(1)
  let c = {
    ..base,
    predicate: {
      ..base.predicate,
      command: [probe_path(), "fingerprint", "keep.mbt"],
    },
    advanced: {
      ..base.advanced,
      stdout_regex: ["E[0-9]+"],
      diagnostic_codes: ["E1234"],
      test_names: ["case"],
    },
  }
  let result = @app.execute_project(c)
  assert_eq(result.result.final_passed, 3)
}
