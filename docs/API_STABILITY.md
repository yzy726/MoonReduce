# Public library API

Import `Ag108/MoonReduce` for `default_config`, `default_passes`, `check`, `reduce`,
`CandidateEvaluator`, `EventSink`, `Event` and `ReduceConfig`. Import
`workspace/manifest` for immutable `Snapshot`, `predicate/stability` for decisions,
and `passes/api` for `ReductionPass`. See the runnable `examples/custom_pass`.

The facade is synchronous and platform independent. An evaluator maps one snapshot
to `Result[Decision, String]`; each call is one uncached trial. Passes propose pure
snapshot iterators. Event sinks receive schema-1 observations in candidate/trial
order. Error results propagate; no successful reduction is returned for an
execution error. `check` returns baseline statistics without running passes.

`reduce` uses the same Session scheduler, selection, strict score policy, cache,
repeat/quorum state machine and final validation as native project mode. Native
process/filesystem/time controls live in the `app` adapter. Library callers can
instead drive `reducer/project.Session` and provide async/concurrent evaluation.

Custom pass names must be unique per registry, nonempty and at most 128 code units.
Custom proposals cannot remove protected files or introduce paths. A custom pass
may override a built-in name for a library run. Supply stable version identity in
checkpoint context when using custom behavior with Session restore.

Generated `.mbti` files are the reviewed signature source. JSON versions are
independent: legacy reports 1, project reports/events 2, facade events 1, native
checkpoint envelope 1, project engine checkpoint 4, advanced predicate spec 1,
environment summary 1 and replay result 1. Incompatible versions are rejected.
Final API/release status is recorded in the acceptance report; this document does
not assert a registry publication.
