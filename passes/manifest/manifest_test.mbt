///|
test "manifest pass removes individual imports with aliases" {
  let text = "import { \"a/b\" @b, \"c/d\" @d, }\n"
  let candidates = @manifest.propose("moon.pkg", text)
  assert_true(
    candidates.iter().any(s => !s.contains("a/b") && s.contains("c/d")),
  )
  assert_true(
    candidates.iter().any(s => s.contains("a/b") && !s.contains("c/d")),
  )
}

///|
test "manifest module fields have a strict whitelist" {
  let text = "name = \"a/b\"\nversion = \"1.0.0\"\nlicense = \"Apache-2.0\"\ndescription = \"noise\"\n"
  let candidates = @manifest.propose("moon.mod", text)
  assert_true(!candidates.is_empty())
  for c in candidates {
    assert_true(
      c.contains("name = \"a/b\"") &&
      c.contains("version = \"1.0.0\"") &&
      c.contains("license = \"Apache-2.0\""),
    )
  }
}

///|
test "manifest module dependency block is immutable" {
  assert_eq(@manifest.propose("moon.mod", "import { \"a/b@1.0.0\", }\n"), [])
}

///|
test "manifest whitelist handles multiline arrays" {
  assert_true(
    @manifest.propose(
      "moon.mod", "name = \"a/b\"\nkeywords = [\n \"one\", \"two\",\n]\n",
    )
    .iter()
    .any(s => !s.contains("keywords") && s.contains("name")),
  )
}

///|
test "manifest comments and strings are not assignments" {
  assert_eq(
    @manifest.propose(
      "moon.mod", "// description = \"x\"\nname = \"description\"\n",
    ),
    [],
  )
}

///|
test "manifest incomplete syntax produces no candidates" {
  assert_eq(@manifest.propose("moon.pkg", "import { \"a/b\""), [])
}

///|
test "manifest edits preserve Unicode boundaries" {
  for
    s in @manifest.propose(
      "moon.mod", "name = \"a/b\"\ndescription = \"😀说明\"\n",
    ) {
    assert_true(@source.decode(@source.encode(s)) is Ok(_))
  }
}

///|
test "manifest refuses unrelated configuration files" {
  assert_eq(@manifest.propose("other.toml", "description = \"x\""), [])
}
