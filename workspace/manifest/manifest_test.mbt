///|
fn snapshot(files : Array[(String, Bytes)]) -> @manifest.Snapshot raise {
  match @manifest.Snapshot::new(files) {
    Ok(s) => s
    Err(e) => fail(e)
  }
}

///|
test "snapshot/canonical order independent of enumeration" {
  let a = snapshot([("b.mbt", b"b"), ("a.mbt", b"a")])
  let b = snapshot([("a.mbt", b"a"), ("b.mbt", b"b")])
  assert_eq(a.files(), b.files())
  assert_eq(a.key(), b.key())
  assert_eq(a.files()[0].0, "a.mbt")
}

///|
test "snapshot/normalizes paths" {
  assert_eq(snapshot([(".\\src\\a.mbt", b"a")]).files()[0].0, "src/a.mbt")
}

///|
test "snapshot/rejects normalized duplicate" {
  assert_true(
    @manifest.Snapshot::new([("a.mbt", b"a"), ("./a.mbt", b"b")]) is Err(_),
  )
}

///|
test "snapshot/rejects portable case collision" {
  assert_true(
    @manifest.Snapshot::new([("A.mbt", b"a"), ("a.mbt", b"b")]) is Err(_),
  )
}

///|
test "snapshot/rejects file as parent directory" {
  assert_true(
    @manifest.Snapshot::new([("src", b"a"), ("src/a.mbt", b"b")]) is Err(_),
  )
  assert_true(
    @manifest.Snapshot::new([("SRC", b"a"), ("src/a.mbt", b"b")]) is Err(_),
  )
}

///|
test "snapshot/rejects traversal" {
  assert_true(@manifest.Snapshot::new([("../a.mbt", b"a")]) is Err(_))
}

///|
test "snapshot/rejects malformed source UTF8" {
  assert_true(@manifest.Snapshot::new([("a.mbt", b"\xff")]) is Err(_))
}

///|
test "snapshot/preserves binary support files" {
  assert_eq(snapshot([("asset.bin", b"\xff")]).files()[0].1, b"\xff")
}

///|
test "snapshot/input array does not alias" {
  let files = [("a.mbt", b"a")]
  let s = snapshot(files)
  files[0] = ("b.mbt", b"b")
  assert_eq(s.files(), [("a.mbt", b"a")])
}

///|
test "snapshot/output array does not alias" {
  let s = snapshot([("a.mbt", b"a")])
  let files = s.files()
  files.clear()
  assert_eq(s.files().length(), 1)
}

///|
test "snapshot/replace preserves original" {
  let s = snapshot([("a.mbt", b"abc")])
  let next = match s.replace("a.mbt", b"a") {
    Ok(s) => s
    Err(e) => fail(e)
  }
  assert_eq(next.files()[0].1, b"a")
  assert_eq(s.files()[0].1, b"abc")
  assert_true(s.key() != next.key())
}

///|
test "snapshot/remove preserves original" {
  let s = snapshot([("a.mbt", b"a"), ("b.mbt", b"b")])
  let next = match s.remove("a.mbt") {
    Ok(s) => s
    Err(e) => fail(e)
  }
  assert_eq(next.files(), [("b.mbt", b"b")])
  assert_eq(s.files().length(), 2)
}

///|
test "snapshot/rejects mutations of unknown paths" {
  let s = snapshot([])
  assert_true(s.replace("a.mbt", b"a") is Err(_))
  assert_true(s.remove("a.mbt") is Err(_))
}

///|
test "snapshot/key distinguishes path and bytes" {
  assert_true(snapshot([("a", b"bc")]).key() != snapshot([("ab", b"c")]).key())
  assert_true(snapshot([("a", b"\x00")]).key() != snapshot([("a", b"0")]).key())
}

///|
test "snapshot/limits individual file" {
  let large = Bytes::from_array(FixedArray::make(1048577, b'a'))
  assert_true(@manifest.Snapshot::new([("data", large)]) is Err(_))
}

///|
test "snapshot/limits source file" {
  let large = Bytes::from_array(FixedArray::make(65537, b'a'))
  assert_true(@manifest.Snapshot::new([("a.mbt", large)]) is Err(_))
}

///|
test "snapshot/limits entry count" {
  let files = Array::makei(1001, i => ("x" + i.to_string(), b""))
  assert_true(@manifest.Snapshot::new(files) is Err(_))
}

///|
test "snapshot/limits total bytes" {
  let meg = Bytes::from_array(FixedArray::make(1048576, b'a'))
  let files = Array::makei(17, i => ("x" + i.to_string(), meg))
  assert_true(@manifest.Snapshot::new(files) is Err(_))
}

///|
test "snapshot/rejects directory spelling case conflict" {
  assert_true(
    @manifest.Snapshot::new([("Src/a.mbt", b"a"), ("src/b.mbt", b"b")])
    is Err(_),
  )
}

///|
test "snapshot/replacement repeats encoding checks" {
  assert_true(snapshot([("a.mbt", b"a")]).replace("a.mbt", b"\xff") is Err(_))
}
