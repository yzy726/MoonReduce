///|
fn score(text : String) -> @score.Score {
  @score.measure(
    @manifest.Snapshot::new([("a.mbt", @source.encode(text))]).unwrap(),
  )
}

///|
test "score measures source and support contents" {
  let s = @score.measure(
    @manifest.Snapshot::new([
      ("a.mbt", b"fn f() { 1 }\n\n"),
      ("asset.bin", b"\xff"),
    ]).unwrap(),
  )
  assert_eq(s.bytes, 15)
  assert_eq(s.files, 2)
  assert_eq(s.lines, 1)
  assert_true(s.tokens > 0 && s.nodes > 0)
}

///|
test "score defaults to bytes before tokens" {
  assert_eq(@score.compare("bytes", score("a+b"), score("longname")), Ok(-1))
  assert_eq(@score.compare("tokens", score("a+b"), score("longname")), Ok(1))
}

///|
test "score line priority and byte tie breaker" {
  assert_eq(
    @score.compare("lines", score("abc\nxyz"), score("longername")),
    Ok(1),
  )
  assert_eq(@score.compare("tokens", score("a"), score("abc")), Ok(-1))
}

///|
test "score identical snapshots never improve" {
  assert_eq(@score.compare("bytes", score("😀"), score("😀")), Ok(0))
}

///|
test "score rejects unknown strategy" {
  assert_true(@score.compare("unknown", score("x"), score("y")) is Err(_))
}

///|
test "score ignores whitespace-only lines" {
  assert_eq(score("\n  \n\t\nx\n").lines, 1)
}
