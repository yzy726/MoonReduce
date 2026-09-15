///|
test "quorum preserves inconclusive observations" {
  let p = @stability.Policy::new(5, 4).unwrap()
  assert_true(
    p.decide([Some(true), Some(true), Some(true), None, None]) is Unresolved,
  )
  assert_true(
    p.decide([Some(true), Some(true), Some(true), Some(true), None])
    is Interesting,
  )
  assert_true(
    p.decide([Some(false), Some(false), None, None, None]) is Uninteresting,
  )
}

///|
test "consecutive requires an uninterrupted run" {
  let p = @stability.Policy::new(5, 3, consecutive=true).unwrap()
  assert_true(
    p.decide([Some(true), Some(true), Some(false), Some(true), Some(true)])
    is Uninteresting,
  )
  assert_true(
    p.decide([Some(false), Some(true), Some(true), Some(true), Some(false)])
    is Interesting,
  )
  assert_true(
    p.decide([Some(true), None, Some(true), Some(false), Some(false)])
    is Unresolved,
  )
}

///|
test "policy validates bounded repeat and quorum" {
  for pair in [(0, 0), (101, 1), (3, 0), (3, 4), (-1, 1)] {
    assert_true(@stability.Policy::new(pair.0, pair.1) is Err(_))
  }
  assert_true(@stability.Policy::new(100, 100) is Ok(_))
}

///|
test "incomplete and excess evidence cannot pass" {
  let p = @stability.Policy::new(3, 2).unwrap()
  assert_true(p.decide([Some(true), Some(true)]) is Unresolved)
  assert_true(
    p.decide([Some(true), Some(true), Some(true), Some(true)]) is Unresolved,
  )
}

///|
test "rate and Wilson confidence use only resolved observations" {
  let s = @stability.summarize([Some(true), None, Some(false), Some(true)])
  assert_eq(s.attempts, 4)
  assert_eq(s.resolved, 3)
  assert_eq(s.passed, 2)
  assert_eq(s.rate, 2.0 / 3.0)
  assert_true(s.lower < s.rate && s.upper > s.rate)
  assert_true(s.lower >= 0.0 && s.upper <= 1.0)
  let empty = @stability.summarize([])
  assert_eq(empty.lower, 0.0)
  assert_eq(empty.upper, 1.0)
}
