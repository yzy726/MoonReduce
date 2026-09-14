# Final acceptance implementation plan

The user authorized continuation after the local proposal. Preserve the initial CLI and develop additive packages before integrating project mode. All new work stays in local Git; public releases and hosted final CI are pending authorization. Do not restore AI_USAGE.md or track 项目申报书.md. Historical release and AI-record requirements in goal.md are overridden only to this extent; do not mark F-18 passed.

## Architecture

Project candidates contain immutable path/content snapshots. Selection uses portable, anchored glob rules; explicit protection wins over selection, ignored entries are omitted only when producing execution copies. Cache keys include complete snapshots and evaluation configuration. Pure planning and scoring are separate from native workspace and process operations. Keep existing Session and single-file CLI working while project mode is added.

## Phase 1 path selection — batch 1

1. Create workspace/glob/moon.pkg, glob.mbt and glob_test.mbt. API matches(pattern : String, path : String) -> Result[Bool,String]. Support literal components, *, ?, and ** as a whole component; root-anchored and case-sensitive; reject unsupported syntax, traversal and excessive patterns. Test zero/multiple directory **, Unicode, Windows separators, reserved paths and invalid patterns. Verify moon test --target native workspace/glob and both pure targets.
2. Create workspace/manifest/moon.pkg, manifest.mbt and manifest_test.mbt. API Snapshot::new(Array[(String,Bytes)]) -> Result[Snapshot,String], files()->Array[(String,Bytes)], replace(String,Bytes)->Result[Snapshot,String], remove(String)->Result[Snapshot,String], key()->String. Canonical sorted paths, portable case collision rejection, strict UTF8 for mbt, explicit size limits and caller mutation isolation. Verify deterministic key, deletion, immutable source, duplicate paths and limits across all targets.
3. Create selection.mbt and selection_test.mbt in manifest. API select(Snapshot,Array[String],Array[String],Array[String])->Result[Array[String],String]. Default **/*.mbt; protection and ignore precedence, default protected documentation/scripts/manifests, deletion eligibility separate from copy omission. Verify glob and protected ancestor cases. Record first phase status in docs/FINAL_PROGRESS.md.

## Phase 2 lightweight structure — batches 2 and 3

Create moon_syntax with scan(String)->ReductionTree, byte spans, tokens, balanced groups, declaration and statement ranges, diagnostics for unsupported or unclosed constructs. Split tasks into balanced groups, declaration boundaries and statement/branch boundaries. Test at least 60 distinct grammar scenarios, including Unicode byte boundaries and opaque strings/comments. Extend passes/structured with documented preconditions and fallback for each of 16 transforms in goal.md; introduce families separately with failing assertions before production code. Verify syntax/pass suites on native, JS and wasm-gc; no parser dependency in public interfaces.

## Phase 3 project execution — batches 4 and 5

Extend native workspace with prepare_snapshot and copy_snapshot using manifest immutable entries. Add pure project candidate planner for file, package and selected source edits, then integrate app and config with project mode. Validate every candidate in its own directory, preserve originals and protected paths. Add multi_file_project E2E before claiming project mode works. Separate manifest dependency/import edits and whitelisted moon.mod changes into their own tasks.

## Phase 4 complete predicate — batches 6 and 7

Add bounded regex matching, crash classification, normalization and diagnostic extraction as independent pure modules. Introduce versioned predicate serialization, differential observations and wrapper protocol. Add repeat/quorum/consecutive state machine with explicit inconclusive status, baseline rate and final 3/3 defaults. Native runner integration follows pure tests; at least 40 predicate scenarios, fake observations for timing boundaries, real differential and flaky E2E.

## Phase 5 persistence and scheduling — batches 8 and 9

Add versioned checkpoint serialization with full snapshot/config/toolchain validation, then native atomic writes and resume command. Save on cancel/budget paths; measure repeated candidate evaluations at <=5%. Add stable candidate batch scheduling and native jobs execution with isolated workspaces. Compare jobs=1/4 final hashes over ten runs each, reject stale results and account for attempts/cancellation.

## Phase 6 evidence and product interface — batches 10 and 11

Add original summary, environment allowlist, SHA256 checksums and replay validation to artifact packages. Stabilize evaluator/pass/event traits and add custom extension examples. Add resume, replay, diff, config validate and cache commands in separate tasks with blackbox E2E. Version JSON schemas and audit .mbti changes. Keep optional source formatting opt-in.

## Phase 7 final acceptance — batches 12 and 13

Expand to 12 runnable examples and 10 fixtures; record >=280 scenarios, >=20 native E2E and >=85% core line coverage. Execute fixed-budget benchmarks and final uncached checks, compare original tree hashes and Windows/Linux local installation smoke. Write artifacts/acceptance/final/summary.md with F-01..F-18 evidence and explicit release/hosted-CI gaps. Never fabricate benchmark, publication or human review evidence.

## Verification and commit contract

Tests use public blackbox assertions grouped by behavior; do not count loop cases as separate tests. Each behavior increment starts with a failing test, then minimal code, formatter/type/interface checks, relevant target tests and a local feature commit merged with --no-ff. Use at most three closely related tasks per batch and checkpoint the plan before proceeding. Full native/pure regression runs at integration boundaries; bounded process probes only, no security-software changes.
