///|
test "regr/portable path rejects control characters and Windows metacharacters" {
  for
    path in [
      "a\nb.mbt", "a\rb.mbt", "a\tb.mbt", "a*b.mbt", "a?b.mbt", "a\"b.mbt", "a<b.mbt",
      "a>b.mbt", "a|b.mbt",
    ] {
    assert_true(@source.validate_path(path) is Err(_))
  }
}

///|
test "invalid/UTF8 truncated and overlong inputs" {
  for
    bytes in [
      b"\xc0\xaf", b"\xe0\x80\xaf", b"\xed\xa0\x80", b"\xf4\x90\x80\x80", b"\xf0\x9f",
      b"\x80",
    ] {
    assert_true(@source.decode(bytes) is Err(_))
  }
}

///|
test "property/valid UTF8 round trip including BOM and supplementary characters" {
  for
    s in ["", "ascii", "中文", "🙂", "\ufefftext", "a\u0000b", "é", "\r\n"] {
    assert_eq(@source.decode(@source.encode(s)), Ok(s))
  }
}
