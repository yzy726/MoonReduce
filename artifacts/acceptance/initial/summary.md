# Initial acceptance — 0.1.0

Updated 2026-09-14. Local technical acceptance is verified. Public registry
publication/installation is the remaining release step. No GitHub upload or hosted
Actions run has been performed. Cross-platform evidence uses the local Windows
and Ubuntu WSL automated matrices under the user's no-GitHub-upload constraint.

| ID | Result | Evidence |
| --- | --- | --- |
| I-01 | PASS locally | Source package extracted into a new directory, CLI builds/runs; platforms/package-smoke.log |
| I-02 | PASS | Default baseline=2, mismatch tests and fixture reports |
| I-03 | PASS | Real isolated moon check E2E on Windows and Linux |
| I-04 | PASS | Matcher matrix and actual timeout/stream-marker fixture |
| I-05 | PASS | 12 text/token passes plus adaptive ddmin |
| I-06 | PASS | All five fixture reports have final_passed=3 |
| I-07 | PASS for trusted test scenarios | Success, baseline/spawn failure, budgets, timeout and cancellation preserve originals |
| I-08 | PASS for measured configuration | Ten independent compiler-fixture runs have identical final SHA256 and counters; determinism-compile/ |
| I-09 | PASS | Exact-content run-scoped cache tests |
| I-10 | PASS | JSON/Markdown/diff/reproduction artifacts; interrupted attempted_commands regression |
| I-11 | PASS | Both native suites 149/149; pure suites 130/130; core lines 439/458 (95.85%) |
| I-12 | PASS | Five fixtures each >=30%; median reduction 89.80% |
| I-13 | LOCAL MATRIX PASS; hosted unrun | platforms/windows-final.log and platforms/linux-final-matrix.log; not GitHub Actions evidence |
| I-14 | PASS locally | Both matrices check format, native types/tests, JS, wasm-gc and CLI |
| I-15 | RELEASE PENDING | Required docs and clean-package smoke pass; registry dry-run accepted; public install still pending |

I-13 deliberately distinguishes local equivalent checks from hosted CI. If an
external reviewer requires actual hosted CI, that requirement remains outstanding;
this report must not be described as proof of a hosted CI run.

## Real benchmarks

| Fixture | Original bytes | Final bytes | Reduction | Baseline/final |
| --- | ---: | ---: | ---: | --- |
| compile_diagnostic | 450 | 39 | 91.33% | 2 / 3 |
| test_failure | 451 | 46 | 89.80% | 2 / 3 |
| nonzero_exit | 476 | 100 | 78.99% | 2 / 3 |
| timeout | 441 | 79 | 82.09% | 2 / 3 |
| noisy_source | 544 | 45 | 91.73% | 2 / 3 |

All runs report original_unchanged=true. See benchmarks.json and each fixture's
unmodified report.json and reduction.diff. The timeout fixture was corrected from
invalid legacy loop syntax, then tested with a 10s timeout and required runtime
marker. Its successful run used 56 commands and 167817 ms.

Each fixture is run with:

```text
moon run cmd/main -- reduce --config testdata/<fixture>/predicate.json --workspace testdata/<fixture>/input --output <new-output-directory> --quiet
```

The successful nonzero run used max_tests=1000 and max_time=600s, now its fixture
defaults. Its earlier BudgetExhausted report remains as budget-stop-report.json.
Earlier Linux failures (probe basename, line endings, Node discovery) are retained
beside final logs and are not counted as passes.

## Toolchains and coverage

Windows: Moon 0.1.20260824 / moonc v0.10.10+f8a486b6f.
Ubuntu WSL: Moon 0.1.20260819 / moonc v0.10.9+6e6c44045; Node v24.11.0.
Dependency: async 0.20.4.

Core coverage: 439/458 lines, 95.85%; instrumentation points 615/645.
See core-coverage.json and docs/TESTING.md for the counting method. Native-only
packages are excluded. The upstream Windows C EINVAL macro warning is retained
in logs; MoonBit --deny-warn passed.

The code-size inventory excludes fixtures, generated interfaces, artifacts and the
bounded test executable. It remains below the 4000-5500 planning range. goal.md
states that code scale is for planning/completeness estimation; no code was added
solely to inflate that number. Exact current counts are in code-size.json.

## Process and publication boundaries

The bounded MoonBit probe reproduced descendant survival before the fix and
passed timeout/cancellation checks after it on both platforms. Cleanup is limited
to identifiable descendants of a runtime-issued PID, with a 3000ms cleanup bound
and direct-parent fallback. See docs/PROCESS_VALIDATION.md for limitations.
No antivirus protections were changed.

The registry dry-run returned HTTP 202 with an explicit successful/no-changes
message after checking a clean extracted package. The Moon CLI nevertheless
returned exit 1 for that response; this discrepancy is retained rather than
reported as a normal CLI success. No actual publication is claimed yet.
