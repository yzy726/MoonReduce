# Testing

Use ./scripts/verify.ps1 with PowerShell. It builds the bounded native test probe
before running the native suite. The equivalent individual commands are:

```text
moon info --target native
moon fmt --check
moon check --target native --warn-list +73 --deny-warn
moon build --target native tools/process_probe
moon test --target native --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon run cmd/main -- --help
```

The native probe is _build/native/debug/build/tools/process_probe/process_probe.exe
on both measured platforms. MR_PROCESS_PROBE can override it with an absolute
path. It never invokes a shell and naturally expires within ten seconds.

The suite includes 149 native tests (including seven app pipeline E2Es and two
descendant lifecycle tests) and 130 pure-backend tests. Tests cover predicate
tables, invalid configuration, UTF-8/path boundaries, lexer opacity, passes,
cache/budget/cancel, reports, original preservation and isolated real moon check.
The engine checks all 255 nonempty required subsets of eight lines under a
monotone predicate; this does not prove global minimality for arbitrary predicates.

Coverage commands:

```text
moon test --target js --enable-coverage --deny-warn
moon coverage report -f summary
moon coverage report -f coveralls -o coverage.json
```

Summary coverage counts instrumentation points. Line coverage counts non-null
coveralls entries, with positive entries covered. The measured Windows exporter
emits unescaped path separators in name fields; normalize only those fields before
parsing. Native-only code is excluded from core coverage. Raw platform and fixture
evidence is under artifacts/acceptance/initial.

All five owned fixtures passed baseline=2, final=3, original preservation and >=30%
byte reduction. The compiler fixture additionally passed ten independent runs
with identical final SHA256 and counters. Historical failed reports/logs are kept;
they are not counted as passing. Old PowerShell probes are not in this suite.
