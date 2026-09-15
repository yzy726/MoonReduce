///|
test "project stability accepts configurable final four of five" {
  let original = @manifest.Snapshot::new([]).unwrap()
  let s = @project.Session::new(
    original,
    [],
    [],
    [],
    final_repeat=5,
    final_quorum=4,
  ).unwrap()
  answer(s, true)
  answer(s, true)
  answer(s, false)
  for _ in 0..<4 {
    answer(s, true)
  }
  assert_eq(s.result().status, Completed)
  assert_eq(s.result().final_passed, 4)
  assert_eq(s.result().evaluations, 7)
}

///|
test "project stability repeat reserves actual command budget" {
  let original = @manifest.Snapshot::new([("a.mbt", b"x")]).unwrap()
  let s = @project.Session::new(
    original,
    [],
    [],
    [],
    repeat=3,
    quorum=2,
    max_tests=12,
  ).unwrap()
  for _ in 0..<3 {
    answer(s, true)
  }
  assert_eq(s.result().evaluations, 3)
  for candidate in s.next_batch() {
    s.record_result(candidate.id, Some(false), cost=3).unwrap()
  }
  assert_eq(s.result().evaluations, 6)
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_true(s.result().evaluations <= 12)
  assert_eq(s.result().final_passed, 3)
}

///|
test "project stability tolerates one unstable baseline in three" {
  let original = @manifest.Snapshot::new([]).unwrap()
  let s = @project.Session::new(original, [], [], [], repeat=3, quorum=2).unwrap()
  answer(s, false)
  answer(s, true)
  answer(s, true)
  assert_eq(s.phase(), "reducing")
  assert_eq(s.result().baseline_passed, 2)
}

///|
test "project stability rejects inconsistent reply cost" {
  let s = session([("a.mbt", b"x")])
  let c = s.next_batch()[0]
  assert_true(s.record_result(c.id, Some(true), cost=2) is Err(_))
  assert_eq(s.result().evaluations, 0)
}

///|
test "project stability restores repeated accounting and rejects changed policy" {
  let original = @manifest.Snapshot::new([("a.mbt", b"KEEP")]).unwrap()
  let s = @project.Session::new(original, [], [], [], repeat=3, quorum=2).unwrap()
  for _ in 0..<3 {
    answer(s, true)
  }
  answer(s, false)
  let saved = s.checkpoint(original, "ctx").unwrap()
  let r = @project.Session::restore(
    saved,
    original,
    [],
    [],
    [],
    "ctx",
    repeat=3,
    quorum=2,
  ).unwrap()
  assert_eq(r.result().evaluations, 6)
  assert_eq(r.phase(), "reducing")
  assert_true(
    @project.Session::restore(saved, original, [], [], [], "ctx") is Err(_),
  )
}

///|
test "project stability inconclusive evidence cannot shrink the project" {
  let original = @manifest.Snapshot::new([("a.mbt", b"KEEP")]).unwrap()
  let s = @project.Session::new(original, [], [], [], max_tests=8).unwrap()
  answer(s, true)
  answer(s, true)
  for c in s.next_batch() {
    s.record_result(c.id, None).unwrap()
  }
  assert_eq(s.result().best.key(), original.key())
}

///|
test "project differential counts both commands in a trial" {
  let original = @manifest.Snapshot::new([]).unwrap()
  let s = @project.Session::new(
    original,
    [],
    [],
    [],
    command_cost=2,
    max_tests=10,
  ).unwrap()
  while !s.next_batch().is_empty() {
    for c in s.next_batch() {
      s.record_result(c.id, Some(true), cost=2).unwrap()
    }
  }
  assert_eq(s.result().evaluations, 10)
  assert_eq(s.result().final_passed, 3)
  assert_true(
    @project.Session::new(original, [], [], [], command_cost=2, max_tests=9)
    is Err(_),
  )
}
