# MoonReduce

A MoonBit testcase reducer and native CLI. It removes irrelevant project files,
declarations, statements and tokens in independent copies while preserving a
user-defined failure predicate.

[中文](README.md) · [Project mode](docs/PROJECT_MODE.md) · [Predicates](docs/PREDICATES.md) · [Library API](docs/API_STABILITY.md)

## Quick start

Use the pinned MoonBit toolchain and a native C compiler. The native runtime uses
moonbitlang/async 0.20.4.

```text
moon update
moon run cmd/main -- reduce --project --config testdata/final/compile_diagnostic/predicate.json --workspace testdata/final/compile_diagnostic/input --output ./compile-result
moon run cmd/main -- replay ./compile-result/report.json
```

Use a fresh output directory outside the input, with an existing parent. Replay
checks SHA-256 and executes uncached final trials in new copies.

```text
moon build --target native --release cmd/main
moon install ./cmd/main --bin ./local-bin
moon run examples/custom_pass --target native
```

## Features

- Single-file and multi-file reduction, protected glob selection and package edits.
- Text/token passes and 16 structured families with conservative syntax fallback.
- Exit/timeout/output predicates, bounded regex, diagnostic fingerprints, wrappers,
  differential commands, repeated quorum and inconclusive decisions.
- Deterministic candidate batches with configurable workers and strict scoring.
- Checkpoints, resume, run-scoped cache, budgets and uncached final verification.
- Checksummed evidence bundles, environment summaries, diff and standalone replay.
- Pure evaluator/pass/event extension contracts and check/reduce library facade.

Commands: check, reduce, resume, replay, diff, explain, passes, config validate,
cache stats and cache clean. Run `--help` for all options. JSON defaults are
validated and overridden by CLI arguments. The twelve examples in `examples/`
include a runnable custom library extension.

## Verification and boundaries

Run `scripts/verify.ps1`, `scripts/benchmark-final.ps1` and
`scripts/determinism-final.ps1` from PowerShell. Pure packages support native,
JavaScript and wasm-gc; process/workspace/CLI packages require native. See
[testing](docs/TESTING.md), [benchmarks](docs/BENCHMARKS.md),
[compatibility](docs/COMPATIBILITY.md) and the
[acceptance record](artifacts/acceptance/final/summary.md).

Only trusted commands/projects are supported. Copies are not a sandbox. The
scanner is not a complete MoonBit parser. Snapshot limits are 1000 files/16 MiB,
1 MiB per file and 64 KiB per MoonBit source. Private checkpoints retain explicit
environment overrides; ordinary reports omit values. Do not put secrets in argv
or share private checkpoints. SHA-256 detects corruption, not a malicious author.
See [security](docs/SECURITY_MODEL.md) and [limitations](docs/LIMITATIONS.md).

Apache-2.0. Dependencies and owned fixture provenance are in THIRD_PARTY.md and
each fixture's LICENSE.
