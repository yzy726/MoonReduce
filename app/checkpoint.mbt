///|
/// Canonical parser-compatible configuration for private local checkpoints.
/// Environment overrides are needed for exact replay and stay in this file.
fn checkpoint_config(c : @config.Config) -> Json {
  let expect = match c.predicate.failure {
    NonZero => "nonzero"
    Timeout => "timeout"
    ExitCode(n) => n.to_string()
  }
  {
    "project": true,
    "score": c.score,
    "pass_include": c.pass_include.to_json(),
    "pass_exclude": c.pass_exclude.to_json(),
    "keep_workdir": c.keep_workdir,
    "schema_version": 1,
    "stdout_regex": c.advanced.stdout_regex.to_json(),
    "stderr_regex": c.advanced.stderr_regex.to_json(),
    "diagnostic_code": c.advanced.diagnostic_codes.to_json(),
    "test_name": c.advanced.test_names.to_json(),
    "normalize": c.advanced.normalize,
    "crash": c.advanced.crash,
    "wrapper": c.advanced.wrapper,
    "differential": c.advanced.differential,
    "timeout_tolerance": c.advanced.timeout_tolerance_ms,
    "reference": c.reference.to_json(),
    "workspace": c.workspace,
    "include": c.includes.to_json(),
    "protect": c.protect.to_json(),
    "ignore": c.ignore.to_json(),
    "jobs": c.jobs,
    "repeat": c.repeat,
    "quorum": c.quorum,
    "consecutive": c.consecutive,
    "final_repeat": c.final_repeat,
    "final_quorum": c.final_quorum,
    "cwd": c.predicate.cwd,
    "expect": expect,
    "command": c.predicate.command.to_json(),
    "timeout": c.predicate.timeout_ms,
    "output_limit": c.predicate.output_limit,
    "max_tests": c.budget.max_tests,
    "max_time": c.budget.max_time_ms.to_json(),
    "stdout_contains": c.predicate.stdout_rules
    .filter(r => !r.negate)
    .map(r => r.text)
    .to_json(),
    "stdout_not_contains": c.predicate.stdout_rules
    .filter(r => r.negate)
    .map(r => r.text)
    .to_json(),
    "stderr_contains": c.predicate.stderr_rules
    .filter(r => !r.negate)
    .map(r => r.text)
    .to_json(),
    "stderr_not_contains": c.predicate.stderr_rules
    .filter(r => r.negate)
    .map(r => r.text)
    .to_json(),
    "ignore_case": (c.predicate.stdout_rules + c.predicate.stderr_rules)
    .iter()
    .any(r => r.ignore_case),
    "strip_locations": c.predicate.strip_locations,
    "environment": c.predicate.environment.to_json(),
  }
}

///|
fn checkpoint_context(c : @config.Config, toolchain : String) -> String {
  let env = c.predicate.environment.iter().to_array()
  env.sort_by((a, b) => a.0.compare(b.0))
  // Arrays make order explicit; worker count and extended budgets are allowed
  // to change, while all evaluation-affecting settings must remain identical.
  let context : Json = [
    c.score.to_json(),
    c.pass_include.to_json(),
    c.pass_exclude.to_json(),
    c.advanced.to_json(),
    c.reference.to_json(),
    c.repeat.to_json(),
    c.quorum.to_json(),
    c.consecutive.to_json(),
    c.final_repeat.to_json(),
    c.final_quorum.to_json(),
    toolchain.to_json(),
    c.predicate.command.to_json(),
    c.predicate.cwd.to_json(),
    c.predicate.failure.to_json(),
    c.predicate.stdout_rules.to_json(),
    c.predicate.stderr_rules.to_json(),
    c.predicate.timeout_ms.to_json(),
    c.predicate.output_limit.to_json(),
    c.predicate.strip_locations.to_json(),
    env.to_json(),
    c.includes.to_json(),
    c.protect.to_json(),
    c.ignore.to_json(),
  ]
  context.stringify()
}

///|
async fn toolchain_identity() -> String {
  let spec = @model.default_predicate(["moon", "version", "--all"])
  let observation = @process.run(spec, ".")
  if observation.exit_code != 0 ||
    observation.timed_out ||
    observation.stdout_truncated {
    raise ProjectError(
      "MR_CHECKPOINT_TOOLCHAIN: cannot identify MoonBit toolchain",
    )
  }
  observation.stdout.replace_all(old="\r\n", new="\n")
}

///|
async fn save_checkpoint(path : String, document : Json) -> Unit {
  write_atomic(path, document.stringify(), (file, text) => {
    file.write_at(@source.encode(text), position=0L)
  })
}

///|
async fn write_atomic(
  path : String,
  text : String,
  writer : async (@fs.File, String) -> Unit,
) -> Unit {
  let temporary = path + ".tmp"
  let file = @fs.open(
    temporary,
    mode=WriteOnly,
    create_mode=CreateNew,
    permission=384,
    sync=Full,
  )
  let mut closed = false
  errdefer @async.protect_from_cancel(resume_on_cancel=false, () => {
    if !closed {
      file.close()
    }
    @fs.remove(temporary)
  })
  writer(file, text)
  file.sync()
  file.close()
  closed = true
  @async.protect_from_cancel(resume_on_cancel=false, () => {
    @fs.rename(temporary, path, replace=true)
  })
}

///|
async fn persist_project(
  c : @config.Config,
  session : @project.Session,
  original : @manifest.Snapshot,
  output : String,
  context : String,
  toolchain : String,
) -> Unit {
  let engine = match session.checkpoint(original, context) {
    Ok(value) => value
    Err(e) => raise ProjectError(e)
  }
  let document : Json = {
    "schema_version": 1,
    "configuration": checkpoint_config(c),
    "toolchain": toolchain,
    "engine": engine,
    "engine_sha256": @sha256.digest(@source.encode(engine.stringify())),
  }
  save_checkpoint(output + "/checkpoint.json", document)
}

///|
async fn resume_project(argv : Array[String]) -> Int {
  if argv.length() < 2 {
    raise ProjectError("MR_CFG_RESUME: checkpoint path required")
  }
  if @fs.kind(argv[1], follow_symlink=false) != Regular {
    raise ProjectError("MR_CHECKPOINT_PATH: expected regular checkpoint file")
  }
  let file = @fs.open(argv[1], mode=ReadOnly)
  defer file.close()
  let size = file.size()
  if size < 0L || size > 268435456L {
    raise ProjectError("MR_CHECKPOINT_SIZE: maximum 256 MiB")
  }
  let encoded = file.read_exactly_at(size.to_int(), position=0L)
  let text = match @source.decode(encoded) {
    Ok(text) => text
    Err(e) => raise ProjectError(e)
  }
  let document = @json.parse(text)
  match document {
    { "engine": engine, "engine_sha256": String(hash), .. } =>
      if @sha256.digest(@source.encode(engine.stringify())) != hash {
        raise ProjectError("MR_CHECKPOINT_CHECKSUM: engine content changed")
      }
    _ => {
      let absolute = @fs.realpath(argv[1]).replace_all(old="\\", new="/")
      let parent = match absolute.rev_split_once("/") {
        Some((parent, _)) => parent.to_owned()
        None =>
          raise ProjectError(
            "MR_CHECKPOINT_CHECKSUM: missing integrity evidence",
          )
      }
      verify_bundle(parent)
    }
  }
  let (configuration, engine, expected_toolchain) = match document {
    {
      "schema_version": 1,
      "configuration": configuration,
      "engine": engine,
      "toolchain": String(version),
      ..
    } => (configuration, engine, version)
    _ => raise ProjectError("MR_CHECKPOINT_FORMAT: unsupported envelope")
  }
  let toolchain = toolchain_identity()
  if expected_toolchain != toolchain {
    raise ProjectError("MR_CHECKPOINT_TOOLCHAIN: toolchain changed")
  }
  let args = ["reduce"]
  args.append(argv[2:].to_owned())
  if !args.contains("--output") {
    args.append([
      "--output",
      @fs.tmpdir(prefix="moonreduce-resume-") + "/result",
    ])
  }
  let c = match @config.parse(args, Some(configuration)) {
    Ok(c) => c
    Err(e) => raise ProjectError(e)
  }
  let result = execute_project(c, restore=engine)
  if !c.quiet {
    @stdio.stdout.write("Artifacts: " + result.output + "\n")
  }
  if result.error is Some(e) {
    @stdio.stderr.write(e + "\n")
  }
  result.result.status.exit_code()
}
