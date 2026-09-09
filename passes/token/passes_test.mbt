///|
test "valid/five token passes" {
  assert_eq(@token.names().length(), 5)
  for
    pair in [
      ("balanced", "{a + b}"),
      ("token-range", "a + b + c"),
      ("token", "a + b"),
      ("string", "\"long text\""),
      ("number", "12345"),
    ] {
    let cs = @token.propose(pair.0, pair.1)
    assert_true(cs.length() > 0)
    for c in cs {
      assert_true(c.length() < pair.1.length())
    }
  }
}

///|
test "valid/balanced spans ignore quoted braces" {
  assert_eq(@token.propose("balanced", "{\"}\"}"), ["{}"])
  assert_eq(@token.propose("balanced", "{ /* } */ x }"), ["{}"])
  assert_eq(@token.propose("balanced", "{[)]}"), [])
}

///|
test "edge/literals and empty structures" {
  assert_eq(@token.propose("string", "\"abc\""), ["\"\""])
  assert_eq(@token.propose("string", "\"\""), [])
  assert_eq(@token.propose("number", "123"), ["0", "1"])
  assert_eq(@token.propose("number", "0"), [])
  assert_eq(@token.propose("balanced", "{}"), [])
  assert_eq(@token.propose("token", " /* abc */ "), [])
}
