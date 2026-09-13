///|
test "valid/cache skips repeated reduction candidates only" {
  let s = @engine.Session::new("a\nb\nc\n")
  let seen : Map[String, Bool] = Map([])
  while s.next() is Some(c) {
    if s.phase_name() == "reducing" {
      assert_false(seen.contains(c))
      seen[c] = true
    }
    s.record(c.contains("b"))
  }
  assert_true(s.result().cache_hits > 0)
  assert_eq(s.result().final_passed, 3)
}

///|
test "valid/test budget reserves final verification" {
  let s = @engine.Session::new("a\nb", budget={
    max_tests: 5,
    max_time_ms: 100L,
  })
  while s.next() is Some(_) {
    s.record(true)
  }
  assert_eq(s.result().status, BudgetExhausted)
  assert_eq(s.result().evaluations, 5)
  assert_eq(s.result().final_passed, 3)
}

///|
test "valid/cancel retains last verified candidate without claiming completion" {
  let s = @engine.Session::new("a")
  ignore(s.next())
  s.record(true)
  ignore(s.next())
  s.record(true)
  s.cancel()
  assert_eq(s.next(), None)
  assert_eq(s.result().best, "a")
  assert_eq(s.result().status, Cancelled)
}

///|
test "valid/time limit stops at current best" {
  let s = @engine.Session::new("a", budget={ max_tests: 100, max_time_ms: 10L })
  s.elapsed(11L)
  assert_eq(s.next(), None)
  assert_eq(s.result().status, BudgetExhausted)
}

///|
test "invalid/zero budget never executes" {
  let s = @engine.Session::new("a", budget={ max_tests: 0, max_time_ms: 10L })
  assert_eq(s.next(), None)
  assert_eq(s.result().status, BudgetExhausted)
}
