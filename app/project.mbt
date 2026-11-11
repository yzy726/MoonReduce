///|
#derive(Debug)
priv suberror ProjectError {
  ProjectError(String)
}

///|
pub(all) struct ProjectRun {
  result : @project.ResultSummary
  output : String
  error : String?
}

///|
fn project_summary(snapshot : @manifest.Snapshot) -> Json {
  @json.ToJson::to_json(
    snapshot
    .files()
    .map(file => {
      let item : Json = {
        "path": file.0,
        "bytes": file.1.length(),
        "fnv1a": @source.digest(file.1),
        "sha256": @sha256.digest(file.1),
      }
      item
    }),
  )
}

///|
/// Execute a pure project session. A fixed batch is evaluated with up to jobs
/// workers in isolated directories; completion order cannot affect acceptance.
pub async fn execute_project(c : @config.Config, restore? : Json) -> ProjectRun {
  let output = if c.output == "" {
    @fs.tmpdir(prefix="moonreduce-project-check-") + "/result"
  } else {
    c.output
  }
  let w = @workspace.prepare_project(c.workspace, output, c.ignore)
  let original = w.snapshot()
  let toolchain = toolchain_identity()
  let context = checkpoint_context(c, toolchain)
  let command_cost = if c.reference.is_empty() { 1 } else { 2 }
  let session = match
    (if restore is Some(document) {
      @project.Session::restore(
        document,
        original,
        c.includes,
        c.protect,
        c.ignore,
        context,
        max_tests=c.budget.max_tests,
        repeat=c.repeat,
        quorum=c.quorum,
        consecutive=c.consecutive,
        final_repeat=c.final_repeat,
        final_quorum=c.final_quorum,
        command_cost~,
        score=c.score,
        pass_include=c.pass_include,
        pass_exclude=c.pass_exclude,
      )
    } else {
      @project.Session::new(
        original,
        c.includes,
        c.protect,
        c.ignore,
        max_tests=c.budget.max_tests,
        repeat=c.repeat,
        quorum=c.quorum,
        consecutive=c.consecutive,
        final_repeat=c.final_repeat,
        final_quorum=c.final_quorum,
        command_cost~,
        score=c.score,
        pass_include=c.pass_include,
        pass_exclude=c.pass_exclude,
      )
    }) {
    Ok(s) => s
    Err(e) => raise ProjectError(e)
  }
  persist_project(c, session, original, w.output, context, toolchain)
  let policy = @stability.Policy::new(
    c.repeat,
    c.quorum,
    consecutive=c.consecutive,
  ).unwrap()
  let start = @async.now()
  let attempts = Ref(0)
  let cancelled_tasks = Ref(0)
  let dropped_events = Ref(0)
  let events : Array[Json] = []
  let evidence : Array[Json] = []
  let live : Array[String] = []
  let mut error : String? = None
  let completed = @async.handle_cancellation(() => {
    try {
      while true {
        if @async.now() - start >= c.budget.max_time_ms {
          session.stop(BudgetExhausted)
          break
        }
        let batch = session.next_batch()
        if batch.is_empty() {
          break
        }
        let phase = session.phase()
        let observations : Array[@model.Evaluation?] = Array::make(
          batch.length(),
          None,
        )
        let outcomes : Array[Array[Bool?]] = Array::makei(batch.length(), _ => {
          []
        })
        let runs : Array[Array[Json]] = Array::makei(batch.length(), _ => [])
        let directories : Array[String] = []
        for candidate in batch {
          let dir = w.materialize_snapshot(candidate.snapshot)
          live.push(dir)
          directories.push(dir)
        }
        for base = 0; base < batch.length(); base = base + c.jobs {
          if @async.now() - start >= c.budget.max_time_ms {
            session.stop(BudgetExhausted)
            break
          }
          @async.with_task_group(group => {
            for index in base..<(base + c.jobs).min(batch.length()) {
              let index = index
              group.spawn_bg(() => {
                errdefer (if @async.is_being_cancelled() {
                  cancelled_tasks.val += 1
                })
                let count = if phase == "reducing" { c.repeat } else { 1 }
                for trial in 0..<count {
                  let remaining = c.budget.max_time_ms - (@async.now() - start)
                  if remaining <= 0L {
                    break
                  }
                  let dir = if trial == 0 {
                    directories[index]
                  } else {
                    let fresh = w.materialize_snapshot(batch[index].snapshot)
                    live.push(fresh)
                    fresh
                  }
                  let spec = {
                    ..c.predicate,
                    timeout_ms: c.predicate.timeout_ms.min(remaining.to_int()),
                  }
                  let cwd = w.working_directory(dir, c.predicate.cwd)
                  attempts.val += 1
                  let observation = @process.run(spec, cwd)
                  observations[index] = Some(observation)
                  let mut reference_root = ""
                  let reference = if c.reference.is_empty() {
                    None
                  } else {
                    let reference_remaining = c.budget.max_time_ms -
                      (@async.now() - start)
                    if reference_remaining <= 0L {
                      raise ProjectError("MR_BUDGET_TIME")
                    }
                    reference_root = w.materialize_snapshot(
                      batch[index].snapshot,
                    )
                    live.push(reference_root)
                    let reference_spec = {
                      ..c.predicate,
                      command: c.reference,
                      timeout_ms: c.predicate.timeout_ms.min(
                        reference_remaining.to_int(),
                      ),
                    }
                    attempts.val += 1
                    Some(
                      @process.run(
                        reference_spec,
                        w.working_directory(reference_root, c.predicate.cwd),
                      ),
                    )
                  }
                  let matched = match
                    @advanced.matches(
                      c.advanced,
                      observation,
                      reference,
                      dir,
                      reference_root,
                    ) {
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
                  outcomes[index].push(matched)
                  runs[index].push({
                    "trial": trial + 1,
                    "matched": matched,
                    "exit_code": observation.exit_code,
                    "timed_out": observation.timed_out,
                    "duration_ms": @json.ToJson::to_json(
                      observation.duration_ms,
                    ),
                  })
                }
              })
            }
          })
        }
        if session.phase() != "stopped" {
          for i in 0..<batch.length() {
            if @async.now() - start >= c.budget.max_time_ms {
              session.stop(BudgetExhausted)
              break
            }
            guard observations[i] is Some(observation) else { continue }
            let matched = if phase == "reducing" {
              match policy.decide(outcomes[i]) {
                Interesting => Some(true)
                Uninteresting => Some(false)
                Unresolved => None
              }
            } else {
              outcomes[i].get(0).unwrap_or(None)
            }
            match
              session.record_result(
                batch[i].id,
                matched,
                cost=outcomes[i].length() * command_cost,
              ) {
              Err(e) => raise ProjectError(e)
              Ok(_) => ()
            }
            let event : Json = {
              "schema_version": 2,
              "id": batch[i].id,
              "phase": phase,
              "matched": @json.ToJson::to_json(matched),
              "runs": @json.ToJson::to_json(runs[i]),
              "statistics": @json.ToJson::to_json(
                @stability.summarize(outcomes[i]),
              ),
              "exit_code": observation.exit_code,
              "timed_out": observation.timed_out,
              "duration_ms": observation.duration_ms,
            }
            if events.length() < 10000 {
              events.push(event)
            } else {
              dropped_events.val += 1
            }
            if phase != "reducing" {
              evidence.push(event)
            }
            if c.json_events {
              @stdio.stdout.write(event.stringify() + "\n")
            }
          }
        }
        for dir in live {
          if !c.keep_workdir {
            w.cleanup(dir)
          }
        }
        live.clear()
        persist_project(c, session, original, w.output, context, toolchain)
        if !c.quiet && !c.json_events {
          let progress = session.result()
          @stdio.stderr.write(
            "MoonReduce " +
            session.phase() +
            ": " +
            progress.evaluations.to_string() +
            " commands, " +
            @score.measure(progress.best).bytes.to_string() +
            " bytes\n",
          )
        }
        if c.action == "check" && session.phase() == "reducing" {
          session.stop(Completed)
          break
        }
      }
    } catch {
      e =>
        if @async.now() - start >= c.budget.max_time_ms {
          session.stop(BudgetExhausted)
        } else {
          session.stop(ExecutionFailed)
          error = Some("MR_EXEC_FAILURE: " + execution_error(e))
        }
    }
  })
  if completed is None {
    session.stop(Cancelled)
    error = Some("MR_BUDGET_CANCELLED")
  }
  @async.protect_from_cancel(() => {
    for dir in live {
      if c.keep_workdir {
        continue
      }
      w.cleanup(dir) catch {
        e => {
          session.stop(ExecutionFailed)
          error = Some("MR_INPUT_CLEANUP: " + e.to_string())
        }
      }
    }
    let unchanged = w.original_unchanged()
    if !unchanged {
      session.stop(ExecutionFailed)
      error = Some("MR_INPUT_CHANGED")
    }
    persist_project(c, session, original, w.output, context, toolchain)
    let result = session.result()
    w.export_snapshot(result.best)
    let report : Json = {
      "schema_version": 2,
      "mode": "project",
      "status": @json.ToJson::to_json(result.status),
      "completed": result.status == Completed &&
      result.final_passed >= c.final_quorum,
      "jobs": c.jobs,
      "score_strategy": c.score,
      "pass_include": @json.ToJson::to_json(c.pass_include),
      "pass_exclude": @json.ToJson::to_json(c.pass_exclude),
      "workdirs_retained": c.keep_workdir,
      "original_score": @json.ToJson::to_json(@score.measure(original)),
      "reduced_score": @json.ToJson::to_json(@score.measure(result.best)),
      "commands_per_trial": command_cost,
      "predicate_spec": @json.ToJson::to_json(c.advanced),
      "repeat": c.repeat,
      "quorum": c.quorum,
      "final_repeat": c.final_repeat,
      "final_quorum": c.final_quorum,
      "probabilistic": c.quorum < c.repeat || c.final_quorum < c.final_repeat,
      "baseline_statistics": @json.ToJson::to_json(
        session.baseline_statistics(),
      ),
      "final_statistics": @json.ToJson::to_json(session.final_statistics()),
      "evaluations": result.evaluations,
      "attempted_commands": attempts.val,
      "cancelled_tasks": cancelled_tasks.val,
      "dropped_events": dropped_events.val,
      "cache_hits": result.cache_hits,
      "baseline_passed": result.baseline_passed,
      "final_passed": result.final_passed,
      "original_unchanged": unchanged,
      "original_files": project_summary(original),
      "reduced_files": project_summary(result.best),
      "evidence": @json.ToJson::to_json(evidence),
      "elapsed_ms": @json.ToJson::to_json(@async.now() - start),
    }
    save(w.output + "/report.json", report.stringify(indent=2))
    save(
      w.output + "/report.md",
      "# Project reduction\n\nStatus: " +
      @json.ToJson::to_json(result.status).stringify() +
      "\n\nFinal verification: " +
      result.final_passed.to_string() +
      "/" +
      c.final_repeat.to_string() +
      "\n",
    )
    save(
      w.output + "/original-summary.json",
      project_summary(original).stringify(indent=2),
    )
    save(
      w.output + "/events.ndjson",
      events.map(e => e.stringify()).join("\n") + "\n",
    )
    save(
      w.output + "/reproduce.txt",
      "Working directory: reduced/" +
      c.predicate.cwd +
      "\nDirect argv: " +
      @json.ToJson::to_json(c.predicate.command).stringify() +
      "\n",
    )
    let diff = StringBuilder()
    let reduced = result.best.files()
    for file in original.files() {
      if !file.0.has_suffix(".mbt") &&
        file.0 != "moon.mod" &&
        file.0 != "moon.pkg" &&
        !file.0.has_suffix("/moon.pkg") {
        continue
      }
      let before = match @source.decode(file.1) {
        Ok(s) => s
        Err(_) => ""
      }
      let after = match reduced.iter().find_first(f => f.0 == file.0) {
        Some(f) =>
          match @source.decode(f.1) {
            Ok(s) => s
            Err(_) => ""
          }
        None => ""
      }
      if before != after {
        diff.write_string(@report.unified_diff(file.0, before, after))
      }
    }
    save(w.output + "/reduction.diff", diff.to_string())
    if error is Some(message) {
      save(w.output + "/error.txt", message)
    }
    seal_bundle(w.output, c, toolchain)
    { result, output: w.output, error, }
  })
}
