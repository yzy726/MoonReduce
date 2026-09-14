///|
test "segments/semicolon statements" {
  let tree = @moon_syntax.scan("{ let a = 1; a + 2 }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    2,
  )
}

///|
test "segments/newline statements" {
  let tree = @moon_syntax.scan("{ let a = 1\na + 2 }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    2,
  )
}

///|
test "segments/CRLF statements" {
  let tree = @moon_syntax.scan("{ let a = 1\r\na }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    2,
  )
}

///|
test "segments/call arguments" {
  let tree = @moon_syntax.scan("(a, f(b,c), d)")
  assert_eq(@moon_syntax.segments(tree, tree.groups[0], "comma").length(), 3)
}

///|
test "segments/array elements" {
  let tree = @moon_syntax.scan("[1, [2,3], 4]")
  assert_eq(@moon_syntax.segments(tree, tree.groups[0], "comma").length(), 3)
}

///|
test "segments/struct fields" {
  let tree = @moon_syntax.scan("{a: Int, b: Array[Int]}")
  assert_eq(@moon_syntax.segments(tree, tree.groups[0], "comma").length(), 2)
}

///|
test "segments/trailing comma" {
  let tree = @moon_syntax.scan("(a,b,)")
  assert_eq(@moon_syntax.segments(tree, tree.groups[0], "comma").length(), 2)
}

///|
test "segments/empty group" {
  let tree = @moon_syntax.scan("{}")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    0,
  )
}

///|
test "segments/only whitespace" {
  let tree = @moon_syntax.scan("{ \n }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    0,
  )
}

///|
test "segments/only comment" {
  let tree = @moon_syntax.scan("{/* hi */}")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    0,
  )
}

///|
test "segments/semicolon in string" {
  let tree = @moon_syntax.scan("{ \"a;b\"; 2 }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    2,
  )
}

///|
test "segments/comma in string" {
  let tree = @moon_syntax.scan("(\"a,b\", 2)")
  assert_eq(@moon_syntax.segments(tree, tree.groups[0], "comma").length(), 2)
}

///|
test "segments/nested block" {
  let tree = @moon_syntax.scan("{ if true { 1; 2 }; 3 }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    2,
  )
}

///|
test "segments/operator continuation" {
  let tree = @moon_syntax.scan("{ let a = 1 +\n2\na }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    2,
  )
}

///|
test "segments/assignment continuation" {
  let tree = @moon_syntax.scan("{ let a =\n1\na }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    2,
  )
}

///|
test "segments/method continuation" {
  let tree = @moon_syntax.scan("{ a\n.foo() }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    1,
  )
}

///|
test "segments/else continuation" {
  let tree = @moon_syntax.scan("{ if true { 1 }\nelse { 2 } }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    1,
  )
}

///|
test "segments/comment after statement" {
  let tree = @moon_syntax.scan("{ a // explain\nb }")
  assert_eq(
    @moon_syntax.segments(tree, tree.groups[0], "statements").length(),
    2,
  )
}

///|
test "segments/Unicode byte boundaries" {
  let tree = @moon_syntax.scan("{ 中文; 🙂 }")
  let nodes = @moon_syntax.segments(tree, tree.groups[0], "statements")
  assert_eq(nodes[0].start, 2)
  assert_eq(nodes[0].end, 9)
  assert_eq(nodes[1].start, 10)
  assert_eq(nodes[1].end, 14)
}

///|
test "segments/invalid mode yields no speculative edits" {
  let tree = @moon_syntax.scan("{1;2}")
  assert_eq(@moon_syntax.segments(tree, tree.groups[0], "unknown"), [])
}
