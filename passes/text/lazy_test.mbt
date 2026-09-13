///|
test "valid/lazy line proposals preserve deterministic order" {
  let s = "line\n".repeat(10000)
  let it = @text.propose_iter("line", s)
  assert_eq(it.next(), Some(s[5:].to_owned()))
  assert_eq(it.next(), Some(s[5:].to_owned()))
}
