///|
/// Native result and artifact location.
pub(all) struct Run {
  result : @engine.ReductionResult
  output : String
  error : String?
}

///|
/// CLI reference for the initial commands and options.
pub fn help() -> String {
  let text =
    #|MoonReduce 0.1.0 — trusted-project testcase reduction
    #|moonreduce check [options] -- executable arg ...
    #|moonreduce reduce [options] -- executable arg ...
    #|moonreduce resume checkpoint.json [--output DIR] [--max-tests N]
    #|moonreduce replay report.json [--output DIR]
    #|moonreduce explain report.json
    #|moonreduce passes
    #|
    #|--workspace DIR         input project (default .)
    #|--project              reduce selected files as one project
    #|--include GLOB         selected source pattern (repeatable)
    #|--jobs N               project worker count, default 1
    #|--score bytes|tokens|lines
    #|--pass-include NAME / --pass-exclude NAME (repeatable)
    #|--keep-workdir         retain candidate copies for inspection
    #|--repeat N / --quorum K  project candidate repeats and acceptance threshold
    #|--consecutive          require consecutive successes
    #|--final-repeat N / --final-quorum K  final verification (default 3/3)
    #|--target FILE.mbt       one workspace-relative UTF8 source
    #|--output DIR            new output directory outside the original workspace
    #|--config FILE           JSON defaults; CLI overrides values
    #|--cwd DIR               command directory relative to workspace (default .)
    #|--expect nonzero|timeout|INTEGER
    #|--stdout-contains TEXT / --stderr-contains TEXT (repeatable)
    #|--stdout-not-contains TEXT / --stderr-not-contains TEXT (repeatable)
    #|--stdout-regex PATTERN / --stderr-regex PATTERN (project mode)
    #|--diagnostic-code CODE / --test-name NAME / --crash CLASS
    #|--normalize / --wrapper / --timeout-tolerance 10ms
    #|--reference ARG        repeat for each reference argv element
    #|--differential stdout|stderr|exit|any
    #|--ignore-case           case-insensitive output rules
    #|--strip-locations       normalize :line:column numbers
    #|--timeout 10s           per-command timeout, ms or s
    #|--max-time 600s         total wall-time budget
    #|--max-tests 1500        commands including 2 baseline + 3 final
    #|--output-limit 1048576  retained bytes per stream; extra output drained
    #|--ignore PATH           exact relative file/directory to omit (repeatable)
    #|--protect PATH          reject protected target (repeatable)
    #|--quiet / --verbose     suppress progress / report every command
    #|--json-events          NDJSON events (also saved in output)
    #|--help                 this reference
    #|
    #|JSON environment is an object of explicit environment overrides.
    #|Limits: 1000 files, 1 MiB/file, 16 MiB/project, 64 KiB/target.
    #|Only run trusted commands. Copies are not a security sandbox.
  text
}

///|
async fn save(path : String, data : String) -> Unit {
  @fs.write_file(path, data, create_mode=CreateNew)
}

///|
/// Drive the pure engine with real processes and preserve reports on interruption.
pub async fn execute(c : @config.Config) -> Run {
  let output = if c.output == "" {
    @fs.tmpdir(prefix="moonreduce-check-") + "/result"
  } else {
    c.output
  }
  let w = @workspace.prepare(c.workspace, c.target, output, c.ignore)
  let s = @engine.Session::new(w.original, budget=c.budget)
  let start = @async.now()
  let evidence : Array[Json] = []
  let events = StringBuilder()
  let mut events_size = 0
  let mut attempted_commands = 0
  let mut error : String? = None
  try {
    while true {
      s.elapsed(@async.now() - start)
      guard s.next() is Some(candidate) else { break }
      let phase = s.phase_name()
      let dir = w.materialize(candidate)
      let cwd = w.working_directory(dir, c.predicate.cwd)
      let remaining = c.budget.max_time_ms - (@async.now() - start)
      if remaining <= 0L {
        s.elapsed(c.budget.max_time_ms)
        break
      }
      let spec = {
        ..c.predicate,
        timeout_ms: c.predicate.timeout_ms.min(remaining.to_int()),
      }
      attempted_commands += 1
      let e = @process.run(spec, cwd)
      if @async.now() - start >= c.budget.max_time_ms {
        s.elapsed(c.budget.max_time_ms)
        break
      }
      let matched = @matcher.matches(c.predicate, e, dir)
      s.record(matched)
      w.cleanup(dir)
      let event : Json = {
        "schema_version": 1,
        "phase": phase,
        "matched": matched,
        "candidate_hash": @source.digest(@source.encode(candidate)),
        "bytes": @source.encode(candidate).length(),
        "exit_code": e.exit_code,
        "timed_out": e.timed_out,
        "duration_ms": e.duration_ms,
        "stdout_hash": @source.digest(@source.encode(e.stdout)),
        "stderr_hash": @source.digest(@source.encode(e.stderr)),
        "stdout_truncated": e.stdout_truncated,
        "stderr_truncated": e.stderr_truncated,
      }
      if phase != "reducing" {
        evidence.push(event)
      }
      let line = event.stringify() + "\n"
      if events_size + line.length() <= 4194304 {
        events.write_string(line)
        events_size += line.length()
      }
      if c.json_events {
        @stdio.stdout.write(line)
      } else if !c.quiet && (c.verbose || s.result().evaluations % 10 == 0) {
        let r = s.result()
        @stdio.stderr.write(
          "\{phase}: best=\{@source.encode(r.best).length()} bytes, commands=\{r.evaluations}/\{c.budget.max_tests}, cache=\{r.cache_hits}\n",
        )
      }
      if c.action == "check" && s.result().baseline_passed == 2 {
        s.stop(Completed)
        break
      }
    }
  } catch {
    e =>
      if @async.is_cancellation_error(e) {
        s.cancel()
        error = Some("MR_BUDGET_CANCELLED")
      } else {
        s.stop(ExecutionFailed)
        error = Some("MR_EXEC_FAILURE: " + e.to_string())
      }
  }
  @async.protect_from_cancel(resume_on_cancel=false, () => {
    let unchanged = w.original_unchanged()
    if !unchanged {
      s.stop(ExecutionFailed)
      error = Some("MR_INPUT_CHANGED: original changed during run")
    }
    let r = s.result()
    let elapsed = @async.now() - start
    w.export_best(r.best)
    save(
      w.output + "/report.json",
      @report.render_json(
        c,
        r,
        elapsed,
        unchanged,
        evidence~,
        attempted_commands=Some(attempted_commands),
      ).stringify(indent=2),
    )
    save(w.output + "/report.md", @report.markdown(c, r, elapsed, unchanged))
    save(
      w.output + "/reduction.diff",
      @report.unified_diff(c.target, r.original, r.best),
    )
    save(w.output + "/reproduce.txt", @report.reproduce(c))
    save(w.output + "/events.ndjson", events.to_string())
    if error is Some(message) {
      save(w.output + "/error.txt", message)
    }
    { result: r, output: w.output, error }
  })
}

///|
/// CLI dispatcher; returns the specified exit code after artifact writes complete.
pub async fn run(argv : Array[String]) -> Int {
  if argv.get(0) == Some("replay") {
    return replay_project(argv)
  }
  if argv.get(0) == Some("resume") {
    return resume_project(argv)
  }
  let mut json : Json? = None
  let mut i = 1
  while i < argv.length() {
    if argv[i] == "--" {
      break
    }
    if argv[i] == "--config" && i + 1 < argv.length() {
      let parsed = @json.parse(@fs.read_file(argv[i + 1]).text()) catch {
        e => {
          if @async.is_cancellation_error(e) {
            raise e
          }
          @stdio.stderr.write(
            "MR_CFG_FILE: cannot read or parse configuration JSON\n",
          )
          return 1
        }
      }
      json = Some(parsed)
      i += 1
    }
    i += 1
  }
  let c = match @config.parse(argv, json) {
    Err(e) => {
      @stdio.stderr.write(e + "\n")
      return 1
    }
    Ok(c) => c
  }
  match c.action {
    "help" => {
      @stdio.stdout.write(help() + "\n")
      0
    }
    "passes" => {
      @stdio.stdout.write(
        (@text.names() + @token.names() + @project.pass_names()).join("\n") +
        "\n",
      )
      0
    }
    "explain" => {
      @stdio.stdout.write(
        @json.parse(@fs.read_file(c.output).text()).stringify(indent=2) + "\n",
      )
      0
    }
    _ => {
      if c.project {
        let r = execute_project(c)
        if r.error is Some(e) {
          @stdio.stderr.write(e + "\n")
        }
        return r.result.status.exit_code()
      }
      let r = execute(c)
      if !c.quiet && !c.json_events {
        @stdio.stdout.write("Artifacts: " + r.output + "\n")
      }
      if r.error is Some(e) {
        @stdio.stderr.write(e + "\n")
      }
      r.result.status.exit_code()
    }
  }
}
