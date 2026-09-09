///|
test "valid/relative path normalization" {
  assert_eq(@source.validate_path("src\\a.mbt"), Ok("src/a.mbt"))
  assert_eq(@source.validate_path("./src/./a.mbt"), Ok("src/a.mbt"))
}

///|
test "invalid/path traversal and absolute paths" {
  for p in ["../a", "a/../b", "/a", "C:\\a", "\\\\host\\a", "a\u0000b", "", "."] {
    assert_true(@source.validate_path(p) is Err(_))
  }
}

///|
test "invalid/windows alternate streams and reserved names" {
  for p in ["a:b", "CON", "aux.txt", "a/NUL.mbt", "a. ", "a//b"] {
    assert_true(@source.validate_path(p) is Err(_))
  }
}

///|
test "valid/UTF8 decoding rejects malformed sequences" {
  assert_eq(@source.decode(b"hello"), Ok("hello"))
  assert_true(@source.decode(b"\xff") is Err(_))
}

///|
test "valid/byte edits respect UTF8 boundaries" {
  let text = @source.encode("你好abc")
  assert_eq(@source.apply_edit(text, 6, 9, b"z"), Ok(@source.encode("你好z")))
  assert_true(@source.apply_edit(text, 1, 4, b"") is Err(_))
  assert_true(@source.apply_edit(text, 5, 2, b"") is Err(_))
  assert_true(@source.apply_edit(text, 0, 99, b"") is Err(_))
}

///|
test "valid/digest stable and content sensitive" {
  assert_eq(@source.digest(b"abc"), @source.digest(b"abc"))
  assert_true(@source.digest(b"abc") != @source.digest(b"abd"))
}
