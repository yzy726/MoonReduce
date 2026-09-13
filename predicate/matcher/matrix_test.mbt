///|
test "matrix/nonzero-zero" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(0, false, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/nonzero-one" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/nonzero-negative" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(-9, false, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/nonzero-timeout" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(-1, true, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/exact-zero" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: ExitCode(0),
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(0, false, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/exact-mismatch" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: ExitCode(23),
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/exact-match" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: ExitCode(23),
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(23, false, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/exact-timeout" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: ExitCode(-1),
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(-1, true, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/timeout-match" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: Timeout,
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(-1, true, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/timeout-normal" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: Timeout,
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(0, false, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/contains-prefix" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: false, ignore_case: false }],
  }
  let e = {
    ..observation(1, false, "error: message", ""),
    stdout_truncated: false,
  }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/contains-middle" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: false, ignore_case: false }],
  }
  let e = {
    ..observation(1, false, "an error here", ""),
    stdout_truncated: false,
  }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/contains-suffix" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "an error", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/contains-absent" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "warning", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/case-sensitive" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "ERROR", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "error", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/case-insensitive" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "ERROR", negate: false, ignore_case: true }],
  }
  let e = { ..observation(1, false, "error", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/case-negative" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "ERROR", negate: true, ignore_case: true }],
  }
  let e = { ..observation(1, false, "error", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/negative-absent" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: true, ignore_case: false }],
  }
  let e = { ..observation(1, false, "warning", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/negative-present" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: true, ignore_case: false }],
  }
  let e = { ..observation(1, false, "error", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/negative-empty-needle" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "", negate: true, ignore_case: false }],
  }
  let e = { ..observation(1, false, "anything", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/positive-empty-needle" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/unicode-contains" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "错误", negate: false, ignore_case: false }],
  }
  let e = {
    ..observation(1, false, "发生错误了", ""),
    stdout_truncated: false,
  }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/emoji-match" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "🙂", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "x🙂y", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/crlf-normalized" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "a\nb", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "a\r\nb", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/needle-crlf-normalized" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "a\r\nb", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "a\nb", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/positive-truncated-match" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "error", ""), stdout_truncated: true }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/positive-truncated-miss" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: false, ignore_case: false }],
  }
  let e = { ..observation(1, false, "warn", ""), stdout_truncated: true }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/negative-truncated-miss" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: true, ignore_case: false }],
  }
  let e = { ..observation(1, false, "warn", ""), stdout_truncated: true }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/negative-truncated-hit" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: true, ignore_case: false }],
  }
  let e = { ..observation(1, false, "error", ""), stdout_truncated: true }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/success-with-matching-output" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: NonZero,
    stdout_rules: [{ text: "error", negate: false, ignore_case: false }],
  }
  let e = { ..observation(0, false, "error", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}

///|
test "matrix/timeout-with-output" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: Timeout,
    stdout_rules: [{ text: "ready", negate: false, ignore_case: false }],
  }
  let e = { ..observation(-1, true, "ready", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), true)
}

///|
test "matrix/timeout-missing-output" {
  let p = {
    ..@model.default_predicate(["tool"]),
    failure: Timeout,
    stdout_rules: [{ text: "ready", negate: false, ignore_case: false }],
  }
  let e = { ..observation(-1, true, "", ""), stdout_truncated: false }
  assert_eq(@matcher.matches(p, e, ""), false)
}
