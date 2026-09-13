# Testing

Run from the repository root:

```text
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon info
moon test --target js --enable-coverage --deny-warn
moon coverage report -f summary
moon coverage report -f coveralls -o coverage.json
```

Native packages are excluded from JS/wasm-gc. The regular suite excludes suspended
PowerShell/process-tree probes; never count those as passing. Native E2E tests
execute trusted local moon commands and filesystem operations, not remote services.

Coverage summary counts instrumentation points. Line coverage uses non-null
coverage array entries, with positive entries counted as covered. The Windows
coveralls exporter emits unescaped path backslashes; normalize only source-file
name separators before JSON parsing, retaining the raw file for auditing.

Tests cover predicate tables, invalid configuration, path/encoding boundaries,
lexer opacity, passes, cache/budget/cancel and reports. The engine exhaustively
checks all 255 nonempty required subsets of eight lines under a monotone predicate;
this is not a proof of global minimality for arbitrary predicates. Ten independent
pure runs check deterministic final content.

Native tests cover fresh-copy isolation, original preservation, confinement,
owner-marker cleanup, process capture, missing executables and a complete real
moon check reduction. Benchmark commands are in examples/*/README.md. A pass
requires baseline=2, final=3, unchanged original and at least 30% fewer bytes.
Budget stops without final evidence do not pass. Timeout remains deferred.
