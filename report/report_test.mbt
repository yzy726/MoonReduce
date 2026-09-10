///|
test "valid/report schema and secret redaction" {
  let cfg = @config.parse(
    ["reduce"],
    Some({
      "target": "a.mbt",
      "output": "out",
      "command": ["tool"],
      "environment": { "API_TOKEN": "hidden-value", "LANG": "C" },
    }),
  ).unwrap()
  let s = @engine.Session::new("x")
  while s.next() is Some(_) {
    s.record(true)
  }
  let j = @report.render_json(cfg, s.result(), 10L, true)
  assert_false(j.stringify().contains("hidden-value"))
  assert_true(j.stringify().contains("schema_version"))
  assert_true(j.stringify().contains("API_TOKEN"))
  assert_true(
    @report.markdown(cfg, s.result(), 10L, true).contains(
      "Final verification: 3/3",
    ),
  )
}

///|
test "valid/unified diff handles missing newline" {
  let d = @report.unified_diff("a.mbt", "a\nb", "b")
  assert_true(d.contains("--- a/a.mbt\n+++ b/a.mbt"))
  assert_true(d.contains("\\ No newline at end of file"))
  assert_eq(@report.unified_diff("a.mbt", "same", "same"), "")
}

///|
test "valid/reproduction uses argv JSON" {
  let c = @config.parse(
    ["check", "--target", "a.mbt", "--", "tool", "space argument", "引号\""],
    None,
  ).unwrap()
  let text = @report.reproduce(c)
  assert_true(text.contains("space argument"))
  assert_true(text.contains("reduced"))
}
