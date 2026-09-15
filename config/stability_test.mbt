///|
test "stability config validates repeat and final quorum" {
  let c = @config.parse(
    [
      "reduce", "--project", "--output", "out", "--repeat", "5", "--quorum", "4",
      "--final-repeat", "5", "--final-quorum", "4", "--consecutive", "--", "tool",
    ],
    None,
  ).unwrap()
  assert_eq(c.repeat, 5)
  assert_eq(c.quorum, 4)
  assert_eq(c.final_repeat, 5)
  assert_eq(c.final_quorum, 4)
  assert_true(c.consecutive)
}

///|
test "stability config defaults quorum to repeat" {
  let c = @config.parse(
    ["reduce", "--project", "--output", "out", "--repeat", "3", "--", "tool"],
    None,
  ).unwrap()
  assert_eq(c.quorum, 3)
  assert_eq(c.final_repeat, 3)
  assert_eq(c.final_quorum, 3)
}

///|
test "stability config rejects impossible policies and insufficient budget" {
  for
    options in [
      ["--repeat", "3", "--quorum", "4"],
      ["--repeat", "101"],
      ["--final-repeat", "3", "--final-quorum", "4"],
      ["--repeat", "4", "--max-tests", "5"],
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
