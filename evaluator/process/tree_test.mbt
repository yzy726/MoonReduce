///|
async test "regr_timeout_reaps_owned_descendant_without_shell" {
  let root = @fs.tmpdir(prefix="moonreduce-owned-tree-")
  let heartbeat = root + "/heartbeat"
  let probe = @fs.realpath(
    @env.get_env_var("MR_PROCESS_PROBE").unwrap_or(
      "_build/native/debug/build/tools/process_probe/process_probe.exe",
    ),
  )
  let e = @process.run(
    {
      ..@model.default_predicate([probe, "parent", heartbeat]),
      timeout_ms: 1200,
    },
    ".",
  )
  assert_true(e.timed_out)
  // A missing heartbeat is a fixture failure, never evidence of termination.
  assert_true(@fs.exists(heartbeat))
  @async.sleep(200)
  let before = @fs.read_file(heartbeat).text()
  @async.sleep(400)
  assert_eq(@fs.read_file(heartbeat).text(), before)
}

///|
async test "e2e_cancellation_reaps_owned_descendant_without_shell" {
  let root = @fs.tmpdir(prefix="moonreduce-cancel-tree-")
  let heartbeat = root + "/heartbeat"
  let probe = @fs.realpath(
    @env.get_env_var("MR_PROCESS_PROBE").unwrap_or(
      "_build/native/debug/build/tools/process_probe/process_probe.exe",
    ),
  )
  let result = @async.with_timeout_opt(1200, () => {
    @process.run(
      {
        ..@model.default_predicate([probe, "parent", heartbeat]),
        timeout_ms: 5000,
      },
      ".",
    )
  })
  assert_true(result is None)
  assert_true(@fs.exists(heartbeat))
  @async.sleep(200)
  let before = @fs.read_file(heartbeat).text()
  @async.sleep(400)
  assert_eq(@fs.read_file(heartbeat).text(), before)
}
