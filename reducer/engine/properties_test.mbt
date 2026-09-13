///|
test "property/ten independent runs converge to identical content" {
  let input = "// noise\nfn keep() { KEEP }\n// removable\n"
  let outputs : Array[String] = []
  for _ in 0..<10 {
    let s = @engine.Session::new(input)
    while s.next() is Some(c) {
      s.record(c.contains("KEEP"))
    }
    assert_eq(s.result().status, Completed)
    outputs.push(s.result().best)
  }
  for output in outputs {
    assert_eq(output, outputs[0])
  }
}

///|
test "property/exhaustive monotone subset predicates reach required one-minimal lines" {
  for mask in 1..<256 {
    let input = "A\nB\nC\nD\nE\nF\nG\nH\n"
    let required = ["A", "B", "C", "D", "E", "F", "G", "H"]
    let s = @engine.Session::new(input)
    while s.next() is Some(c) {
      let mut matched = true
      for i in 0..<8 {
        if (mask & (1 << i)) != 0 && !c.contains(required[i]) {
          matched = false
        }
      }
      s.record(matched)
    }
    let best = s.result().best
    assert_eq(s.result().status, Completed)
    for i in 0..<8 {
      assert_eq(best.contains(required[i]), (mask & (1 << i)) != 0)
    }
  }
}

///|
test "property/repeated next is idempotent until verdict supplied" {
  let s = @engine.Session::new("A\nB\n")
  assert_eq(s.next(), s.next())
  assert_eq(s.result().evaluations, 0)
  s.record(true)
  s.record(false)
  assert_eq(s.result().evaluations, 1)
}

///|
test "property/failed final keeps previously accepted source" {
  let s = @engine.Session::new("noise\nKEEP\n")
  while s.next() is Some(c) {
    s.record(s.phase_name() != "final" && c.contains("KEEP"))
  }
  assert_eq(s.result().status, FinalFailed)
  assert_true(s.result().best.contains("KEEP"))
  assert_eq(s.result().final_passed, 0)
}

///|
test "property/budget commands never exceed configured limit" {
  for limit in 0..<25 {
    let s = @engine.Session::new("noise\nKEEP\nmore\n", budget={
      max_tests: limit,
      max_time_ms: 10000L,
    })
    while s.next() is Some(c) {
      s.record(c.contains("KEEP"))
    }
    assert_true(s.result().evaluations <= limit)
    assert_true(s.result().best.contains("KEEP"))
  }
}

///|
test "property/cancellation during pending request preserves best" {
  let s = @engine.Session::new("KEEP\nnoise\n")
  ignore(s.next())
  s.record(true)
  ignore(s.next())
  s.record(true)
  ignore(s.next())
  s.cancel()
  s.record(true)
  assert_eq(s.result().evaluations, 2)
  assert_eq(s.result().status, Cancelled)
  assert_eq(s.result().best, "KEEP\nnoise\n")
}
