///|
test "selection/default selects only source in sorted order" {
  let s = snapshot([
    ("z.mbt", b""),
    ("a/x.mbt", b""),
    ("moon.mod", b""),
    ("asset", b""),
  ])
  assert_eq(@manifest.select(s, [], [], []), Ok(["a/x.mbt", "z.mbt"]))
}

///|
test "selection/include constrains subtree" {
  let s = snapshot([("a/x.mbt", b""), ("b/y.mbt", b"")])
  assert_eq(@manifest.select(s, ["a/**"], [], []), Ok(["a/x.mbt"]))
}

///|
test "selection/protect overrides include" {
  let s = snapshot([("a.mbt", b""), ("b.mbt", b"")])
  assert_eq(@manifest.select(s, ["**"], ["a.mbt"], []), Ok(["b.mbt"]))
}

///|
test "selection/protect directory protects descendants" {
  let s = snapshot([("safe/a.mbt", b""), ("b.mbt", b"")])
  assert_eq(@manifest.select(s, [], ["safe"], []), Ok(["b.mbt"]))
}

///|
test "selection/ignore directory excludes descendants" {
  let s = snapshot([("vendor/a.mbt", b""), ("b.mbt", b"")])
  assert_eq(@manifest.select(s, [], [], ["vendor"]), Ok(["b.mbt"]))
  assert_eq(s.files().length(), 2)
}

///|
test "selection/default protects docs and scripts even when source named" {
  let s = snapshot([
    ("README.mbt", b""),
    ("LICENSE.mbt", b""),
    ("scripts/probe.mbt", b""),
    ("a.mbt", b""),
  ])
  assert_eq(@manifest.select(s, ["**"], [], []), Ok(["a.mbt"]))
}

///|
test "selection/default protects nested script directories" {
  let s = snapshot([("pkg/scripts/probe.mbt", b""), ("pkg/a.mbt", b"")])
  assert_eq(@manifest.select(s, [], [], []), Ok(["pkg/a.mbt"]))
}

///|
test "selection/invalid rule fails even on empty snapshot" {
  let s = snapshot([])
  assert_true(@manifest.select(s, ["[bad]"], [], []) is Err(_))
  assert_true(@manifest.select(s, [], ["../bad"], []) is Err(_))
  assert_true(@manifest.select(s, [], [], ["a**b"]) is Err(_))
}

///|
test "selection/duplicate rules do not duplicate targets" {
  assert_eq(
    @manifest.select(snapshot([("a.mbt", b"")]), ["**", "*.mbt"], [], []),
    Ok(["a.mbt"]),
  )
}

///|
test "selection/limits total rule count" {
  assert_true(
    @manifest.select(snapshot([]), Array::make(129, "**"), [], []) is Err(_),
  )
}

///|
test "manifest selection preserves protected package metadata" {
  let s = @manifest.Snapshot::new([
    ("moon.mod", b"name = \"x/y\""),
    ("moon.pkg", b""),
    ("src/moon.pkg", b""),
    ("vendor/moon.pkg", b""),
  ]).unwrap()
  assert_eq(
    @manifest.select_manifests(s, [], ["vendor/**"], [], include_root=false).unwrap(),
    ["src/moon.pkg"],
  )
  assert_eq(
    @manifest.select_manifests(s, ["moon.mod"], [], [], include_root=true).unwrap(),
    ["moon.mod"],
  )
}
