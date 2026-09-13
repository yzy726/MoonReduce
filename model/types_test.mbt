///|
test "valid/default budgets reserve baseline and final" {
  let b = @model.default_budget()
  assert_true(b.max_tests >= 5)
  assert_true(b.max_time_ms > 0)
}

///|
test "valid/default predicate is nonzero with bounded output" {
  let p = @model.default_predicate(["moon", "check"])
  assert_eq(p.command, ["moon", "check"])
  assert_true(p.failure is NonZero)
  assert_true(p.output_limit > 0)
}

///|
test "valid/status exit codes" {
  assert_eq(@model.Completed.exit_code(), 0)
  assert_eq(@model.BudgetExhausted.exit_code(), 4)
  assert_eq(@model.Cancelled.exit_code(), 5)
  assert_eq(@model.FinalFailed.exit_code(), 7)
}
