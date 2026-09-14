///|
test "glob/literal root anchoring" {
  assert_eq(@glob.matches("a.mbt", "a.mbt"), Ok(true))
  assert_eq(@glob.matches("a.mbt", "src/a.mbt"), Ok(false))
}

///|
test "glob/star cannot cross directory" {
  assert_eq(@glob.matches("*.mbt", "abc.mbt"), Ok(true))
  assert_eq(@glob.matches("*.mbt", "src/abc.mbt"), Ok(false))
}

///|
test "glob/double star matches zero directories" {
  assert_eq(@glob.matches("**/*.mbt", "a.mbt"), Ok(true))
}

///|
test "glob/double star matches nested directories" {
  assert_eq(@glob.matches("**/*.mbt", "a/b/c.mbt"), Ok(true))
}

///|
test "glob/middle double star respects suffix" {
  assert_eq(@glob.matches("src/**/a.mbt", "src/a.mbt"), Ok(true))
  assert_eq(@glob.matches("src/**/a.mbt", "src/x/y/a.mbt"), Ok(true))
  assert_eq(@glob.matches("src/**/a.mbt", "src/x/b.mbt"), Ok(false))
}

///|
test "glob/question matches one Unicode scalar" {
  assert_eq(@glob.matches("?.mbt", "中.mbt"), Ok(true))
  assert_eq(@glob.matches("?.mbt", "🙂.mbt"), Ok(true))
  assert_eq(@glob.matches("?.mbt", "ab.mbt"), Ok(false))
}

///|
test "glob/star backtracks within a component" {
  assert_eq(@glob.matches("a*b*c.mbt", "axbybc.mbt"), Ok(true))
  assert_eq(@glob.matches("a*b*c.mbt", "axbybd.mbt"), Ok(false))
}

///|
test "glob/star permits empty match" {
  assert_eq(@glob.matches("a*.mbt", "a.mbt"), Ok(true))
}

///|
test "glob/windows separators normalized" {
  assert_eq(@glob.matches("src\\*.mbt", "src\\a.mbt"), Ok(true))
}

///|
test "glob/case sensitive across platforms" {
  assert_eq(@glob.matches("*.mbt", "a.MBT"), Ok(false))
}

///|
test "glob/dotfiles included explicitly by star" {
  assert_eq(@glob.matches("**/*.mbt", ".hidden/a.mbt"), Ok(true))
}

///|
test "glob/repeated double stars" {
  assert_eq(@glob.matches("**/**/a.mbt", "x/a.mbt"), Ok(true))
}

///|
test "glob/reject traversal patterns" {
  for pattern in ["../*.mbt", "a/../*.mbt", "/a", "C:/a", "a//b", ""] {
    assert_true(@glob.matches(pattern, "a.mbt") is Err(_))
  }
}

///|
test "glob/reject unsupported pattern syntax" {
  for pattern in ["[ab].mbt", "{a,b}.mbt", "a**b", "***", "!a", "a\n*"] {
    assert_true(@glob.matches(pattern, "a.mbt") is Err(_))
  }
}

///|
test "glob/reject unsafe candidate paths" {
  for path in ["../a.mbt", "a//b", "CON.mbt", "a:b", ""] {
    assert_true(@glob.matches("**", path) is Err(_))
  }
}

///|
test "glob/current directory prefix" {
  assert_eq(@glob.matches("./src/*.mbt", "./src/a.mbt"), Ok(true))
}

///|
test "glob/reject excessive pattern length" {
  assert_true(@glob.matches("a".repeat(1025), "a.mbt") is Err(_))
}
