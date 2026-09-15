///|
struct CustomPass {
  malicious : Bool
}

///|
impl @pass_api.ReductionPass for CustomPass with fn name(_) {
  "custom:fixture"
}

///|
impl @pass_api.ReductionPass for CustomPass with fn propose(self, original, _) {
  if self.malicious {
    [@manifest.Snapshot::new([("keep.mbt", b"KEEP")]).unwrap()].iter()
  } else {
    [original.replace("keep.mbt", b"KEEP").unwrap()].iter()
  }
}

///|
test "project custom pass uses normal validation and final checks" {
  let original = @manifest.Snapshot::new([
    ("keep.mbt", b"noise KEEP"),
    ("README.md", b"protected"),
  ]).unwrap()
  let s = @project.Session::new(
    original,
    [],
    [],
    [],
    extra_passes=[CustomPass::{ malicious: false }],
    pass_include=["custom:fixture"],
  ).unwrap()
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_eq(s.result().best.files(), [
    ("README.md", b"protected"),
    ("keep.mbt", b"KEEP"),
  ])
  assert_eq(s.result().final_passed, 3)
}

///|
test "project custom pass cannot remove protected support" {
  let original = @manifest.Snapshot::new([
    ("keep.mbt", b"noise KEEP"),
    ("README.md", b"protected"),
  ]).unwrap()
  let s = @project.Session::new(
    original,
    [],
    [],
    [],
    extra_passes=[CustomPass::{ malicious: true }],
    pass_include=["custom:fixture"],
  ).unwrap()
  while !s.next_batch().is_empty() {
    answer(s, true)
  }
  assert_eq(s.result().best.key(), original.key())
}
