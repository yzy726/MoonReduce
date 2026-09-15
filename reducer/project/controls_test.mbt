///|
test "project pass controls reject unknown names and score" {
  let original = @manifest.Snapshot::new([]).unwrap()
  assert_true(
    @project.Session::new(original, [], [], [], pass_include=["unknown"])
    is Err(_),
  )
  assert_true(
    @project.Session::new(original, [], [], [], score="unknown") is Err(_),
  )
}

///|
test "project pass exclusion disables file removal" {
  let original = @manifest.Snapshot::new([("a.mbt", b"x")]).unwrap()
  let s = @project.Session::new(original, [], [], [], pass_include=["file"], pass_exclude=[
    "file",
  ]).unwrap()
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_eq(s.result().best.key(), original.key())
  assert_eq(s.result().evaluations, 5)
}

///|
test "project score can choose fewer tokens over fewer bytes" {
  let original = @manifest.Snapshot::new([
    ("a.mbt", b"a+b"),
    ("b.mbt", b"longname"),
  ]).unwrap()
  let s = @project.Session::new(original, [], [], [], score="tokens", pass_include=[
    "file",
  ]).unwrap()
  answer(s, true)
  answer(s, true)
  for c in s.next_batch() {
    s.record(c.id, true).unwrap()
  }
  assert_eq(s.result().best.files(), [("b.mbt", b"longname")])
}
