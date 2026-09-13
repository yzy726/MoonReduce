///|
test "valid/lazy token proposals support large sources without materializing all copies" {
  let s = "word ".repeat(10000)
  let it = @token.propose_iter("token", s)
  assert_eq(it.next(), Some(s[4:].to_owned()))
  assert_true(it.next() is Some(_))
}
