///|
priv suberror ProjectError {
  ProjectError(String)
} derive(Debug)

///|
pub(all) struct ProjectRun {
  result : @project.ResultSummary
  output : String
  error : String?
}

///|
fn project_summary(snapshot : @manifest.Snapshot) -> Json {
  snapshot
  .files()
  .map(file => {
    let item : Json = {
      "path": file.0,
      "bytes": file.1.length(),
      "fnv1a": @source.digest(file.1),
    }
    item
  })
  .to_json()
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
  let events : Array[Json] = []
  let evidence : Array[Json] = []
  let live : Array[String] = []
  let mut error : String? = None
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
      let outcomes : Array[Array[Bool?]] = Array::makei(batch.length(), _ => [])
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
                let matched = @matcher.matches(c.predicate, observation, dir)
                outcomes[index].push(Some(matched))
                runs[index].push({
                  "trial": trial + 1,
                  "matched": matched,
                  "exit_code": observation.exit_code,
                  "timed_out": observation.timed_out,
                  "duration_ms": observation.duration_ms.to_json(),
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
              cost=outcomes[i].length(),
            ) {
            Err(e) => raise ProjectError(e)
            Ok(_) => ()
          }
          let event : Json = {
            "schema_version": 2,
            "id": batch[i].id,
            "phase": phase,
            "matched": matched.to_json(),
            "runs": runs[i].to_json(),
            "statistics": @stability.summarize(outcomes[i]).to_json(),
            "exit_code": observation.exit_code,
            "timed_out": observation.timed_out,
            "duration_ms": observation.duration_ms,
          }
          if events.length() < 10000 {
            events.push(event)
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
        w.cleanup(dir)
      }
      live.clear()
      persist_project(c, session, original, w.output, context, toolchain)
      if c.action == "check" && session.phase() == "reducing" {
        session.stop(Completed)
        break
      }
    }
  } catch {
    e =>
      if @async.is_cancellation_error(e) {
        session.stop(Cancelled)
        error = Some("MR_BUDGET_CANCELLED")
      } else {
        session.stop(ExecutionFailed)
        error = Some("MR_EXEC_FAILURE: " + e.to_string())
      }
  }
  @async.protect_from_cancel(resume_on_cancel=false, () => {
    for dir in live {
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
      "status": result.status.to_json(),
      "completed": result.status == Completed &&
      result.final_passed >= c.final_quorum,
      "jobs": c.jobs,
      "repeat": c.repeat,
      "quorum": c.quorum,
      "final_repeat": c.final_repeat,
      "final_quorum": c.final_quorum,
      "probabilistic": c.quorum < c.repeat || c.final_quorum < c.final_repeat,
      "baseline_statistics": session.baseline_statistics().to_json(),
      "final_statistics": session.final_statistics().to_json(),
      "evaluations": result.evaluations,
      "attempted_commands": attempts.val,
      "cache_hits": result.cache_hits,
      "baseline_passed": result.baseline_passed,
      "final_passed": result.final_passed,
      "original_unchanged": unchanged,
      "original_files": project_summary(original),
      "reduced_files": project_summary(result.best),
      "evidence": evidence.to_json(),
      "elapsed_ms": (@async.now() - start).to_json(),
    }
    save(w.output + "/report.json", report.stringify(indent=2))
    save(
      w.output + "/report.md",
      "# Project reduction\n\nStatus: " +
      result.status.to_json().stringify() +
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
      c.predicate.command.to_json().stringify() +
      "\n",
    )
    let diff = StringBuilder()
    let reduced = result.best.files()
    for file in original.files() {
      if !file.0.has_suffix(".mbt") {
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
    { result, output: w.output, error }
  })
}
