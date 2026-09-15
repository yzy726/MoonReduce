///|
test "project config/project mode requires no single target" {
  let c = @config.parse(
    ["reduce", "--project", "--output", "out", "--", "moon", "check"],
    None,
  ).unwrap()
  assert_true(c.project)
  assert_eq(c.jobs, 1)
}

///|
test "project config/glob include and protection" {
  let c = @config.parse(
    [
      "reduce", "--project", "--include", "src/**/*.mbt", "--protect", "**/tests/**",
      "--ignore", "vendor/**", "--output", "out", "--", "tool",
    ],
    None,
  ).unwrap()
  assert_eq(c.includes, ["src/**/*.mbt"])
}

///|
test "project config/parallel workers" {
  assert_eq(
    @config.parse(
      ["reduce", "--project", "--jobs", "4", "--output", "out", "--", "tool"],
      None,
    ).unwrap().jobs,
    4,
  )
}

///|
test "project config/invalid glob is rejected" {
  assert_true(
    @config.parse(
      [
        "reduce", "--project", "--include", "[bad]", "--output", "out", "--", "tool",
      ],
      None,
    )
    is Err(_),
  )
}

///|
test "project config/worker count bounded" {
  assert_true(
    @config.parse(
      ["reduce", "--project", "--jobs", "65", "--output", "out", "--", "tool"],
      None,
    )
    is Err(_),
  )
}

///|
test "project config/single file compatibility" {
  let c = @config.parse(
    ["reduce", "--target", "a.mbt", "--output", "out", "--", "tool"],
    None,
  ).unwrap()
  assert_true(!c.project)
}

///|
test "project config/rejects project options in single file mode" {
  assert_true(
    @config.parse(
      [
        "reduce", "--target", "a.mbt", "--jobs", "4", "--output", "out", "--", "tool",
      ],
      None,
    )
    is Err(_),
  )
}
