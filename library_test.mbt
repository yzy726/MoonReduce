///|
struct Keep {
  calls : Ref[Int]
}

///|
impl @MoonReduce.CandidateEvaluator for Keep with fn evaluate(self, snapshot) {
  self.calls.val += 1
  Ok(
    if snapshot
      .files()
      .iter()
      .any(f => @source.decode(f.1).unwrap().contains("KEEP")) {
      Interesting
    } else {
      Uninteresting
    },
  )
}

///|
struct Log {
  events : Array[@MoonReduce.Event]
}

///|
impl @MoonReduce.EventSink for Log with fn emit(self, event) {
  self.events.push(event)
}

///|
test "library reduce uses evaluator and emits versioned final evidence" {
  let input = @manifest.Snapshot::new([("a.mbt", b"noise KEEP")]).unwrap()
  let calls = Ref(0)
  let events : Array[@MoonReduce.Event] = []
  let result = @MoonReduce.reduce(input, Keep::{ calls, }, sink=Log::{ events, }).unwrap()
  assert_true(result.best.files()[0].1.length() < 10)
  assert_true(
    @source.decode(result.best.files()[0].1).unwrap().contains("KEEP"),
  )
  assert_eq(result.final_passed, 3)
  assert_eq(result.evaluations, calls.val)
  assert_eq(events.filter(e => e.phase == "final").length(), 3)
  assert_true(events.iter().all(e => e.schema_version == 1))
}

///|
test "library check only evaluates baseline without reduction" {
  let calls = Ref(0)
  let input = @manifest.Snapshot::new([("a.mbt", b"noise KEEP")]).unwrap()
  let result = @MoonReduce.check(input, Keep::{ calls, }).unwrap()
  assert_eq(result.passed, 2)
  assert_eq(calls.val, 2)
}

///|
test "library default passes are named and formatting is opt in" {
  let passes = @MoonReduce.default_passes()
  assert_true(passes.length() >= 28)
  assert_true(!passes.iter().any(p => p.name() == "struct:format"))
}

///|
struct Broken {}

///|
impl @MoonReduce.CandidateEvaluator for Broken with fn evaluate(_, _) {
  Err("fixture failure")
}

///|
test "library evaluator failure is returned without a successful result" {
  let input = @manifest.Snapshot::new([("a.mbt", b"KEEP")]).unwrap()
  assert_true(@MoonReduce.reduce(input, Broken::{  }) is Err("fixture failure"))
}

///|
test "library invalid budgets rejected before evaluator invocation" {
  let calls = Ref(0)
  let input = @manifest.Snapshot::new([("a.mbt", b"KEEP")]).unwrap()
  let config = { ..@MoonReduce.default_config(), max_tests: 1 }
  assert_true(@MoonReduce.reduce(input, Keep::{ calls, }, config~) is Err(_))
  assert_eq(calls.val, 0)
}

///|
test "library repeats every reducing evaluation and emits all trials" {
  let input = @manifest.Snapshot::new([("a.mbt", b"noise KEEP")]).unwrap()
  let calls = Ref(0)
  let events : Array[@MoonReduce.Event] = []
  let config = { ..@MoonReduce.default_config(), repeat: 3, quorum: 2 }
  let result = @MoonReduce.reduce(input, Keep::{ calls, }, config~, sink=Log::{
    events,
  }).unwrap()
  assert_eq(result.evaluations, calls.val)
  assert_eq(events.filter(e => e.phase == "baseline").length(), 3)
  assert_eq(events.filter(e => e.phase == "final").length(), 3)
  assert_true(events.iter().any(e => e.phase == "reducing" && e.trial == 3))
}
