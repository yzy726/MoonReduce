///|
fn matches(pattern : String, text : String) -> Bool {
  @regex.Regex::compile(pattern).unwrap().matches(text).unwrap()
}

///|
test "regex searches unanchored literals" {
  assert_true(matches("error", "an error here"))
  assert_true(!matches("error", "warning"))
}

///|
test "regex anchors complete input" {
  assert_true(matches("^abc$", "abc"))
  assert_true(!matches("^abc$", "xabc"))
  assert_true(!matches("^abc$", "abc\n"))
}

///|
test "regex alternation and grouped sequence" {
  assert_true(matches("^(error|panic): [0-9]+$", "panic: 123"))
  assert_true(!matches("^(error|panic): [0-9]+$", "panic: x"))
}

///|
test "regex optional group" {
  assert_true(matches("^ab(c)?d$", "abd"))
  assert_true(matches("^ab(c)?d$", "abcd"))
}

///|
test "regex star accepts zero and many" {
  assert_true(matches("^ab*c$", "ac"))
  assert_true(matches("^ab*c$", "abbbc"))
}

///|
test "regex plus requires at least one" {
  assert_true(matches("^ab+c$", "abc"))
  assert_true(!matches("^ab+c$", "ac"))
}

///|
test "regex wildcard excludes newline" {
  assert_true(matches("^a.c$", "a中c"))
  assert_true(!matches("^a.c$", "a\nc"))
}

///|
test "regex Unicode literal is a scalar" {
  assert_true(matches("^😀+$", "😀😀"))
  assert_true(!matches("^😀$", "😀😀"))
}

///|
test "regex character class negation" {
  assert_true(matches("^[^0-9]+$", "error"))
  assert_true(!matches("^[^0-9]+$", "err1"))
}

///|
test "regex digit word whitespace escapes" {
  assert_true(matches("^\\w+\\s\\d+$", "abc_ 123"))
  assert_true(!matches("^\\d+$", "abc"))
}

///|
test "regex escaped punctuation" {
  assert_true(matches("^\\[x\\]\\.$", "[x]."))
}

///|
test "regex empty alternatives are safe" {
  assert_true(matches("^(a|)*$", "aaa"))
  assert_true(matches("^(a|)*$", ""))
}

///|
test "regex empty pattern matches" {
  assert_true(matches("", "anything"))
}

///|
test "regex invalid constructs are rejected" {
  for
    p in [
      "(", "a)", "[", "[]", "[z-a]", "*a", "a**", "a{2}", "\\", "(?=a)", "\\1",
    ] {
    assert_true(@regex.Regex::compile(p) is Err(_))
  }
}

///|
test "regex evaluation has explicit work limit" {
  let r = @regex.Regex::compile("(a|aa)*b").unwrap()
  assert_true(r.matches("aaaaaaaaaaaaaaaa", max_steps=10) is Err(_))
  assert_true(!r.matches("aaaaaaaaaaaaaaaa").unwrap())
}

///|
test "regex pattern and nesting are bounded" {
  assert_true(@regex.Regex::compile("a".repeat(1025)) is Err(_))
  assert_true(
    @regex.Regex::compile("(".repeat(40) + "a" + ")".repeat(40)) is Err(_),
  )
}

///|
test "regex complemented shorthands" {
  assert_true(matches("^\\D\\W\\S$", "a!x"))
  assert_true(!matches("^\\D$", "7"))
}

///|
test "regex escaped class dash and bracket" {
  assert_true(matches("^[\\]\\-]+$", "]--]"))
}

///|
test "regex nested alternatives retain suffix" {
  assert_true(matches("^(a(b|c)|d)+z$", "abacdz"))
  assert_true(!matches("^(a(b|c)|d)+z$", "abacdy"))
}

///|
test "regex long ambiguous repetition stays bounded" {
  assert_true(!matches("^(a|aa)*b$", "a".repeat(10000)))
}

///|
test "regex overlapping branches and empty input" {
  assert_true(matches("^(ab|a)b$", "ab"))
  assert_true(!matches(".+", ""))
  assert_true(matches("^$", ""))
}

///|
test "regex class work contributes to execution limit" {
  let r = @regex.Regex::compile("[" + "z".repeat(100) + "]").unwrap()
  assert_true(r.matches("a", max_steps=20) is Err(_))
}
