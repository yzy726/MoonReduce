///|
test "valid/lexer ignores brackets in strings and comments" {
  let ts = @token.scan("fn x() { \"}\\\"{\" /* [ nested /* x */ ] */ // }\n}")
  assert_eq(ts.filter(t => t.kind == "punct").map(t => t.text), [
    "(", ")", "{", "}",
  ])
}

///|
test "valid/lexer Unicode spans reconstruct source" {
  let s = "let 名字 = \"🙂\" + 123.45e-6 //说明\n"
  let ts = @token.scan(s)
  assert_eq(ts.map(t => t.text).join(""), s)
  for t in ts {
    assert_eq(s[t.start:t.end].to_owned(), t.text)
  }
}

///|
test "edge/unterminated quoted or comment input" {
  for s in ["\"abc", "/* aa", "'a", "//end", "#|raw"] {
    assert_eq(@token.scan(s).map(t => t.text).join(""), s)
  }
}

///|
test "valid/numeric and character literals" {
  let ts = @token.scan("42 0xff 1.5e-2 'a' '\\n'")
  assert_eq(ts.filter(t => t.kind == "number").length(), 3)
  assert_eq(ts.filter(t => t.kind == "char").length(), 2)
}
