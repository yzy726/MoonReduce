///|
test "valid/baseline reduction and three uncached final checks" {
  let s = @engine.Session::new("noise\nKEEP\nmore\n")
  let seen : Array[String] = []
  while s.next() is Some(c) {
    seen.push(c)
    s.record(c.contains("KEEP"))
  }
  let r = s.result()
  assert_eq(r.status, Completed)
  assert_eq(r.best, "KEEP\n")
  assert_eq(r.baseline_passed, 2)
  assert_eq(r.final_passed, 3)
  assert_eq(seen[0], "noise\nKEEP\nmore\n")
  assert_eq(seen[1], seen[0])
  for i in (seen.length() - 3)..<seen.length() {
    assert_eq(seen[i], "KEEP\n")
  }
}

///|
test "invalid/baseline mismatch and unstable baseline" {
  let s = @engine.Session::new("a")
  ignore(s.next())
  s.record(false)
  assert_eq(s.next(), None)
  assert_eq(s.result().status, BaselineFailed)
  let s = @engine.Session::new("b")
  ignore(s.next())
  s.record(true)
  ignore(s.next())
  s.record(false)
  assert_eq(s.result().status, BaselineUnstable)
}

///|
test "property/accepted history strictly decreases bytes" {
  for input in ["a\nb\nc\n", "你好 world", "123 + 999", "{\"abc\"}", ""] {
    let s = @engine.Session::new(input)
    while s.next() is Some(_) {
      s.record(true)
    }
    let r = s.result()
    assert_eq(r.status, Completed)
    for i in 1..<r.accepted_sizes.length() {
      assert_true(r.accepted_sizes[i] < r.accepted_sizes[i - 1])
    }
  }
}

///|
test "invalid/final mismatch is never completed" {
  let s = @engine.Session::new("")
  ignore(s.next())
  s.record(true)
  ignore(s.next())
  s.record(true)
  ignore(s.next())
  s.record(false)
  assert_eq(s.result().status, FinalFailed)
}
