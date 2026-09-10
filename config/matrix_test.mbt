///|
test "invalid/root-array" {
  let j : Json = []
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/root-string" {
  let j : Json = "x"
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/unknown-key" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "bogus": true,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/target-type" {
  let j : Json = { "target": 23, "output": "out", "command": ["tool"] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/command-type" {
  let j : Json = { "target": "a.mbt", "output": "out", "command": "moon" }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/command-element" {
  let j : Json = { "target": "a.mbt", "output": "out", "command": [1] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/empty-command" {
  let j : Json = { "target": "a.mbt", "output": "out", "command": [] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/empty-executable" {
  let j : Json = { "target": "a.mbt", "output": "out", "command": [""] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/nul-argv" {
  let j : Json = { "target": "a.mbt", "output": "out", "command": ["a\u0000b"] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/outside-target" {
  let j : Json = { "target": "../a.mbt", "output": "out", "command": ["tool"] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/absolute-target" {
  let j : Json = { "target": "/a.mbt", "output": "out", "command": ["tool"] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/non-moonbit-target" {
  let j : Json = { "target": "a.txt", "output": "out", "command": ["tool"] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/output-type" {
  let j : Json = { "target": "a.mbt", "output": 0, "command": ["tool"] }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/cwd-traversal" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "cwd": "../x",
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/max-tests-zero" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "max_tests": 0,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/max-tests-four" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "max_tests": 4,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/max-tests-fraction" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "max_tests": 5.5,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/max-tests-overflow" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "max_tests": 2147483648,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/max-tests-bool" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "max_tests": true,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/negative-duration" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "timeout": "-1s",
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/zero-duration" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "timeout": "0ms",
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/bad-duration-unit" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "timeout": "1m",
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/duration-overflow" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "timeout": "2147483647s",
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/time-zero" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "max_time": 0,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/output-limit-zero" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "output_limit": 0,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/rule-type" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "stdout_contains": "error",
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/rule-element" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "stderr_contains": [1],
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/quiet-type" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "quiet": "yes",
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/case-type" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "ignore_case": 1,
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/environment-type" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "environment": [],
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/environment-value" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "environment": { "X": 1 },
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/environment-empty-key" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "environment": { "": "v" },
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/environment-equals" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "environment": { "X=Y": "v" },
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/ignore-traversal" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "ignore": ["../x"],
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "invalid/protect-target" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "protect": ["a.mbt"],
  }
  assert_true(@config.parse(["reduce"], Some(j)) is Err(_))
}

///|
test "valid/milliseconds" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "timeout": "25ms",
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.predicate.timeout_ms, 25)
}

///|
test "valid/seconds" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "timeout": "2s",
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.predicate.timeout_ms, 2000)
}

///|
test "valid/bare-ms" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "timeout": "250",
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.predicate.timeout_ms, 250)
}

///|
test "valid/number-duration" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "timeout": 123,
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.predicate.timeout_ms, 123)
}

///|
test "valid/min-budget" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "max_tests": 5,
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.budget.max_tests, 5)
}

///|
test "valid/negative-exit" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "expect": "-9",
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.predicate.failure, @model.ExitCode(-9))
}

///|
test "valid/zero-exit" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "expect": "0",
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.predicate.failure, @model.ExitCode(0))
}

///|
test "valid/timeout-kind" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "expect": "timeout",
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.predicate.failure, @model.Timeout)
}

///|
test "valid/cwd-normal" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "cwd": "src",
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.predicate.cwd, "src")
}

///|
test "valid/quiet" {
  let j : Json = {
    "target": "a.mbt",
    "output": "out",
    "command": ["tool"],
    "quiet": true,
  }
  let c = @config.parse(["reduce"], Some(j)).unwrap()
  assert_eq(c.quiet, true)
}
