///|
test "advanced config exposes versioned predicates" {
  let c = @config.parse(
    [
      "reduce", "--project", "--output", "out", "--stdout-regex", "KEEP.*", "--diagnostic-code",
      "E1234", "--test-name", "case", "--normalize", "--crash", "memory", "--", "tool",
    ],
    None,
  ).unwrap()
  assert_eq(c.advanced.stdout_regex, ["KEEP.*"])
  assert_true(c.advanced.normalize)
  assert_eq(c.advanced.diagnostic_codes, ["E1234"])
}

///|
test "advanced config differential command uses explicit JSON argv" {
  let c = @config.parse(
    ["reduce", "--project", "--output", "out", "--", "left"],
    Some({ "reference": ["right", "arg"], "differential": "stdout" }),
  ).unwrap()
  assert_eq(c.reference, ["right", "arg"])
  assert_eq(c.advanced.differential, "stdout")
}

///|
test "advanced config rejects invalid regex and missing reference" {
  for
    options in [
      ["--stdout-regex", "("],
      ["--differential", "stdout"],
      ["--crash", "unknown"],
    ] {
    assert_true(
      @config.parse(
        ["reduce", "--project", "--output", "out"] + options + ["--", "tool"],
        None,
      )
      is Err(_),
    )
  }
}

///|
test "advanced config rejects insufficient differential budget" {
  assert_true(
    @config.parse(
      [
        "reduce", "--project", "--output", "out", "--max-tests", "9", "--", "left",
      ],
      Some({ "reference": ["right"], "differential": "exit" }),
    )
    is Err(_),
  )
}
