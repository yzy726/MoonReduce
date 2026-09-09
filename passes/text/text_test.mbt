///|
test "valid/seven text passes registered" {
  assert_eq(@text.names().length(), 7)
}

///|
test "valid/text deletion pass outcomes" {
  for
    pair in [
      ("line-block", "a\nb\nc\nd\n"),
      ("line", "a\nb\n"),
      ("blank-line", "a\n\n"),
      ("line-comment", "x // hi\n"),
      ("block-comment", "x /* hi */"),
      ("doc-comment", "/// doc\nx"),
      ("trim-edge", "a\nb\nc\n"),
    ] {
    let candidates = @text.propose(pair.0, pair.1)
    assert_true(candidates.length() > 0)
    for c in candidates {
      assert_true(c.length() < pair.1.length())
    }
  }
}

///|
test "edge/comment text inside string remains opaque" {
  for name in ["line-comment", "block-comment", "doc-comment"] {
    assert_eq(@text.propose(name, "\"// /* /// */\""), [])
  }
}

///|
test "edge/line deletion preserves CRLF and final newline" {
  assert_eq(@text.propose("line", "a\r\nb\r\n"), ["b\r\n", "a\r\n"])
  assert_eq(@text.propose("line", "a\nb"), ["b", "a\n"])
  assert_eq(@text.propose("line", ""), [])
}
