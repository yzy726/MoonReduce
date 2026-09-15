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

///|
async test "project/e2e strategy controls retain requested workspaces" {
  let base = project_fixture(1)
  let c = {
    ..base,
    score: "tokens",
    pass_include: ["file"],
    pass_exclude: ["file"],
    keep_workdir: true,
  }
  let result = @app.execute_project(c)
  assert_eq(result.result.evaluations, 5)
  assert_true(@fs.exists(c.output + "/.moonreduce/work/run-1"))
  assert_true(@fs.exists(c.output + "/reduced/noise.mbt"))
  assert_true(
    @fs.read_file(c.output + "/report.json")
    .text()
    .contains("\"score_strategy\": \"tokens\""),
  )
}

///|
async test "project/e2e deletes unused package directory only in copies" {
  let base = project_fixture(1)
  @fs.mkdir(base.workspace + "/unused")
  @fs.write_file(base.workspace + "/unused/moon.pkg", "", create_mode=CreateNew)
  @fs.write_file(
    base.workspace + "/unused/a.mbt",
    "noise",
    create_mode=CreateNew,
  )
  let result = @app.execute_project({ ..base, pass_include: ["package"] })
  assert_eq(result.result.final_passed, 3)
  assert_true(!@fs.exists(base.output + "/reduced/unused"))
  assert_true(@fs.exists(base.workspace + "/unused/a.mbt"))
}

///|
async test "project/e2e opt-in manifest edit appears in diff" {
  let base = project_fixture(1)
  @fs.write_file(
    base.workspace + "/moon.mod",
    "name = \"a/b\"\ndescription = \"noise\"\n",
    create_mode=CreateNew,
  )
  let result = @app.execute_project({ ..base, pass_include: ["manifest"] })
  assert_eq(result.result.final_passed, 3)
  assert_true(
    @fs.read_file(base.output + "/reduced/moon.mod")
    .text()
    .contains("name = \"a/b\""),
  )
  assert_true(
    @fs.read_file(base.output + "/reduction.diff").text().contains("moon.mod"),
  )
}

///|
async test "project/e2e evidence bundle has checksums and redacted environment" {
  let base = project_fixture(1)
  let env : Map[String, String] = { "MR_TEST_SECRET": "private-value-123" }
  let c = { ..base, predicate: { ..base.predicate, environment: env } }
  let result = @app.execute_project(c)
  assert_eq(result.result.final_passed, 3)
  let checksums = @fs.read_file(c.output + "/checksums.txt").text()
  assert_true(checksums.contains("  checkpoint.json\n"))
  assert_true(checksums.contains("  reduced/keep.mbt\n"))
  let environment = @fs.read_file(c.output + "/environment.json").text()
  assert_true(!environment.contains("private-value-123"))
  assert_true(environment.contains("schema_version"))
  assert_eq(@app.verify_bundle(c.output), ())
  @fs.write_file(c.output + "/reduced/keep.mbt", "tampered")
  let rejected = try {
    @app.verify_bundle(c.output)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
async test "project/e2e evidence rejects missing extra and traversal entries" {
  let c = project_fixture(1)
  let _ = @app.execute_project(c)
  let checksums = @fs.read_file(c.output + "/checksums.txt").text()
  @fs.write_file(
    c.output + "/reduced/extra.txt",
    "extra",
    create_mode=CreateNew,
  )
  let extra = try {
    @app.verify_bundle(c.output)
    false
  } catch {
    _ => true
  }
  assert_true(extra)
  @fs.remove(c.output + "/reduced/extra.txt")
  @fs.write_file(c.output + "/checksums.txt", "")
  let missing = try {
    @app.verify_bundle(c.output)
    false
  } catch {
    _ => true
  }
  assert_true(missing)
  @fs.write_file(
    c.output + "/checksums.txt",
    checksums +
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  ../outside\n",
  )
  let traversal = try {
    @app.verify_bundle(c.output)
    false
  } catch {
    _ => true
  }
  assert_true(traversal)
}

///|
async test "project/e2e replay verifies fresh copies without original input" {
  let c = project_fixture(1)
  let _ = @app.execute_project(c)
  @fs.write_file(c.workspace + "/keep.mbt", "original intentionally changed")
  let saved = @fs.read_file(c.output + "/reduced/keep.mbt").text()
  let out = c.output + "-replay"
  assert_eq(@app.run(["replay", c.output + "/report.json", "--output", out]), 0)
  let report = @fs.read_file(out + "/replay.json").text()
  assert_true(report.contains("Interesting"))
  assert_true(report.contains("\"attempts\": 3"))
  assert_eq(@fs.read_file(c.output + "/reduced/keep.mbt").text(), saved)
}

///|
async test "project/e2e replay refuses corrupt evidence before executing" {
  let c = project_fixture(1)
  let _ = @app.execute_project(c)
  @fs.write_file(c.output + "/report.json", "{}")
  let out = c.output + "-blocked"
  let rejected = try {
    let _ = @app.run(["replay", c.output + "/report.json", "--output", out])
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(!@fs.exists(out))
}

///|
async test "project/e2e real flaky predicate records four of five successes" {
  let base = project_fixture(1)
  let counter = base.workspace + "-counter"
  @fs.write_file(counter, "", create_mode=CreateNew)
  let environment : Map[String, String] = { "MR_FLAKY_STATE": counter }
  let c = {
    ..base,
    repeat: 5,
    quorum: 4,
    final_repeat: 5,
    final_quorum: 4,
    budget: { ..base.budget, max_tests: 200 },
    predicate: {
      ..base.predicate,
      command: [probe_path(), "flaky", "keep.mbt"],
      environment,
    },
  }
  let result = @app.execute_project(c)
  assert_eq(result.result.baseline_passed, 4)
  assert_eq(result.result.final_passed, 4)
  let report = @fs.read_file(c.output + "/report.json").text()
  assert_true(report.contains("\"rate\": 0.8"))
  assert_true(report.contains("\"probabilistic\": true"))
  assert_eq(
    @app.run([
      "replay",
      c.output + "/report.json",
      "--output",
      c.output + "-replay",
    ]),
    0,
  )
}

///|
async test "project/e2e cancellation persists checkpoint and resumes to final validation" {
  let base = project_fixture(1)
  let c = { ..base, budget: { ..base.budget, max_tests: 150 } }
  @async.with_task_group(group => {
    let task = group.spawn(() => @app.execute_project(c), allow_failure=true)
    let mut reached = false
    for _ in 0..<1000 {
      if @fs.exists(c.output + "/checkpoint.json") {
        let document = @json.parse(
          @fs.read_file(c.output + "/checkpoint.json").text(),
        )
        if document is { "engine": { "evaluations": Number(n, ..), .. }, .. } &&
          n >= 10.0 {
          reached = true
          break
        }
      }
      @async.sleep(5)
    }
    assert_true(reached)
    task.cancel()
    ignore(task.wait()) catch {
      _ => ()
    }
  })
  assert_true(@fs.exists(c.output + "/checkpoint.json"))
  assert_true(
    @fs.read_file(c.output + "/report.json").text().contains("Cancelled"),
  )
  let cancelled_report = @json.parse(
    @fs.read_file(c.output + "/report.json").text(),
  )
  assert_true(
    cancelled_report is { "cancelled_tasks": Number(n, ..), .. } && n >= 0.0,
  )
  let resumed = c.output + "-resume"
  assert_eq(
    @app.run([
      "resume",
      c.output + "/checkpoint.json",
      "--output",
      resumed,
      "--max-tests",
      "500",
      "--quiet",
    ]),
    0,
  )
  let report = @fs.read_file(resumed + "/report.json").text()
  assert_true(report.contains("\"final_passed\": 3"))
  assert_true(report.contains("\"original_unchanged\": true"))
}

///|
async test "project/e2e resume rejects modified cache before creating output" {
  let c = project_fixture(1)
  let _ = @app.execute_project(c)
  let document = @json.parse(
    @fs.read_file(c.output + "/checkpoint.json").text(),
  )
  match document {
    Object(envelope) =>
      match envelope.get("engine") {
        Some(Object(engine)) => {
          let empty : Array[Json] = []
          engine["cache"] = empty.to_json()
          envelope["engine"] = engine.to_json()
          @fs.write_file(
            c.output + "/checkpoint.json",
            envelope.to_json().stringify(),
          )
        }
        _ => fail("missing engine")
      }
    _ => fail("missing envelope")
  }
  let out = c.output + "-tampered"
  let rejected = try {
    let _ = @app.run([
      "resume",
      c.output + "/checkpoint.json",
      "--output",
      out,
      "--quiet",
    ])
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(!@fs.exists(out))
}

///|
async test "project/e2e cancellation counts an active worker" {
  let base = project_fixture(1)
  let c = {
    ..base,
    predicate: {
      ..base.predicate,
      command: [probe_path(), "heartbeat", "keep.mbt"],
      failure: Timeout,
      stdout_rules: [],
      timeout_ms: 5000,
    },
  }
  @async.with_task_group(group => {
    let task = group.spawn(() => @app.execute_project(c), allow_failure=true)
    let marker = c.output + "/.moonreduce/work/run-1/keep.mbt"
    let mut started = false
    for _ in 0..<1000 {
      let observed = try @fs.read_file(marker).text() == "0" catch {
        _ => false
      }
      if observed {
        started = true
        break
      }
      @async.sleep(5)
    }
    assert_true(started)
    task.cancel()
    ignore(task.wait()) catch {
      _ => ()
    }
  })
  let report = @json.parse(@fs.read_file(c.output + "/report.json").text())
  assert_true(report is { "cancelled_tasks": 1, .. })
}
