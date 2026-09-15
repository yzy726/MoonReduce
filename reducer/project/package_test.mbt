///|
test "project package candidate removes directory and its manifest" {
  let original = @manifest.Snapshot::new([
    ("keep.mbt", b"KEEP"),
    ("unused/moon.pkg", b""),
    ("unused/a.mbt", b"noise"),
  ]).unwrap()
  let s = @project.Session::new(original, [], [], [], pass_include=["package"]).unwrap()
  answer(s, true)
  answer(s, true)
  let candidates = s.next_batch()
  assert_eq(candidates.length(), 1)
  assert_eq(candidates[0].snapshot.files(), [("keep.mbt", b"KEEP")])
}

///|
test "project package candidate never removes protected support" {
  let original = @manifest.Snapshot::new([
    ("keep.mbt", b"KEEP"),
    ("unused/README.md", b"protected"),
    ("unused/a.mbt", b"noise"),
  ]).unwrap()
  let s = @project.Session::new(original, [], [], [], pass_include=["package"]).unwrap()
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_eq(s.result().best.key(), original.key())
}

///|
test "project opt-in manifest edits respect module whitelist" {
  let original = @manifest.Snapshot::new([
    ("keep.mbt", b"KEEP"),
    ("moon.mod", b"name = \"a/b\"\ndescription = \"noise\"\n"),
  ]).unwrap()
  let s = @project.Session::new(original, [], [], [], pass_include=["manifest"]).unwrap()
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  let files = s.result().best.files()
  assert_true(files.iter().any(f => f.0 == "keep.mbt"))
  assert_true(
    files
    .iter()
    .any(f => {
      f.0 == "moon.mod" &&
      @source.decode(f.1).unwrap().contains("name") &&
      !@source.decode(f.1).unwrap().contains("description")
    }),
  )
}
