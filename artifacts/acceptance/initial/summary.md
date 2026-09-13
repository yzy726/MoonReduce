# Initial acceptance status

Status: INCOMPLETE. Updated 2026-09-14. All evidence is local; no GitHub push or publication.

Current phase: phase 8 acceptance and phase 9 documentation/maintenance.
Core source/model, matcher, twelve passes, engine/cache/budgets, configuration,
native workspace/evaluator, reports and CLI are implemented.

| Gate | Local result | Remaining |
| --- | --- | --- |
| I01 install/run | Source CLI runs | Public package install not verified |
| I02 baseline | Two-match baseline covered | None for deterministic fixtures |
| I03 real project | Real moon check end-to-end passes | Broader platforms |
| I04 predicates | Rule matrix passes | Native timeout/tree evidence deferred |
| I05 passes | 12 passes and adaptive ddmin implemented | None for initial text/token scope |
| I06 final | Three uncached checks in 3 successful fixtures | All five fixtures |
| I07 original preservation | Success and workspace isolation tests pass | Native timeout/cancel failure matrix |
| I08 determinism | 10 pure engine runs agree | 10 runs of each real fixture |
| I09 cache | Run-scoped exact-content cache tested | None for current sequential scope |
| I10 reports | JSON/Markdown/diff/reproduce emitted | Interrupted execution counts have limitations |
| I11 tests/coverage | Native 139/139; prior JS and wasm-gc 130/130; core lines 438/457 (95.84%) | Native timeout scenarios |
| I12 benchmarks | 3 of 5 complete with final=3 | nonzero_exit and timeout |
| I13 Windows/Linux CI | Windows local tests pass | CI configuration and Linux run evidence |
| I14 quality | Standard native test --deny-warn passes | Fresh full gates after documentation; optional warning 73 cleanup |
| I15 delivery | Required documentation prepared | Public package release and human review |

## Benchmark evidence

See benchmarks.json and each fixture's unmodified report.json and reduction.diff.
Original input sources remain in testdata. Commands:

```text
moon run cmd/main -- reduce --config testdata/<fixture>/predicate.json --workspace testdata/<fixture>/input --output .moonreduce/acceptance/<fixture> --quiet
```

- compile_diagnostic: 450 -> 39 bytes, baseline=2, final=3, unchanged original.
- test_failure: 451 -> 46 bytes, baseline=2, final=3, unchanged original.
- noisy_source: 544 -> 45 bytes, baseline=2, final=3, unchanged original.
- nonzero_exit: 476 -> 100 bytes, BudgetExhausted at 120016 ms, final=0.
  This is NOT a successful acceptance run. A retry with --max-tests 60
  --max-time 180s produced no report and has no usable completion evidence.
- timeout: not executed in the acceptance set. Process-tree validation is deferred
  after the user's Huorong warning; see docs/PROCESS_VALIDATION.md.

No five-fixture median or complete determinism claim is made.

## Coverage and toolchain

core-coverage.json records line counts from the JS coveralls exporter. Exclude
null entries from the denominator and count positive entries as covered.
The summary instrumentation-point metric is different: 614/644.
Coverage does not include native-only packages. See docs/TESTING.md.

Moon 0.1.20260824 (dae026a), moonc v0.10.10+f8a486b6f, async 0.20.4.
Native suite on Windows passed 139/139 in this verification session. The C compiler
emitted an upstream async EINVAL macro-redefinition warning; MoonBit --deny-warn
did not reject it. This should be tracked separately from MoonBit warnings.

## Outstanding boundaries

Descendant process cleanup is not certified. Direct-command timeout support must
not be presented as process-tree containment. No antivirus settings were changed.
No Linux execution, GitHub Actions run or mooncakes publication has been performed.
Effective-code size still requires a final measured inventory; do not pad it.
