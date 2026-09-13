# Predicates

Choose `--expect nonzero`, `--expect timeout`, or an exact numeric exit code.
Timeout is distinct from nonzero: a killed timeout cannot satisfy a normal
nonzero rule. Failure to launch is an execution error, never a matching failure.

`--stdout-contains`, `--stderr-contains`, `--stdout-not-contains` and
`--stderr-not-contains` accept repeated text rules. Every rule must match.
Use a distinctive diagnostic, rather than only nonzero, to prevent failure drift.
`--ignore-case` applies Unicode lowercase matching to all configured rules.
CRLF is normalized to LF, the copied workspace path becomes `<workspace>`, and
`--strip-locations` optionally replaces colon-prefixed numbers with `<n>`.
Location stripping is deliberately opt-in because it can broaden a fingerprint.

Positive rules can match retained truncated output. Negative rules cannot prove
absence in discarded output and therefore reject truncated streams. Process
output is decoded lossily when non-UTF8; target source is decoded strictly.

Example from the repository root:

```text
moon run cmd/main -- check --workspace testdata/compile_diagnostic/input --target repro.mbt --stderr-contains "The value identifier mr_missing_symbol is unbound" -- moon check --target native
```

JSON configuration keys use underscores: `stdout_contains`, `stderr_contains`,
`stdout_not_contains`, `stderr_not_contains`, `ignore_case`, `strip_locations`.
Output-rule values are arrays of strings. `environment` maps names to strings.
CLI options override JSON defaults; unknown keys and duplicate scalar CLI options
are rejected. Repeatable CLI rules replace the corresponding JSON array.
