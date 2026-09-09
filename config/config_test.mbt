///|
test "valid/CLI config and direct argv" {
  let c = @config.parse(
    [
      "reduce", "--workspace", ".", "--target", "a.mbt", "--output", "out", "--stderr-contains",
      "bad", "--", "moon", "check",
    ],
    None,
  ).unwrap()
  assert_eq(c.predicate.command, ["moon", "check"])
  assert_eq(c.predicate.stderr_rules[0].text, "bad")
}

///|
test "invalid/config errors" {
  for
    args in [
      ["reduce"],
      ["wat"],
      ["reduce", "--target"],
      ["reduce", "--wat", "x"],
      ["reduce", "--target", "../x"],
      ["reduce", "--target", "x.mbt", "--target", "y.mbt"],
      ["check", "--target", "x.mbt", "--timeout", "0", "--", "x"],
    ] {
    assert_true(@config.parse(args, None) is Err(_))
  }
}

///|
test "valid/JSON config overridden by CLI" {
  let j : Json = {
    "target": "a.mbt",
    "workspace": ".",
    "output": "out",
    "command": ["tool"],
    "max_tests": 100,
    "expect": "nonzero",
  }
  let c = @config.parse(["reduce", "--max-tests", "20"], Some(j)).unwrap()
  assert_eq(c.budget.max_tests, 20)
  assert_eq(c.target, "a.mbt")
}

///|
test "valid/informational commands need no target" {
  for a in [["--help"], ["passes"], ["explain", "report.json"]] {
    assert_true(@config.parse(a, None) is Ok(_))
  }
}
