///|
test "strategy config exposes score pass controls and retained workspaces" {
  let c = @config.parse(
    [
      "reduce", "--project", "--output", "out", "--score", "tokens", "--pass-include",
      "file", "--pass-exclude", "struct:format", "--keep-workdir", "--", "tool",
    ],
    None,
  ).unwrap()
  assert_eq(c.score, "tokens")
  assert_eq(c.pass_include, ["file"])
  assert_true(c.keep_workdir)
}

///|
test "strategy config rejects unknown score and pass" {
  for options in [["--score", "unknown"], ["--pass-include", "unknown"]] {
    assert_true(
      @config.parse(
        ["reduce", "--project", "--output", "out"] + options + ["--", "tool"],
        None,
      )
      is Err(_),
    )
  }
}
