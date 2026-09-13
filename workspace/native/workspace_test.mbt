///|
async test "e2e/workspace isolates candidates and exports original support files" {
  let root = @fs.tmpdir(prefix="moonreduce-workspace-test-")
  let input = root + "/输入 project"
  @fs.mkdir(input)
  @fs.write_file(input + "/a.mbt", "original", create_mode=CreateNew)
  @fs.write_file(
    input + "/moon.mod",
    "name = \"test/project\"",
    create_mode=CreateNew,
  )
  let w = @native.prepare(input, "a.mbt", root + "/output", [])
  let candidate = w.materialize("smaller")
  assert_eq(@fs.read_file(candidate + "/a.mbt").text(), "smaller")
  assert_eq(@fs.read_file(input + "/a.mbt").text(), "original")
  @fs.write_file(candidate + "/moon.mod", "corrupted")
  let next = w.materialize("again")
  assert_eq(@fs.read_file(next + "/moon.mod").text(), "name = \"test/project\"")
  w.export_best("best")
  assert_eq(@fs.read_file(root + "/output/reduced/a.mbt").text(), "best")
  assert_true(w.original_unchanged())
}

///|
async test "e2e/workspace rejects output over original and target traversal" {
  let root = @fs.tmpdir(prefix="moonreduce-path-test-")
  @fs.write_file(root + "/a.mbt", "x", create_mode=CreateNew)
  let bad = try {
    ignore(@native.prepare(root, "../a.mbt", root + "/out", []))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  let bad = try {
    ignore(@native.prepare(root, "a.mbt", root, []))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}
