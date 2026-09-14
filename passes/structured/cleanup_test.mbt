///|
test "cleanup/type annotation" {
  assert_true(
    @structured.propose("type-annotation", "fn f() { let x : Int = 123; x }").contains(
      "fn f() { let x  = 123; x }",
    ),
  )
}

///|
test "cleanup/generic argument" {
  assert_true(
    @structured.propose("type-annotation", "fn f(x : Array[Int]) {}").contains(
      "fn f(x : Array) {}",
    ),
  )
}

///|
test "cleanup/namespace separator preserved" {
  assert_eq(
    @structured.propose("type-annotation", "fn f() { Type::method() }"),
    [],
  )
}

///|
test "cleanup/doc comments" {
  assert_true(
    @structured.propose("metadata", "/// docs\nfn f() {}").contains(
      "\nfn f() {}",
    ),
  )
}

///|
test "cleanup/attribute line" {
  assert_true(
    @structured.propose("metadata", "#deprecated\nfn f() {}").contains(
      "\nfn f() {}",
    ),
  )
}

///|
test "cleanup/test label" {
  assert_true(
    @structured.propose("metadata", "test \"long label\" { () }").contains(
      "test  { () }",
    ),
  )
}

///|
test "cleanup/identifier shortening" {
  assert_true(
    @structured.propose("identifier-literal", "fn long_name() {}").contains(
      "fn x() {}",
    ),
  )
}

///|
test "cleanup/numeric literal shortening" {
  assert_true(
    @structured.propose("identifier-literal", "let value = 12345").contains(
      "let value = 0",
    ),
  )
}

///|
test "cleanup/string literal shortening" {
  assert_true(
    @structured.propose("identifier-literal", "let value = \"long\"").contains(
      "let value = \"\"",
    ),
  )
}

///|
test "cleanup/keywords not shortened" {
  assert_eq(@structured.propose("identifier-literal", "fn f() { true }"), [])
}

///|
test "cleanup/format disabled by default" {
  assert_eq(@structured.propose("format", "fn  f() {}"), [])
}

///|
test "cleanup/format explicit opt in" {
  assert_true(
    @structured.propose("format", "fn  f() {}", allow_format=true).contains(
      "fn f() {}",
    ),
  )
}

///|
test "cleanup/format leaves string contents intact" {
  let s = "fn f() { \"a  b\" }"
  assert_eq(@structured.propose("format", s, allow_format=true), [])
}

///|
test "cleanup/pass registry has sixteen distinct entries" {
  let names = @structured.names()
  assert_eq(names.length(), 16)
  for i in 0..<names.length() {
    for j in (i + 1)..<names.length() {
      assert_true(names[i] != names[j])
    }
  }
}

///|
test "cleanup/Unicode identifier shorter bytes" {
  assert_true(
    @structured.propose("identifier-literal", "fn 中文() {}").contains(
      "fn x() {}",
    ),
  )
}
