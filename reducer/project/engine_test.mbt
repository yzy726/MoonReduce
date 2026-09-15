///|
fn session(
  files : Array[(String, Bytes)],
  budget? : Int = 100,
) -> @project.Session raise {
  let snapshot = match @manifest.Snapshot::new(files) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  match @project.Session::new(snapshot, [], [], [], max_tests=budget) {
    Ok(s) => s
    Err(e) => fail(e)
  }
}

///|
fn answer(s : @project.Session, matched : Bool) -> Unit raise {
  for c in s.next_batch() {
    assert_eq(s.record(c.id, matched), Ok(()))
  }
}

///|
test "project engine/two baseline attempts before candidates" {
  let s = session([("a.mbt", b"keep")])
  assert_eq(s.phase(), "baseline")
  answer(s, true)
  assert_eq(s.phase(), "baseline")
  answer(s, true)
  assert_eq(s.phase(), "reducing")
}

///|
test "project engine/baseline mismatch stops" {
  let s = session([("a.mbt", b"keep")])
  answer(s, false)
  assert_eq(s.result().status, BaselineFailed)
  assert_eq(s.next_batch().length(), 0)
}

///|
test "project engine/record requires issued id" {
  let s = session([("a.mbt", b"keep")])
  assert_true(s.record(99, true) is Err(_))
}

///|
test "project engine/pending batch is stable" {
  let s = session([("a.mbt", b"keep")])
  let a = s.next_batch()
  let b = s.next_batch()
  assert_eq(a[0].id, b[0].id)
  assert_eq(a[0].snapshot.key(), b[0].snapshot.key())
}

///|
test "project engine/final validation bypasses cache three times" {
  let s = session([("a.mbt", b"")])
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_eq(s.result().final_passed, 3)
  assert_eq(s.result().status, Completed)
}

///|
test "project engine/reject budget below baseline and finals" {
  let snapshot = match @manifest.Snapshot::new([]) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  assert_true(
    @project.Session::new(snapshot, [], [], [], max_tests=4) is Err(_),
  )
}

///|
test "project engine/reserves final attempts under budget" {
  let s = session([("a.mbt", b"keep")], budget=5)
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_eq(s.result().evaluations, 5)
  assert_eq(s.result().final_passed, 3)
}

///|
test "project engine/protected file never removed" {
  let snapshot = match
    @manifest.Snapshot::new([("a.mbt", b"keep"), ("b.mbt", b"noise")]) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  let s = match @project.Session::new(snapshot, [], ["a.mbt"], []) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_eq(s.result().best.files(), [("a.mbt", b"keep")])
}

///|
test "project engine/out of order batch answers choose same best" {
  let a = session([("a.mbt", b"a"), ("b.mbt", b"long")])
  let b = session([("a.mbt", b"a"), ("b.mbt", b"long")])
  answer(a, true)
  answer(a, true)
  answer(b, true)
  answer(b, true)
  let aa = a.next_batch()
  let bb = b.next_batch()
  for c in aa {
    assert_eq(a.record(c.id, true), Ok(()))
  }
  for i = bb.length() - 1; i >= 0; i = i - 1 {
    assert_eq(b.record(bb[i].id, true), Ok(()))
  }
  assert_eq(a.result().best.key(), b.result().best.key())
}

///|
test "project engine/final mismatch cannot report success" {
  let s = session([("a.mbt", b"")], budget=5)
  answer(s, true)
  answer(s, true)
  assert_true(!s.next_batch().is_empty())
  assert_eq(s.phase(), "final")
  answer(s, false)
  assert_eq(s.result().status, FinalFailed)
}

///|
test "project engine/cancel preserves original before acceptance" {
  let s = session([("a.mbt", b"keep")])
  s.stop(Cancelled)
  assert_eq(s.result().status, Cancelled)
  assert_eq(s.result().best.files(), [("a.mbt", b"keep")])
  assert_true(s.next_batch().is_empty())
}

///|
test "project engine/published request cannot mutate internal batch" {
  let s = session([("a.mbt", b"keep")])
  let batch = s.next_batch()
  batch.clear()
  assert_eq(s.next_batch().length(), 1)
}
