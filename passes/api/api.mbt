///|
/// Pure extension point. Names must be stable and unique within a run.
/// Proposals are untrusted edits: the engine still enforces selection, protected
/// files, existing paths, strict score improvement and predicate validation.
pub(open) trait ReductionPass {
  fn name(Self) -> String
  fn propose(Self, @manifest.Snapshot, Array[String]) -> Iter[
    @manifest.Snapshot,
  ]
}
