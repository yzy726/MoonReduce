///|
async fn artifact_json(path : String) -> Json {
  let bytes = read_bounded(path, 268435456)
  let text = match @source.decode(bytes) {
    Ok(s) => s
    Err(e) => raise ProjectError(e)
  }
  @json.parse(text)
}

///|
async fn replay_project(argv : Array[String]) -> Int {
  if argv.length() != 2 && (argv.length() != 4 || argv[2] != "--output") {
    raise ProjectError(
      "MR_CFG_REPLAY: replay report.json [--output NEW_DIRECTORY]",
    )
  }
  let path = @fs.realpath(argv[1]).replace_all(old="\\", new="/")
  let root = match path.rev_split_once("/") {
    Some((parent, "report.json")) => parent.to_owned()
    _ => raise ProjectError("MR_CFG_REPLAY: expected report.json")
  }
  verify_bundle(root)
  let (configuration, expected) = match
    artifact_json(root + "/checkpoint.json") {
    { "schema_version": 1, "configuration": c, "toolchain": String(t), .. } =>
      (c, t)
    _ => raise ProjectError("MR_CHECKPOINT_FORMAT: unsupported envelope")
  }
  let toolchain = toolchain_identity()
  if toolchain != expected {
    raise ProjectError("MR_CHECKPOINT_TOOLCHAIN: toolchain changed")
  }
  let output = if argv.length() == 4 {
    argv[3]
  } else {
    @fs.tmpdir(prefix="moonreduce-replay-") + "/result"
  }
  let c = match
    @config.parse(
      ["reduce", "--workspace", root + "/reduced", "--output", output],
      Some(configuration),
    ) {
    Ok(c) => c
    Err(e) => raise ProjectError(e)
  }
  let w = @workspace.prepare_project(c.workspace, output, [])
  let snapshot = w.snapshot()
  let live : Array[String] = []
  errdefer @async.protect_from_cancel(resume_on_cancel=false, () => {
    for dir in live {
      w.cleanup(dir)
    }
  })
  let results : Array[Bool?] = []
  let runs : Array[Json] = []
  let start = @async.now()
  for trial in 0..<c.final_repeat {
    let remaining = c.budget.max_time_ms - (@async.now() - start)
    if remaining <= 0L {
      break
    }
    let dir = w.materialize_snapshot(snapshot)
    live.push(dir)
    let spec = {
      ..c.predicate,
      timeout_ms: c.predicate.timeout_ms.min(remaining.to_int()),
    }
    let observation = @process.run(
      spec,
      w.working_directory(dir, c.predicate.cwd),
    )
    let mut reference_root = ""
    let reference = if c.reference.is_empty() {
      None
    } else {
      let left = c.budget.max_time_ms - (@async.now() - start)
      if left <= 0L {
        break
      }
      reference_root = w.materialize_snapshot(snapshot)
      live.push(reference_root)
      Some(
        @process.run(
          {
            ..c.predicate,
            command: c.reference,
            timeout_ms: c.predicate.timeout_ms.min(left.to_int()),
          },
          w.working_directory(reference_root, c.predicate.cwd),
        ),
      )
    }
    let matched = match
      @advanced.matches(c.advanced, observation, reference, dir, reference_root) {
      None => None
      Some(value) =>
        Some(
          value &&
          @matcher.matches(
            c.predicate,
            @advanced.prepare(c.advanced, observation, dir),
            dir,
          ),
        )
    }
    results.push(matched)
    runs.push({
      "trial": trial + 1,
      "matched": matched,
      "exit_code": observation.exit_code,
      "timed_out": observation.timed_out,
    })
    for path in live {
      w.cleanup(path)
    }
    live.clear()
  }
  for path in live {
    w.cleanup(path)
  }
  live.clear()
  let policy = @stability.Policy::new(
    c.final_repeat,
    c.final_quorum,
    consecutive=c.consecutive,
  ).unwrap()
  let decision = policy.decide(results)
  let unchanged = w.original_unchanged()
  // Recheck the sealed source after running external commands in copies.
  verify_bundle(root)
  let report : Json = {
    "schema_version": 1,
    "decision": decision.to_json(),
    "statistics": @stability.summarize(results).to_json(),
    "runs": runs.to_json(),
    "cache_used": false,
    "original_unchanged": unchanged,
    "toolchain": toolchain,
  }
  save(w.output + "/replay.json", report.stringify(indent=2))
  @stdio.stderr.write("Replay: " + w.output + "/replay.json\n")
  if decision == Interesting && unchanged {
    0
  } else {
    3
  }
}
