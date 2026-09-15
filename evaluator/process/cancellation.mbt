///|
/// Clean only descendants of the PID supplied by the child-process runtime.
/// Commands use direct argv and are bounded independently of the predicate.
fn tree_cancel(error : Ref[String?]) -> @child.CancellationHandler {
  CancellationHandler(pid => {
    @async.protect_from_cancel(() => {
      let hard = @child.hard_cancel()
      defer (hard.0)(pid)
      try {
        let cleaned = @async.with_timeout_opt(3000, () => {
          if @env.get_env_var("OS") == Some("Windows_NT") {
            let (code, _, _) = @child.collect_output(
              "taskkill.exe",
              ["/PID", pid.to_string(), "/T", "/F"],
              no_console_window=true,
            )
            if code != 0 {
              raise ProcessError(
                "MR_EXEC_CLEANUP: taskkill did not confirm termination",
              )
            }
          } else {
            let (code, data, _) = @child.collect_output("ps", [
              "-eo", "pid=,ppid=",
            ])
            if code != 0 {
              raise ProcessError(
                "MR_EXEC_CLEANUP: cannot enumerate descendants",
              )
            }
            let pairs : Array[(Int, Int)] = []
            for line in data.text().split("\n") {
              let fields = line
                .to_owned()
                .replace_all(old="\t", new=" ")
                .split(" ")
                .filter(s => !s.is_empty())
                .to_array()
              if fields.length() == 2 {
                pairs.push(
                  (@string.parse_int(fields[0]), @string.parse_int(fields[1])),
                )
              }
            }
            let descendants = [pid]
            let mut i = 0
            while i < descendants.length() {
              for pair in pairs {
                if pair.0 > 1 &&
                  pair.1 == descendants[i] &&
                  !descendants.contains(pair.0) {
                  descendants.push(pair.0)
                }
              }
              i += 1
            }
            let mut i = descendants.length() - 1
            while i > 0 {
              // The child may have exited since enumeration. An already exited
              // process needs no further action; the root is reaped by the runtime.
              ignore(
                @child.collect_output("kill", [
                  "-KILL",
                  descendants[i].to_string(),
                ]),
              )
              i -= 1
            }
            if descendants.length() > 1 {
              @async.sleep(50)
            }
          }
        })
        if cleaned is None {
          error.val = Some(
            "MR_EXEC_CLEANUP: descendant cleanup exceeded 3000 ms",
          )
        }
      } catch {
        ProcessError(message) => error.val = Some(message)
        e => error.val = Some("MR_EXEC_CLEANUP: " + e.to_string())
      }
    })
  })
}
