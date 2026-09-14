///|
test "body/delete direct statement" {
  assert_true(
    @structured.propose("statement", "fn f() { let x = 1; x }").contains(
      "fn f() {  x }",
    ),
  )
}

///|
test "body/statement pass excludes struct fields" {
  assert_eq(@structured.propose("statement", "struct S { x : Int }"), [])
}

///|
test "body/replace if with branch body" {
  assert_true(
    @structured.propose("if-branch", "fn f() { if true { 100 } else { 200 } }").contains(
      "fn f() {  100  }",
    ),
  )
}

///|
test "body/delete match arm" {
  assert_true(
    @structured.propose("match-arm", "fn f(x) { match x { A => 1, B => 2 } }").contains(
      "fn f(x) { match x {  B => 2 } }",
    ),
  )
}

///|
test "body/delete loop body statement" {
  assert_true(
    @structured.propose("loop-body", "fn f() { while true { foo(); bar() } }").contains(
      "fn f() { while true {  bar() } }",
    ),
  )
}

///|
test "body/simplify local binding value" {
  assert_true(
    @structured.propose("binding", "fn f() { let x = expensive(); x }").contains(
      "fn f() { let x = 0; x }",
    ),
  )
}

///|
test "body/simplify expression literal" {
  assert_true(
    @structured.propose("expression", "fn f() { 12345 }").contains(
      "fn f() { 0 }",
    ),
  )
}

///|
test "body/if in string does not create branch" {
  assert_eq(@structured.propose("if-branch", "fn f() { \"if true {}\" }"), [])
}

///|
test "body/match keyword inside comment ignored" {
  assert_eq(@structured.propose("match-arm", "fn f() { /* match x */ {} }"), [])
}

///|
test "body/loop pass ignores ordinary nested block" {
  assert_eq(@structured.propose("loop-body", "fn f() { { foo(); bar() } }"), [])
}

///|
test "body/binding pass does not touch global let" {
  assert_eq(@structured.propose("binding", "let value = 12345"), [])
}

///|
test "body/malformed branches fall back" {
  assert_eq(@structured.propose("if-branch", "fn f() { if true { 1 }"), [])
}

///|
test "body/expression candidates strictly smaller" {
  let s = "fn f() { (100 + 200) }"
  for c in @structured.propose("expression", s) {
    assert_true(c.length() < s.length())
  }
}

///|
test "body/Unicode statements remain valid" {
  assert_true(
    @structured.propose("statement", "fn f() { let 中文 = 1; 中文 }").contains(
      "fn f() {  中文 }",
    ),
  )
}

///|
test "body/match nested tuple commas not split" {
  let cs = @structured.propose(
    "match-arm", "fn f(x) { match x { (A,B) => 1, C => 2 } }",
  )
  assert_true(cs.contains("fn f(x) { match x {  C => 2 } }"))
}
