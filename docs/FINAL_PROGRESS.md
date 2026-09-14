# Final development progress

## Phase 1 completed — portable project model

- workspace/glob provides validated, anchored *, ? and whole-component ** matching; Unicode scalar ?, portable separators, unsupported syntax and traversal rejection. 17 blackbox tests.
- workspace/manifest provides defensive immutable snapshots, canonical lexical path order, case collision and file/directory conflict rejection, strict source UTF8, file/count/total size limits, pure replace/remove and an exact versioned path/content key. 20 blackbox tests.
- manifest selection applies explicit includes, ignores and protections with default documentation/scripts/Git metadata protection. Ancestor protection wins; selection never mutates the snapshot or removes support files. 10 blackbox tests.

Verification on Windows with moonc 0.10.10+f8a486b6f: scripts/verify.ps1 passed; native 196/196, JS 177/177, wasm-gc 177/177. Native types, formatting, generated interfaces and CLI help passed. No .mbti regression in existing packages. New tests are repeated across backends, not counted as different scenarios per backend.

Feature commits: 98e7065 (glob), 8f9bd55 (snapshot), 9fc785c (selection and lexical-order regression). All merged locally. No push after e3d64bc; the project proposal remains ignored and untracked.

## Remaining work

This is foundation for F-02, not a completed project reducer. Existing CLI remains single-target. Next planned phase: lightweight structure with byte spans, conservative recovery, declaration and statement ranges; then structured passes and integration with independent native candidate workspaces. Complete predicate, checkpoint/resume, stable concurrent execution, product CLI and final benchmarks follow docs/FINAL_PLAN.md.

Final acceptance is not complete. New final code has not run hosted CI, registry publication was not verified, and no final release was performed. Do not infer final coverage from the initial coverage report. The user's no-push/no-remote-release constraint remains in force.
