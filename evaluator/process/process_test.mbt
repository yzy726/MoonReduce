///|
async test "e2e/real direct argv captures bounded output" {
  let p = { ..@model.default_predicate(["moon", "version"]), output_limit: 8 }
  let e = @process.run(p, ".")
  assert_eq(e.exit_code, 0)
  assert_true(e.stdout_truncated)
  assert_true(e.stdout.length() <= 8)
}

///|
async test "e2e/missing executable is an error not an interesting failure" {
  let failed = try {
    ignore(
      @process.run(
        @model.default_predicate(["moonreduce-missing-program-629875"]),
        ".",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
async test "invalid/empty command does not panic" {
  let failed = try {
    ignore(@process.run(@model.default_predicate([]), "."))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
