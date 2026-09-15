# Report and evidence formats

Legacy single-file reports keep schema 1. Project reports and native project
NDJSON events use schema 2. The project bundle contains `reduced/`,
`original-summary.json`, `report.json`, `report.md`, `events.ndjson`,
`checkpoint.json`, `environment.json`, `checksums.txt`, `reduction.diff` and
`reproduce.txt`. Execution failures may additionally create `error.txt`.

Project reports include status/completed, scoring strategy and before/after score,
pass selection, worker count, repeat/quorum/final policy, rate/confidence summaries,
recorded evaluations, attempted commands, cache hits, elapsed time, original
preservation, per-file byte counts/FNV-1a/SHA-256 and baseline/final observations.
A differential trial counts both commands. Evidence streams are capped at 10000
native events. Timing includes process cleanup. Raw stdout/stderr are not embedded.

`completed` requires Completed status and the configured final threshold. Any
original change forces execution failure. `check` can exit zero after baseline
while completed remains false, since it did not certify a reduced candidate.
Unresolved observations are never cached as false. MoonBit Option JSON encoding
is used for optional verdicts: [] is absent, [true]/[false] is a resolved value.

`environment.json` schema 1 records toolchain and override names, never values.
The private checkpoint retains explicit values for recovery. Argument arrays
remain verbatim. Reproduction records argv and relative cwd, not shell quoting.
Checkpoint engine state also has a SHA-256 integrity field; legacy envelopes are
accepted for resume only when backed by a verified complete evidence bundle.

`checksums.txt` contains lowercase SHA-256, two spaces, and relative file path per
line. It covers every reduced regular file and emitted evidence file except
itself. Replay rejects missing, extra, duplicate, corrupt, linked or invalid paths
before execution and checks the source bundle again afterwards. This is integrity
checking, not authentication or an untrusted-command sandbox.

Unified diffs contain whole-file hunks with no-final-newline markers. They include
source, moon.pkg and opt-in moon.mod edits/deletions. Replay emits a separate
schema-1 replay.json with decision, trials, statistics and cache_used=false.
