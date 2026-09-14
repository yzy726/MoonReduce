# Compiler diagnostic determinism

Ten independent real CLI reductions were run on Windows with the same original
testdata/compile_diagnostic/input and predicate.json. Each run had a fresh output
directory and run-scoped cache. All ten completed with two baseline matches,
three uncached final matches, 41 evaluations, seven cache hits, unchanged original
and the same 39-byte final file.

SHA256: 68434CFFBA4BF5CBBB4EE704EEC3D16212335011DB6675F8D7A9CB17F1348B7A

Command for each N from 1 through 10:

```text
moon run cmd/main -- reduce --config testdata/compile_diagnostic/predicate.json --workspace testdata/compile_diagnostic/input --output .moonreduce/acceptance/determinism-compile/run-N --quiet
```

runs.json records measured hashes and counters. Per-run report.json files retain
the complete evidence summaries and runtime configuration. SHA256 was computed
with PowerShell Get-FileHash on reduced/repro.mbt; the product itself reports FNV1a64.

This establishes final-content and counter repeatability for this one fixture.
It does not certify all five fixtures, byte-for-byte event equivalence, Linux
repeatability or timeout behavior. Raw process-output hashes may vary with
temporary paths; no such difference was silently removed from these reports.
