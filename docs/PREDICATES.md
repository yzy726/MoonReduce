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

## Project predicates (schema 1)

Project mode adds repeatable `--stdout-regex`, `--stderr-regex`,
`--diagnostic-code` and `--test-name`. All configured rules combine with the legacy
exit/output rules. A MoonBit diagnostic `[4014]` is extracted as `4014`; E/W-prefixed
codes preserve their prefix. Test names are quoted labels following `test`.

The regex engine supports literals, Unicode, `.`, absolute `^`/`$`, groups,
alternation, character classes/ranges, `*`, `+`, `?`, and common character-class
escapes. Counted repetition, lookaround, backreferences and inline flags are
rejected. Pattern length, nesting, NFA states, input length and execution steps
are bounded. Exhaustion is unresolved rather than a negative cache entry.
`--ignore-case` applies to legacy substring rules; regex remains case sensitive.

`--normalize` applies copy-root, CRLF, location-number, ANSI CSI and long hex-address
normalization. It deliberately does not erase arbitrary diagnostics. Crash
classification distinguishes timeout, memory, abort, arithmetic, illegal-instruction,
signal and panic outcomes using platform exit/signal conventions and observations.
`--timeout-tolerance 10ms` treats near-boundary observations as inconclusive.

`--reference ARG` repeats for every reference argv element. Select comparison with
`--differential stdout|stderr|exit|any`; supplying a reference defaults to any.
The primary and reference commands run in separate copies and both consume budget.
Truncated compared streams or a missing reference are unresolved.

`--wrapper --expect 0` accepts stdout containing a JSON object with
`{"schema_version":1,"interesting":true}` or false. Invalid JSON/version, timeout,
nonzero status or truncated wrapper output is unresolved. Wrapper commands remain
trusted executable input, not dynamically loaded plugins.

Use `--repeat N --quorum K`, optional `--consecutive`, and
`--final-repeat N --final-quorum K` for instability. See FLAKY_FAILURES.md for rate
and confidence interpretation. Final repeat is at least three.
