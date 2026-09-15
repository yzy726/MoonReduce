# Testing

Run `./scripts/verify.ps1` from PowerShell. It generates interfaces, checks
formatting and warning 73, builds the bounded native probe, runs native/JS/wasm-gc
suites and CLI help. Public `.mbti` changes must be reviewed and committed.

Current local core verification: 492 native test declarations, 435 on each pure
backend. Counts are not added across targets. The application has 43 test
declarations, including real compiler/process E2E and fault-injection checks.
See `artifacts/acceptance/final/test-inventory.txt` for exact names and locations.

Coverage is measured on all project pure packages, excluding native-only process,
workspace and app adapters and excluding dependencies. Coveralls line coverage
counts non-null entries, with positive entries covered. Current measured result:
1467/1585 instrumented lines, 92.56%. The Windows exporter needs path separators
normalized only within its name fields before JSON parsing.

```text
moon coverage clean
moon test --target js --enable-coverage --deny-warn
moon coverage report -f coveralls -o .moonreduce/final-coverage.json
```

Always clean old coverage counters before a new measurement. Otherwise changes to
instrumentation sites can mix incompatible runs. Native tests cover additional
filesystem/process behavior outside the pure-core denominator.

The suite includes 60 syntax cases, 64 structured cases, per-pass strict-decrease
and determinism invariants, exhaustive eight-element ddmin checks, stable batch
ordering, cache reuse, zero known repeats on checkpoint restore, invalid replies,
protected paths and original preservation. Predicate suites cover Unicode, bounded
regex, timeout tolerance, differential observations, wrappers and real 5/4 flaky
statistics. Native fault checks cover bad commands/config, process timeout and
cancellation, partial checkpoint writes, occupied paths and corrupt evidence.

`tools/process_probe` expires naturally within ten seconds in its waiting modes.
It uses no shell and requires no antivirus exception. Its expected debug output
path is `_build/native/debug/build/tools/process_probe/process_probe.exe` on both
tested platforms; `MR_PROCESS_PROBE` can override that path.

Fixed budget, uncached final replay and parallel determinism scripts are in
`scripts/benchmark-final.ps1` and `scripts/determinism-final.ps1`. Preserve failed
runs as failures. Platform, installation and benchmark evidence is under
`artifacts/acceptance/final`; historical initial evidence is separate.
