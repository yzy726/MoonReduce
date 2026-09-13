///|
async test "e2e/cleanup only removes owned evaluation copies" {
  let root = @fs.tmpdir(prefix="moonreduce-cleanup-test-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(input + "/a.mbt", "original", create_mode=@fs.CreateNew)
  let w = @native.prepare(input, "a.mbt", root + "/out", [])
  let dir = w.materialize("candidate")
  w.cleanup(dir)
  assert_false(@fs.exists(dir))
  assert_true(w.original_unchanged())
  let bad = try {
    w.cleanup(input)
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}

///|
async test "invalid/cleanup rejects altered owner marker" {
  let root = @fs.tmpdir(prefix="moonreduce-marker-test-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(input + "/a.mbt", "original", create_mode=@fs.CreateNew)
  let w = @native.prepare(input, "a.mbt", root + "/out", [])
  let dir = w.materialize("candidate")
  @fs.write_file(
    dir + "/.moonreduce-owner",
    "not ours",
    create_mode=@fs.TruncateExisting,
  )
  let bad = try {
    w.cleanup(dir)
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  assert_true(@fs.exists(dir))
}
