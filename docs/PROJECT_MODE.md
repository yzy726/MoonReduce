# Project mode

`moonreduce reduce --project --workspace INPUT --output NEW -- COMMAND ARGS`

A snapshot contains up to 1000 regular files, 1 MiB per file and 16 MiB total;
selected MoonBit sources are at most 64 KiB each. Every trial starts with a new
copy. Reference commands get a separate copy. Originals are compared again at
exit. Build/cache directories and symlinks are omitted during snapshot capture.

Selection defaults to `**/*.mbt`. Patterns are root anchored and case sensitive:
`*` matches within one component, `?` matches one character, and `**` matches
whole path components. A protected or ignored ancestor wins over inclusion.
README, license, script and Git metadata paths are protected by default.

The `package` pass can remove a directory only when every captured file below it
is eligible, including its selected `moon.pkg`. A protected README or asset keeps
the package directory intact. The `file` pass removes individual source files.
The opt-in `manifest` pass removes import entries from `moon.pkg` and only
`description`, `keywords`, `repository` fields from `moon.mod`. Module identity,
version, license, dependencies and build settings are never rewritten by it.

`--pass-include NAME` and `--pass-exclude NAME` are repeatable. An explicit include
list replaces the default registry selection. `struct:format` is also opt-in.
`--score bytes|tokens|lines` selects a lexicographic ordering with byte/token/line,
file/node and canonical-path tie breakers. Every accepted proposal strictly
improves its selected score; built-in source edits also decrease bytes.

`--jobs 1..64` controls native workers. The planner always issues batches of four
and commits completed results in candidate order, comparing scores before IDs.
Changing worker count therefore cannot change stable-predicate acceptance order.
No wall-clock determinism is promised for time-budget or genuinely flaky runs.

`--keep-workdir` retains candidate copies under the result's `.moonreduce/work`.
Without it, copies are removed after trials and on cancellation. Only owned copy
directories are cleaned. Commands can still access outside paths: this is not a
sandbox. Use fresh output directories outside INPUT, with an existing parent.
