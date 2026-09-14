# Ag108/MoonReduce

MoonReduce is a MoonBit library and native CLI for reducing one failing UTF-8
`.mbt` file while retaining a specified external-command failure.

**Status: 0.1.0 local acceptance verified; see the evidence for publication status.**
See [acceptance status](artifacts/acceptance/initial/summary.md) and
[limitations](docs/LIMITATIONS.md).

## Quick start

Requires the MoonBit native toolchain and a C compiler. Tested locally with
MoonBit 0.1.20260824, async 0.20.4 and Windows.

```text
moon check --deny-warn
moon run cmd/main -- --help
moon run cmd/main -- passes
moon run cmd/main -- reduce --config testdata/compile_diagnostic/predicate.json --workspace testdata/compile_diagnostic/input --output ./compile_diagnostic-result
moon run cmd/main -- explain ./compile_diagnostic-result/report.json
```

Choose a new output directory outside the input workspace. Its parent must exist.
The result contains reduced/, report.json, report.md, reduction.diff,
reproduce.txt and events.ndjson. The compiler fixture locally reduced from
450 to 39 bytes, preserving its diagnostic with three uncached final matches.

Build with `moon build --target native cmd/main`. The executable is under
`_build/native/debug/build/cmd/main/`; the extension varies by platform.
Use `moon run cmd/main -- ...` as the portable development command.

## Behavior

Two baseline matches precede adaptive ddmin and twelve deterministic text/token
passes. Only strictly smaller matching candidates are accepted. Full-content
run-scoped caching avoids duplicate evaluation. Three final checks bypass cache.
Budgets/cancellation retain the last accepted result, but incomplete final checks
do not certify it. Only run trusted projects and commands: copies are not a sandbox.
Descendant timeout/cancellation tests pass on Windows and Ubuntu; see the process validation limits.

## Commands

check validates the baseline; reduce runs the pipeline; passes lists the registry;
explain formats report JSON. --help lists all options, including JSON defaults,
CLI overrides, stream rules, limits and progress. See [predicates](docs/PREDICATES.md),
[passes](docs/REDUCTION_PASSES.md), [reports](docs/REPORT_FORMAT.md),
[design](docs/DESIGN.md), and [testing](docs/TESTING.md).

```text
moon run cmd/main -- reduce --config testdata/noisy_source/predicate.json --workspace testdata/noisy_source/input --output ./noisy-result --max-tests 100 --max-time 120s --timeout 10s --output-limit 65536 --verbose
```

Five [examples](examples/) cover compiler diagnostics, test failure, nonzero,
timeout and noise. All five passed three final checks and at least 30% byte reduction.

## Library

Import Ag108/MoonReduce/reducer/engine for the pure Session request/verdict API,
predicate/matcher for rules, or app for native execution. Generated .mbti files
record current signatures. APIs are pre-stable. Apache-2.0; see THIRD_PARTY.md and REFERENCES.md for attribution.
