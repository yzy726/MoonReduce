///|
test "valid/help documents four initial commands" {
  let text = @app.help()
  for
    command in [
      "check", "reduce", "explain", "passes", "--max-tests", "--timeout", "--json-events",
    ] {
    assert_true(text.contains(command))
  }
}

///|
async test "e2e/real moon diagnostic reduced in isolated copies" {
  let root = @fs.tmpdir(prefix="moonreduce-compile-e2e-")
  let input = root + "/project 中文"
  @fs.mkdir(input)
  @fs.write_file(
    input + "/moon.mod",
    "name = \"test/fixture\"\n",
    create_mode=@fs.CreateNew,
  )
  @fs.write_file(input + "/moon.pkg", "", create_mode=@fs.CreateNew)
  let original = "// noise one\n// noise two\n///|\nfn bad() -> Int { keep_missing_symbol }\n// trailing irrelevant\n"
  @fs.write_file(input + "/a.mbt", original, create_mode=@fs.CreateNew)
  let c = @config.parse(
    [
      "reduce",
      "--workspace",
      input,
      "--target",
      "a.mbt",
      "--output",
      root + "/output",
      "--quiet",
      "--max-tests",
      "80",
      "--stderr-contains",
      "The value identifier keep_missing_symbol is unbound",
      "--",
      "moon",
      "check",
      "--target",
      "native",
    ],
    None,
  ).unwrap()
  let r = @app.execute(c)
  assert_eq(r.result.baseline_passed, 2)
  assert_eq(r.result.final_passed, 3)
  assert_true(r.result.best.length() < original.length())
  assert_eq(@fs.read_file(input + "/a.mbt").text(), original)
  for name in ["report.json", "report.md", "reduction.diff", "reproduce.txt"] {
    assert_true(@fs.exists(root + "/output/" + name))
  }
}
