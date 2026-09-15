# Final benchmark protocol

Build `moon build --target native --release cmd/main`, then run
`./scripts/benchmark-final.ps1` in PowerShell. It requires the pinned MoonBit
compiler and native C compiler. Each run gets a fresh `.moonreduce/final-benchmark`
directory. No previous candidate cache is loaded. The toolchain installation/cache
is shared and should be recorded as warm.

The fixed, original Apache-2.0 inputs under `testdata/final` cover three real
`moon check` failures, three `moon test` failures, two explicit runtime exits,
one timeout and one multi-file compiler failure. Irrelevant helper declarations
exercise structural/token reduction. Initial fixtures remain versioned separately.

Every run records status, bytes, significant tokens, command count, wall time,
baseline predicate duration, final count, independent original-file SHA-256 checks,
and a fresh evidence replay. Budget: 2500 command launches and 600 seconds; timeout
fixture uses ten seconds per command and the bounded `text:line-block` pass. The first two-second timeout run failed its baseline and remains in the failure evidence. Report all runs, including failures; do not
replace the matrix with best-case timing. Byte scores include protected captured
files, while token scores measure MoonBit source tokens.

Quality gates: at least eight deterministic fixtures reduce bytes by 50%, median
byte reduction >=70%, median token reduction >=60%; multi-file input removes half
of reducible files or 60% of source bytes. At least nine fixtures meet the budget.
Predicate times above 200 ms are identified rather than presented as meeting the
fast-predicate premise. Final numerical results belong to
`artifacts/acceptance/final/summary.md`.
