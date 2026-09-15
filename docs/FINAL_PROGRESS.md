# Final development progress

## Verified local state (2026-09-15)

Full scripts/verify.ps1 passed on Windows with moonc 0.10.10+f8a486b6f: native 365/365, JS 334/334, wasm-gc 334/334. Counts are distinct test declarations per target, not added across backends. Formatting, native type checks with warning 73, generated interfaces and CLI help passed.

- Phase 1: validated portable globs, immutable bounded project snapshots and protected selection (47 tests).
- Phase 2: lightweight UTF8 byte-span syntax tree (60 tests) and 16 structured pass families (64 tests). Malformed groups suppress structured edits; strings/comments are opaque. This is a reduction-oriented scanner, not a complete MoonBit parser.
- Phase 3: project CLI, independent native copies, file deletion and source edits, stable four-candidate batches with configurable workers. Real jobs=1/4 tests agree and preserve original/support files. Glob omission and failed-copy cleanup have native regressions. Package/dependency manifest edits remain pending.
- Phase 4 foundation: pure repeat/quorum/consecutive three-state policy and Wilson confidence statistics (5 tests). These policies are not yet wired to CLI evaluation; advanced predicates remain pending.
- Phase 5: versioned settled-boundary checkpoints, complete binary-safe snapshots and cache restoration (9 tests). Native atomic replacement and resume CLI work, including budget extension, input/context/toolchain mismatch rejection and uncached final revalidation. Cache keys currently store complete contents; large-run storage and interruption repeat-rate benchmarks remain to be measured.

Feature commits include a1b68cb/2a337c6/f7a82be (syntax), 7d27479/2dcf700/3115dd7 (passes), 4fc1a75/cd50255/9aabc6f/53d3f18/d480543 (project integration), 9f01afe (cleanup), d39f255 (stability), 92750f2 (checkpoint engine), 2ec206d (native resume). All merged locally.

## Resume usage

```text
moonreduce reduce --project --workspace INPUT --output FIRST --max-tests 100 -- COMMAND ARGS
moonreduce resume FIRST/checkpoint.json --output SECOND --max-tests 2500
```

SECOND must be new and outside INPUT. Omitting --output allocates a new temporary result directory. Resume compares the original full snapshot, selection, predicate settings and installed MoonBit toolchain. Jobs and total budgets may change. Checkpoints contain explicit environment overrides needed for replay: treat them as private trusted local configuration. They are not a public environment dump or a security boundary. Abrupt interruption can repeat the unfinished batch; completed cached candidates are skipped. Final verification always executes again.

## Outstanding acceptance work

Complete predicate integration (regex, crash/diagnostic/differential/wrapper, repeated native execution), score and pass controls, manifest reduction, evidence SHA256/environment/replay, remaining CLI/API extensions, 12 examples and 10-fixture benchmarks, jobs determinism across ten runs per setting, measured resume repeat rate, final coverage and Windows/Linux clean installation. See FINAL_PLAN.md for acceptance phases.

Final acceptance is NOT complete. Do not use initial coverage or hosted CI as evidence for these changes. No push after e3d64bc, no final remote release, and registry publication has not been verified. The local 项目申报书.md remains ignored and untracked. User authorization continues through all remaining local development; do not stop at this progress checkpoint.