# Report format, schema 1

The output directory contains `reduced/`, `report.json`, `report.md`,
`reduction.diff`, `reproduce.txt` and `events.ndjson`. Execution failures also
produce `error.txt` when artifact writing remains possible.

JSON includes tool/version, terminal status and exit code, before/after UTF-8 byte
counts, significant tokens, physical lines, FNV-1a identifiers, baseline/final
counts, actual recorded evaluations, cache hits, elapsed milliseconds, original
manifest equality, accepted sizes, pass counters and sanitized configuration.
Baseline/final evidence records the verdict, exit/timeout, elapsed time, hashes
of captured streams and truncation flags. Full stream contents are not embedded.

All environment override names are listed and all values are omitted, including
nonsensitive values. Reproduction requires restoring those overrides manually.
Do not put credentials in command arguments: argv is recorded verbatim.

`completed` requires Completed status, three final matches and an unchanged
original manifest. `check` performs only two baseline runs, so its exit status
can be 0 while `completed` remains false: it has not performed a reduction.
Results stopped by cancellation or wall budget may have fewer than three final
checks; the best prior matching candidate remains exportable but is not certified.

The unified diff uses one complete-file hunk and preserves no-final-newline
markers. Reproduction records an argv JSON array and working directory under
`reduced`; it does not invent shell quoting. NDJSON events are capped at roughly
4 Mi code units; event truncation metadata is not yet implemented.

attempted_commands counts calls to the process adapter, including cancelled and failed-start attempts. evaluations retains its completed-engine-verdict meaning. The new field is additive in schema 1; historical reports can omit it.
