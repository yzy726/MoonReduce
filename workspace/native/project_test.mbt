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

///|
async test "project/e2e ignored glob omits files from every copy" {
  let root = @fs.tmpdir(prefix="moonreduce-project-ignore-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.mkdir(input + "/vendor")
  @fs.write_file(input + "/a.mbt", "KEEP", create_mode=CreateNew)
  @fs.write_file(
    input + "/vendor/ignored.mbt",
    "ignored",
    create_mode=CreateNew,
  )
  let w = @native.prepare_project(input, root + "/out", ["**/ignored.mbt"])
  let dir = w.materialize_snapshot(w.snapshot())
  assert_true(!@fs.exists(dir + "/vendor/ignored.mbt"))
  assert_true(@fs.exists(input + "/vendor/ignored.mbt"))
  assert_true(w.original_unchanged())
  w.cleanup(dir)
}

///|
async test "regr_project_materialize_failure_cleans_owned_copy" {
  let root = @fs.tmpdir(prefix="moonreduce-project-failure-")
  let input = root + "/input"
  @fs.mkdir(input)
  @fs.write_file(input + "/a.mbt", "KEEP", create_mode=CreateNew)
  let w = @native.prepare_project(input, root + "/out", [])
  let invalid = match @manifest.Snapshot::new([("unknown.mbt", b"x")]) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  let rejected = try {
    ignore(w.materialize_snapshot(invalid))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(!@fs.exists(root + "/out/.moonreduce/work/run-1"))
  assert_true(w.original_unchanged())
  let next = w.materialize_snapshot(w.snapshot())
  w.cleanup(next)
}
