///|
test "invariants/import deterministic strict reduction" {
  let source = "import { \"a/b\" }"
  let first = @structured.propose("import", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("import", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/function deterministic strict reduction" {
  let source = "fn unused() {}"
  let first = @structured.propose("function", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("function", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/type-declaration deterministic strict reduction" {
  let source = "enum E { LongName }"
  let first = @structured.propose("type-declaration", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(
    first,
    @structured.propose("type-declaration", source, allow_format=true),
  )
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/test deterministic strict reduction" {
  let source = "test \"sample\" { () }"
  let first = @structured.propose("test", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("test", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/parameter deterministic strict reduction" {
  let source = "fn f[T](x : T, y : T) {}"
  let first = @structured.propose("parameter", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("parameter", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/field deterministic strict reduction" {
  let source = "struct S { a : Int, b : Int }"
  let first = @structured.propose("field", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("field", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/statement deterministic strict reduction" {
  let source = "fn f() { let a = 1; a }"
  let first = @structured.propose("statement", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("statement", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/if-branch deterministic strict reduction" {
  let source = "fn f() { if true { 100 } else { 200 } }"
  let first = @structured.propose("if-branch", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("if-branch", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/match-arm deterministic strict reduction" {
  let source = "fn f(x) { match x { A => 1, B => 2 } }"
  let first = @structured.propose("match-arm", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("match-arm", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/loop-body deterministic strict reduction" {
  let source = "fn f() { for x in xs { foo(); bar() } }"
  let first = @structured.propose("loop-body", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("loop-body", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/binding deterministic strict reduction" {
  let source = "fn f() { let x = expensive(); x }"
  let first = @structured.propose("binding", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("binding", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/expression deterministic strict reduction" {
  let source = "fn f() { (100 + 200) }"
  let first = @structured.propose("expression", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("expression", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/type-annotation deterministic strict reduction" {
  let source = "fn f(x : Array[Int]) {}"
  let first = @structured.propose("type-annotation", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(
    first,
    @structured.propose("type-annotation", source, allow_format=true),
  )
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/metadata deterministic strict reduction" {
  let source = "/// documentation\nfn f() {}"
  let first = @structured.propose("metadata", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("metadata", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/identifier-literal deterministic strict reduction" {
  let source = "fn very_long_name() { 12345 }"
  let first = @structured.propose(
    "identifier-literal",
    source,
    allow_format=true,
  )
  assert_true(!first.is_empty())
  assert_eq(
    first,
    @structured.propose("identifier-literal", source, allow_format=true),
  )
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "invariants/format deterministic strict reduction" {
  let source = "fn  f() {  1  }"
  let first = @structured.propose("format", source, allow_format=true)
  assert_true(!first.is_empty())
  assert_eq(first, @structured.propose("format", source, allow_format=true))
  for i in 0..<first.length() {
    assert_true(
      @source.encode(first[i]).length() < @source.encode(source).length(),
    )
    for j in (i + 1)..<first.length() {
      assert_true(first[i] != first[j])
    }
  }
}

///|
test "structured/all passes reject incomplete syntax" {
  for name in @structured.names() {
    assert_eq(@structured.propose(name, "fn f() {", allow_format=true), [])
  }
}

///|
test "structured/type declaration includes derive suffix" {
  assert_true(
    @structured.propose(
      "type-declaration", "struct S { x : Int } derive(Eq)\nfn f() {}",
    ).contains("fn f() {}"),
  )
}

///|
test "structured/generic parameter removal" {
  assert_true(
    @structured.propose("parameter", "fn f[LongType](x : LongType) {}").contains(
      "fn f[](x : LongType) {}",
    ),
  )
}
