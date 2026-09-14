///|
test "declaration/function" {
  let source = "fn f() { 1 }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "fn")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/public function" {
  let source = "pub fn f() { 1 }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "fn")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/async function" {
  let source = "pub async fn f() { 1 }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "fn")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/struct" {
  let source = "struct S { x : Int }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "struct")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/enum" {
  let source = "enum E { A; B }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "enum")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/trait" {
  let source = "trait T { f(Self) -> Int }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "trait")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/implementation" {
  let source = "impl T for S with f(self) { 1 }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "impl")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/type alias" {
  let source = "typealias A = Int"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "typealias")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/type declaration" {
  let source = "type T Int"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "type")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/constant" {
  let source = "const N = 1"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "const")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/global binding" {
  let source = "let x = 1"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "let")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/test block" {
  let source = "test \"sample\" { assert_true(true) }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "test")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/async test" {
  let source = "async test \"sample\" { () }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "test")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/external function" {
  let source = "extern \"C\" fn f() -> Int = \"f\""
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "fn")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/public all modifier" {
  let source = "pub(all) struct S { x : Int }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "struct")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/private modifier" {
  let source = "priv struct S { x : Int }"
  let nodes = @moon_syntax.declarations(@moon_syntax.scan(source))
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].kind, "struct")
  assert_eq(nodes[0].start, 0)
  assert_eq(nodes[0].end, source.length())
}

///|
test "declaration/nested functions are not top level" {
  let nodes = @moon_syntax.declarations(
    @moon_syntax.scan("fn a() { fn b() { 1 }; b() }"),
  )
  assert_eq(nodes.length(), 1)
}

///|
test "declaration/comments do not create declarations" {
  let nodes = @moon_syntax.declarations(
    @moon_syntax.scan("// fn ignored() {}\nfn a() {}"),
  )
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].start, 19)
}

///|
test "declaration/siblings preserve byte boundaries" {
  let tree = @moon_syntax.scan("fn 中文() {}\nfn b() {}")
  let nodes = @moon_syntax.declarations(tree)
  assert_eq(nodes.length(), 2)
  assert_eq(nodes[0].end, nodes[1].start)
  assert_eq(nodes[1].start, 15)
}

///|
test "declaration/malformed input uses fallback" {
  assert_eq(@moon_syntax.declarations(@moon_syntax.scan("fn a() {")), [])
}
