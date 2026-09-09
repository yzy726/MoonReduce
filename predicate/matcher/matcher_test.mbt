///|
fn observation(
  code : Int,
  timeout : Bool,
  out : String,
  err : String,
) -> @model.Evaluation {
  {
    exit_code: code,
    timed_out: timeout,
    stdout: out,
    stderr: err,
    stdout_truncated: false,
    stderr_truncated: false,
    duration_ms: 1L,
  }
}

///|
test "valid/exit and timeout are distinct failure classes" {
  let p = @model.default_predicate(["tool"])
  for code in [0, 1, 2, 127, -1] {
    assert_eq(
      @matcher.matches(p, observation(code, false, "", ""), ""),
      code != 0,
    )
    assert_false(@matcher.matches(p, observation(code, true, "", ""), ""))
    assert_eq(
      @matcher.matches(
        { ..p, failure: @model.ExitCode(2) },
        observation(code, false, "", ""),
        "",
      ),
      code == 2,
    )
    assert_true(
      @matcher.matches(
        { ..p, failure: @model.Timeout },
        observation(code, true, "", ""),
        "",
      ),
    )
  }
}

///|
test "valid/output rules AND across streams" {
  let p = {
    ..@model.default_predicate(["tool"]),
    stdout_rules: [{ text: "hello", negate: false, ignore_case: false }],
    stderr_rules: [{ text: "wrong", negate: true, ignore_case: true }],
  }
  assert_true(
    @matcher.matches(p, observation(1, false, "hello there", "error"), ""),
  )
  assert_false(@matcher.matches(p, observation(1, false, "HELLO", "error"), ""))
  assert_false(@matcher.matches(p, observation(1, false, "hello", "WRONG"), ""))
  assert_false(@matcher.matches(p, observation(0, false, "hello", "error"), ""))
}

///|
test "valid/normalization" {
  assert_eq(
    @matcher.normalize("C:/work/a:12:3\r\nerr", "C:/work", true),
    "<workspace>/a:<n>:<n>\nerr",
  )
  assert_eq(@matcher.normalize("x:123 blah 44", "", true), "x:<n> blah 44")
  assert_eq(@matcher.normalize("a:1\r\nb", "", false), "a:1\nb")
}

///|
test "edge/negative rules reject truncated evidence" {
  let p = {
    ..@model.default_predicate(["tool"]),
    stdout_rules: [{ text: "absent", negate: true, ignore_case: false }],
  }
  let e = { ..observation(1, false, "x", ""), stdout_truncated: true }
  assert_false(@matcher.matches(p, e, ""))
}
