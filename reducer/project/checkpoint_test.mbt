///|
fn restore_checkpoint(
  s : @project.Session,
  checkpoint : Json,
) -> @project.Session raise {
  match
    @project.Session::restore(
      checkpoint,
      s.result().best,
      [],
      [],
      [],
      "toolchain+config",
      max_tests=100,
    ) {
    Ok(restored) => restored
    Err(e) => fail(e)
  }
}

///|
test "checkpoint restores candidate progression and cached rejection" {
  let original = @manifest.Snapshot::new([("a.mbt", b"KEEP")]).unwrap()
  let s = @project.Session::new(original, [], [], []).unwrap()
  answer(s, true)
  answer(s, true)
  answer(s, false)
  let document = s.checkpoint(original, "context").unwrap()
  let r = @project.Session::restore(document, original, [], [], [], "context").unwrap()
  assert_eq(r.result().evaluations, s.result().evaluations)
  let expected = s.next_batch().map(c => c.snapshot.key())
  assert_eq(r.next_batch().map(c => c.snapshot.key()), expected)
}

///|
test "checkpoint refuses pending batches" {
  let s = session([("a.mbt", b"x")])
  ignore(s.next_batch())
  assert_true(s.checkpoint(s.result().best, "ctx") is Err(_))
}

///|
test "checkpoint validates original and context" {
  let s = session([("a.mbt", b"x")])
  let original = s.result().best
  let document = s.checkpoint(original, "ctx").unwrap()
  assert_true(
    @project.Session::restore(document, original, [], [], [], "different")
    is Err(_),
  )
  let changed = original.replace("a.mbt", b"y").unwrap()
  assert_true(
    @project.Session::restore(document, changed, [], [], [], "ctx") is Err(_),
  )
}

///|
test "checkpoint preserves binary support files" {
  let s = session([("a.mbt", b"x"), ("asset.bin", b"\x00\xff")])
  let r = restore_checkpoint(
    s,
    s.checkpoint(s.result().best, "toolchain+config").unwrap(),
  )
  assert_eq(r.result().best.files(), s.result().best.files())
}

///|
test "checkpoint rejects invalid document and changed selection" {
  let s = session([("a.mbt", b"x")])
  let original = s.result().best
  assert_true(
    @project.Session::restore(null, original, [], [], [], "ctx") is Err(_),
  )
  let document = s.checkpoint(original, "ctx").unwrap()
  assert_true(
    @project.Session::restore(document, original, [], ["a.mbt"], [], "ctx")
    is Err(_),
  )
}

///|
fn altered(document : Json, key : String, value : Json) -> Json {
  match document {
    Object(fields) => {
      let fields = fields.copy()
      fields[key] = value
      fields.to_json()
    }
    _ => document
  }
}

///|
test "checkpoint rejects incompatible schema and impossible counters" {
  let s = session([("a.mbt", b"x")])
  let original = s.result().best
  let saved = s.checkpoint(original, "ctx").unwrap()
  for
    item in [
      ("schema_version", 99),
      ("state", 4),
      ("pass_index", -1),
      ("evaluations", -1),
      ("baseline", 3),
    ] {
    assert_true(
      @project.Session::restore(
        altered(saved, item.0, item.1.to_json()),
        original,
        [],
        [],
        [],
        "ctx",
      )
      is Err(_),
    )
  }
}

///|
test "checkpoint rejects protected file tampering" {
  let s = session([("a.mbt", b"x"), ("README.md", b"keep")])
  let original = s.result().best
  let files : Json = [{ "path": "a.mbt", "bytes": [120] }]
  let saved = altered(s.checkpoint(original, "ctx").unwrap(), "files", files)
  assert_true(
    @project.Session::restore(saved, original, [], [], [], "ctx") is Err(_),
  )
}

///|
test "checkpoint resumes budget exhaustion with enlarged budget" {
  let s = session([("a.mbt", b"KEEP")], budget=5)
  let original = s.result().best
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_eq(s.result().status, BudgetExhausted)
  let r = @project.Session::restore(
    s.checkpoint(original, "ctx").unwrap(),
    original,
    [],
    [],
    [],
    "ctx",
    max_tests=30,
  ).unwrap()
  assert_eq(r.phase(), "reducing")
  assert_eq(r.result().evaluations, 5)
}

///|
test "checkpoint reruns completed final verification without cache" {
  let s = session([("a.mbt", b"x")])
  let original = s.result().best
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  let r = @project.Session::restore(
    s.checkpoint(original, "ctx").unwrap(),
    original,
    [],
    [],
    [],
    "ctx",
  ).unwrap()
  assert_eq(r.phase(), "final")
  assert_eq(r.result().final_passed, 0)
  let before = r.result().evaluations
  while !r.next_batch().is_empty() {
    answer(r, true)
  }
  assert_eq(r.result().evaluations, before + 3)
  assert_eq(r.result().final_passed, 3)
}
