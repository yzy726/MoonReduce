///|
test "structured/remove function" {
  assert_true(
    @structured.propose("function", "fn a() {}\nfn b() {}").contains(
      "fn b() {}",
    ),
  )
}

///|
test "structured/remove type declaration" {
  assert_true(
    @structured.propose("type-declaration", "struct S {}\nfn a() {}").contains(
      "fn a() {}",
    ),
  )
}

///|
test "structured/remove test declaration" {
  assert_true(
    @structured.propose("test", "test { () }\nfn a() {}").contains("fn a() {}"),
  )
}

///|
test "structured/remove import block" {
  assert_true(
    @structured.propose("import", "import { \"a/b\" }\nfn a() {}").contains(
      "\nfn a() {}",
    ),
  )
}

///|
test "structured/delete parameter" {
  assert_true(
    @structured.propose("parameter", "fn a(x : Int, y : Int) {}").contains(
      "fn a( y : Int) {}",
    ),
  )
}

///|
test "structured/delete field" {
  assert_true(
    @structured.propose("field", "struct S { x : Int, y : Int }").contains(
      "struct S {  y : Int }",
    ),
  )
}

///|
test "structured/malformed source yields no declaration edits" {
  assert_eq(@structured.propose("function", "fn a() {"), [])
}

///|
test "structured/unknown pass yields no edits" {
  assert_eq(@structured.propose("unknown", "fn a() {}"), [])
}

///|
test "structured/parameter pass ignores call arguments" {
  assert_eq(@structured.propose("parameter", "fn a() { f(100, 200) }"), [])
}

///|
test "structured/field pass ignores function blocks" {
  assert_eq(@structured.propose("field", "fn a() { let x = 1; x }"), [])
}

///|
test "structured/Unicode deletion retains valid UTF8" {
  assert_true(
    @structured.propose("function", "fn 中文() {}\nfn b() {}").contains(
      "fn b() {}",
    ),
  )
}

///|
test "structured/declaration candidates are unique and smaller" {
  let s = "fn a() {}\nfn a() {}"
  let candidates = @structured.propose("function", s)
  for c in candidates {
    assert_true(c.length() < s.length())
  }
  assert_eq(candidates.length(), 2)
}

///|
test "structured/visibility group is not a parameter" {
  let candidates = @structured.propose("parameter", "pub(all) fn a() {}")
  assert_eq(candidates, [])
}

///|
test "structured/return tuple is not a parameter list" {
  assert_eq(
    @structured.propose("parameter", "fn a() -> (Int, Int) { (1,2) }"),
    [],
  )
}

///|
test "structured/import keyword inside function is ignored" {
  assert_eq(@structured.propose("import", "fn a() { import }\nfn b() {}"), [])
}
