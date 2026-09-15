///|
async test "maintenance config validates without executing commands" {
  let dir = @fs.tmpdir(prefix="moonreduce-config-validate-")
  let path = dir + "/config.json"
  @fs.write_file(
    path,
    "{\"project\":true,\"command\":[\"does-not-exist\"]}",
    create_mode=CreateNew,
  )
  assert_eq(
    maintenance(["config", "validate", path]),
    "Configuration valid (schema 1)\n",
  )
  @fs.write_file(path, "{\"project\":true,\"jobs\":0,\"command\":[\"unused\"]}")
  let invalid = try {
    let _ = maintenance(["config", "validate", path])
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
async test "maintenance rejects missing explicit cache clean run" {
  let invalid = try {
    let _ = maintenance(["cache", "clean"])
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
async test "maintenance cache clean preserves candidate and sealed replay state" {
  let root = @fs.tmpdir(prefix="moonreduce-cache-e2e-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(input + "/keep.mbt", "// noise\nKEEP\n", create_mode=CreateNew)
  let probe = @fs.realpath(
    "_build/native/debug/build/tools/process_probe/process_probe.exe",
  )
  let c = @config.parse(
    [
      "reduce",
      "--project",
      "--workspace",
      input,
      "--output",
      root + "/out",
      "--expect",
      "0",
      "--stdout-contains",
      "KEEP",
      "--max-tests",
      "40",
      "--",
      probe,
      "contains",
      "keep.mbt",
    ],
    None,
  ).unwrap()
  let result = execute_project(c)
  assert_eq(result.result.final_passed, 3)
  let before = @fs.read_file(c.output + "/reduced/keep.mbt").text()
  let stat = @json.parse(maintenance(["cache", "stats", "--run", c.output]))
  assert_true(stat is { "entries": Number(n, ..), .. } && n > 0.0)
  let diff = maintenance(["diff", c.output + "/report.json"])
  assert_true(diff.contains("keep.mbt"))
  let _ = maintenance(["cache", "clean", "--run", c.output])
  verify_bundle(c.output)
  let cleared = @json.parse(maintenance(["cache", "stats", "--run", c.output]))
  assert_true(cleared is { "entries": 0, .. })
  assert_eq(@fs.read_file(c.output + "/reduced/keep.mbt").text(), before)
}
