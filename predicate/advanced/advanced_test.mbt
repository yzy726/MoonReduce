///|
fn observed(code : Int, out : String, err : String) -> @model.Evaluation {
  {
    exit_code: code,
    timed_out: false,
    stdout: out,
    stderr: err,
    stdout_truncated: false,
    stderr_truncated: false,
    duration_ms: 1L,
  }
}

///|
test "advanced regex streams are conjunctive" {
  let s = {
    ..@advanced.defaults(),
    stdout_regex: ["^KEEP$"],
    stderr_regex: ["E[0-9]+"],
  }
  assert_eq(
    @advanced.matches(s, observed(1, "KEEP", "E123"), None, "", ""),
    Some(true),
  )
  assert_eq(
    @advanced.matches(s, observed(1, "KEEP", "other"), None, "", ""),
    Some(false),
  )
}

///|
test "advanced regex invalid settings are rejected" {
  assert_true(
    { ..@advanced.defaults(), stdout_regex: ["("] }.validate() is Err(_),
  )
}

///|
test "advanced crash classes normalize Windows and POSIX" {
  assert_eq(@advanced.crash_class(observed(-11, "", "")), "memory")
  assert_eq(@advanced.crash_class(observed(-1073741819, "", "")), "memory")
  assert_eq(@advanced.crash_class(observed(-6, "", "")), "abort")
  assert_eq(@advanced.crash_class(observed(1, "", "")), "none")
}

///|
test "advanced timeout is not a crash" {
  assert_eq(
    @advanced.crash_class({ ..observed(-1, "", ""), timed_out: true }),
    "timeout",
  )
}

///|
test "advanced diagnostic codes require token boundaries" {
  assert_eq(@advanced.diagnostic_codes("Error: [E1234] W0002 E1234 extraE77"), [
    "E1234", "W0002",
  ])
}

///|
test "advanced test labels preserve names" {
  assert_eq(
    @advanced.test_names("test \"first case\" failed\ntest 'second' failed"),
    ["first case", "second"],
  )
}

///|
test "advanced fingerprint does not accept unrelated failure" {
  let s = {
    ..@advanced.defaults(),
    diagnostic_codes: ["E1234"],
    test_names: ["case"],
  }
  assert_eq(
    @advanced.matches(
      s,
      observed(1, "", "E1234 test \"case\" failed"),
      None,
      "",
      "",
    ),
    Some(true),
  )
  assert_eq(
    @advanced.matches(
      s,
      observed(1, "", "E9999 test \"case\" failed"),
      None,
      "",
      "",
    ),
    Some(false),
  )
}

///|
test "advanced normalized output removes ANSI address and location" {
  assert_eq(
    @advanced.normalize(
      "\u001b[31m/root/a.mbt:12:3\u001b[0m 0xdeadbeef\r\n", "/root",
    ),
    "<workspace>/a.mbt:<n>:<n> <address>\n",
  )
}

///|
test "advanced differential output compares independent roots" {
  let s = { ..@advanced.defaults(), differential: "stdout", normalize: true }
  assert_eq(
    @advanced.matches(
      s,
      observed(0, "/a/file:1", ""),
      Some(observed(0, "/b/file:2", "")),
      "/a",
      "/b",
    ),
    Some(false),
  )
  assert_eq(
    @advanced.matches(
      s,
      observed(0, "left", ""),
      Some(observed(0, "right", "")),
      "",
      "",
    ),
    Some(true),
  )
}

///|
test "advanced differential missing or truncated evidence is inconclusive" {
  let s = { ..@advanced.defaults(), differential: "stdout" }
  assert_eq(@advanced.matches(s, observed(0, "a", ""), None, "", ""), None)
  assert_eq(
    @advanced.matches(
      s,
      { ..observed(0, "a", ""), stdout_truncated: true },
      Some(observed(0, "b", "")),
      "",
      "",
    ),
    None,
  )
}

///|
test "advanced differential exit status" {
  let s = { ..@advanced.defaults(), differential: "exit" }
  assert_eq(
    @advanced.matches(s, observed(1, "", ""), Some(observed(0, "", "")), "", ""),
    Some(true),
  )
}

///|
test "advanced wrapper protocol validates schema and tri-state" {
  let s = { ..@advanced.defaults(), wrapper: true }
  assert_eq(
    @advanced.matches(
      s,
      observed(0, "{\"schema_version\":1,\"interesting\":true}", ""),
      None,
      "",
      "",
    ),
    Some(true),
  )
  assert_eq(
    @advanced.matches(
      s,
      observed(0, "{\"schema_version\":1,\"interesting\":false}", ""),
      None,
      "",
      "",
    ),
    Some(false),
  )
  assert_eq(
    @advanced.matches(s, observed(0, "invalid", ""), None, "", ""),
    None,
  )
}

///|
test "advanced timeout boundary is inconclusive" {
  let s = { ..@advanced.defaults(), timeout_ms: 100, timeout_tolerance_ms: 10 }
  assert_eq(
    @advanced.matches(
      s,
      { ..observed(0, "", ""), duration_ms: 95L },
      None,
      "",
      "",
    ),
    None,
  )
  assert_eq(
    @advanced.matches(
      s,
      { ..observed(0, "", ""), duration_ms: 80L },
      None,
      "",
      "",
    ),
    Some(true),
  )
}

///|
test "advanced schema round trip and version rejection" {
  let s = { ..@advanced.defaults(), stdout_regex: ["KEEP"], normalize: true }
  assert_eq(
    @advanced.Spec::from_json(s.to_json()).unwrap().to_json(),
    s.to_json(),
  )
  assert_true({ ..s, schema_version: 2 }.validate() is Err(_))
  assert_true(@advanced.Spec::from_json(null) is Err(_))
}

///|
test "advanced numeric compiler diagnostic extraction" {
  assert_eq(@advanced.diagnostic_codes("Error: [4015] [12] [4015]"), ["4015"])
}

///|
test "advanced truncated anchored regex is inconclusive" {
  assert_eq(
    @advanced.matches(
      { ..@advanced.defaults(), stdout_regex: ["^x$"] },
      { ..observed(0, "x", ""), stdout_truncated: true },
      None,
      "",
      "",
    ),
    None,
  )
}

///|
test "advanced wrapper rejects version and incomplete output" {
  let s = { ..@advanced.defaults(), wrapper: true }
  assert_eq(
    @advanced.matches(
      s,
      observed(0, "{\"schema_version\":2,\"interesting\":true}", ""),
      None,
      "",
      "",
    ),
    None,
  )
  assert_eq(
    @advanced.matches(
      s,
      {
        ..observed(0, "{\"schema_version\":1,\"interesting\":true}", ""),
        stdout_truncated: true,
      },
      None,
      "",
      "",
    ),
    None,
  )
}

///|
test "advanced any crash excludes ordinary nonzero" {
  let s = { ..@advanced.defaults(), crash: "any" }
  assert_eq(
    @advanced.matches(s, observed(1, "", "ordinary error"), None, "", ""),
    Some(false),
  )
  assert_eq(
    @advanced.matches(s, observed(-4, "", ""), None, "", ""),
    Some(true),
  )
}

///|
test "advanced normalization preserves Unicode and small hex constants" {
  assert_eq(@advanced.normalize("😀 0xff\n", ""), "😀 0xff\n")
}

///|
test "advanced differential timeouts are inconclusive" {
  let s = { ..@advanced.defaults(), differential: "exit" }
  assert_eq(
    @advanced.matches(
      s,
      { ..observed(-1, "", ""), timed_out: true },
      Some(observed(0, "", "")),
      "",
      "",
    ),
    None,
  )
}

///|
test "advanced invalid tolerance cannot silently accept" {
  let s = { ..@advanced.defaults(), timeout_tolerance_ms: 10000 }
  assert_true(s.validate() is Err(_))
  assert_eq(@advanced.matches(s, observed(0, "", ""), None, "", ""), None)
}
