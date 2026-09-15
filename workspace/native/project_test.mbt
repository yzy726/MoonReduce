///|
async test "project/e2e materializes multiple replacements and file deletion" {
  let root = @fs.tmpdir(prefix="moonreduce-project-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(input + "/a.mbt", "first", create_mode=CreateNew)
  @fs.write_file(input + "/b.mbt", "second", create_mode=CreateNew)
  @fs.write_file(
    input + "/moon.mod",
    "name = \"test/project\"",
    create_mode=CreateNew,
  )
  let w = @native.prepare_project(input, root + "/out", [])
  let original = w.snapshot()
  let removed = match original.remove("b.mbt") {
    Ok(s) => s
    Err(e) => fail(e)
  }
  let changed = match removed.replace("a.mbt", b"x") {
    Ok(s) => s
    Err(e) => fail(e)
  }
  let copy = w.materialize_snapshot(changed)
  assert_eq(@fs.read_file(copy + "/a.mbt").text(), "x")
  assert_true(!@fs.exists(copy + "/b.mbt"))
  assert_true(@fs.exists(copy + "/moon.mod"))
  assert_true(w.original_unchanged())
  w.cleanup(copy)
  assert_true(!@fs.exists(copy))
  assert_eq(original.files().length(), 3)
}

///|
async test "project/e2e copies remain independent" {
  let root = @fs.tmpdir(prefix="moonreduce-project-independent-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(input + "/a.mbt", "x", create_mode=CreateNew)
  let w = @native.prepare_project(input, root + "/out", [])
  let first = w.materialize_snapshot(w.snapshot())
  let second = w.materialize_snapshot(w.snapshot())
  @fs.write_file(first + "/a.mbt", "polluted")
  assert_eq(@fs.read_file(second + "/a.mbt").text(), "x")
  w.cleanup(first)
  w.cleanup(second)
  assert_true(w.original_unchanged())
}

///|
async test "project/e2e exports entire selected snapshot" {
  let root = @fs.tmpdir(prefix="moonreduce-project-export-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(input + "/a.mbt", "x", create_mode=CreateNew)
  @fs.write_file(input + "/b.mbt", "y", create_mode=CreateNew)
  let w = @native.prepare_project(input, root + "/out", [])
  let best = match w.snapshot().remove("b.mbt") {
    Ok(s) => s
    Err(e) => fail(e)
  }
  w.export_snapshot(best)
  assert_true(@fs.exists(root + "/out/reduced/a.mbt"))
  assert_true(!@fs.exists(root + "/out/reduced/b.mbt"))
  assert_true(w.original_unchanged())
}
