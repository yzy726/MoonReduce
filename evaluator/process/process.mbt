///|
/// Expected adapter failures are distinct from an executed command's nonzero exit.
pub suberror ProcessError {
  ProcessError(String)
} derive(Debug)

///|
priv struct Capture {
  bytes : Array[Byte]
  mut truncated : Bool
}

///|
async fn drain(
  reader : @child.ReadFromProcess,
  capture : Capture,
  limit : Int,
) -> Unit {
  while reader.read_some(max_len=8192) is Some(chunk) {
    let keep = (limit - capture.bytes.length()).max(0).min(chunk.length())
    for i in 0..<keep {
      capture.bytes.push(chunk[i])
    }
    if keep < chunk.length() {
      capture.truncated = true
    }
    // Continue draining after the limit so a noisy child cannot block on a full pipe.
  }
}

///|
/// Execute direct argv in cwd, concurrently draining bounded stdout and stderr.
/// Non-UTF8 process output is decoded lossily; source input is always strict UTF8.
pub async fn run(
  spec : @model.PredicateSpec,
  cwd : String,
) -> @model.Evaluation {
  if spec.command.is_empty() || spec.command[0] == "" {
    raise ProcessError("MR_EXEC_COMMAND: empty argv")
  }
  if spec.timeout_ms <= 0 || spec.output_limit <= 0 {
    raise ProcessError("MR_EXEC_LIMIT: invalid limits")
  }
  let start = @async.now()
  let out = Capture::{ bytes: [], truncated: false }
  let err = Capture::{ bytes: [], truncated: false }
  let (read_out, write_out) = @child.read_from_process()
  defer read_out.close()
  let (read_err, write_err) = @child.read_from_process()
  defer read_err.close()
  let cleanup_error : Ref[String?] = Ref(None)
  let result = @async.with_timeout_opt(spec.timeout_ms, () => {
    @async.with_task_group(group => {
      let command = group.spawn(() => {
        @child.run(
          spec.command[0],
          spec.command[1:],
          extra_env=spec.environment,
          cwd~,
          stdout=write_out,
          stderr=write_err,
          no_console_window=true,
          cancel_handler=tree_cancel(cleanup_error),
        )
      })
      group.spawn_bg(() => drain(read_out, out, spec.output_limit))
      group.spawn_bg(() => drain(read_err, err, spec.output_limit))
      command.wait()
    })
  })
  if cleanup_error.val is Some(message) {
    raise ProcessError(message)
  }
  {
    exit_code: result.unwrap_or(-1),
    timed_out: result is None,
    stdout: @utf8.decode_lossy(Bytes::from_array(out.bytes)),
    stderr: @utf8.decode_lossy(Bytes::from_array(err.bytes)),
    stdout_truncated: out.truncated,
    stderr_truncated: err.truncated,
    duration_ms: @async.now() - start,
  }
}
