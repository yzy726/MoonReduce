///|
test "structure/empty input" {
  let tree = @moon_syntax.scan("")
  assert_eq(tree.groups.length(), 0)
  assert_eq(tree.diagnostics.length(), 0)
}

///|
test "structure/nested group byte spans" {
  let tree = @moon_syntax.scan("中🙂({[]})")
  assert_eq(tree.groups.length(), 3)
  assert_eq(tree.groups[0].start, 7)
  assert_eq(tree.groups[0].end, 13)
  assert_eq(tree.groups[0].depth, 0)
  assert_eq(tree.groups[2].depth, 2)
  assert_eq(tree.diagnostics.length(), 0)
}

///|
test "structure/mismatched closing rejects unsafe groups" {
  let tree = @moon_syntax.scan("([)]")
  assert_eq(tree.groups.length(), 0)
  assert_true(tree.diagnostics.length() > 0)
}

///|
test "structure/unclosed group reports fallback" {
  assert_true(@moon_syntax.scan("fn a() { [").diagnostics.length() > 0)
}

///|
test "structure/unmatched closing reports fallback" {
  assert_true(@moon_syntax.scan("}").diagnostics.length() > 0)
}

///|
test "structure/complete prefix survives incomplete tail" {
  let tree = @moon_syntax.scan("() {")
  assert_eq(tree.groups.length(), 1)
  assert_true(tree.diagnostics.length() > 0)
}

///|
test "structure/string braces opaque" {
  let tree = @moon_syntax.scan("{ \"([}])\" }")
  assert_eq(tree.groups.length(), 1)
  assert_eq(tree.diagnostics.length(), 0)
}

///|
test "structure/character braces opaque" {
  assert_eq(@moon_syntax.scan("['}']").groups.length(), 1)
}

///|
test "structure/nested block comment opaque" {
  assert_eq(@moon_syntax.scan("{/* { /* ] */ ) */}").groups.length(), 1)
}

///|
test "structure/line comment opaque" {
  assert_eq(@moon_syntax.scan("{ // }\n}").groups.length(), 1)
}

///|
test "structure/multiline raw string opaque" {
  assert_eq(@moon_syntax.scan("{\n#| } ) ]\n}").groups.length(), 1)
}

///|
test "structure/unterminated string requests fallback" {
  assert_true(@moon_syntax.scan("\"abc").diagnostics.length() > 0)
}

///|
test "structure/unterminated comment requests fallback" {
  assert_true(@moon_syntax.scan("/* abc").diagnostics.length() > 0)
}

///|
test "structure/escaped final quote is not terminated" {
  assert_true(@moon_syntax.scan("\"abc\\\"").diagnostics.length() > 0)
}

///|
test "structure/groups sorted by start including siblings" {
  let tree = @moon_syntax.scan("([]) {}")
  assert_eq(tree.groups.map(g => g.start), [0, 1, 5])
}

///|
test "structure/inner spans exclude delimiters" {
  let tree = @moon_syntax.scan("(中)")
  assert_eq(tree.groups[0].inner_start, 1)
  assert_eq(tree.groups[0].inner_end, 4)
}

///|
test "structure/CRLF byte positions" {
  assert_eq(@moon_syntax.scan("\r\n{}").groups[0].start, 2)
}

///|
test "structure/escaped slash literal does not start comment" {
  assert_eq(@moon_syntax.scan("[\"//\"]").diagnostics.length(), 0)
}

///|
test "structure/source limit prevents unbounded scan" {
  let tree = @moon_syntax.scan("a".repeat(65537))
  assert_eq(tree.groups.length(), 0)
  assert_true(tree.diagnostics.length() > 0)
}

///|
test "structure/empty matched group retained" {
  let group = @moon_syntax.scan("{}").groups[0]
  assert_eq(group.inner_start, group.inner_end)
}
