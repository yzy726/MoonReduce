# Checkpoints and recovery

A native checkpoint envelope has schema_version 1, parser-compatible configuration,
MoonBit toolchain identity and engine state. Engine schema 4 (`project-v4`) stores
the original snapshot key, canonical predicate context, immutable candidate files,
selected paths/pass names, scoring and repeat policies, pass cursor, counters and
settled candidate cache. Earlier development schemas are rejected explicitly.

Snapshots currently use exact framed contents as cache identity. This avoids a
hash-collision correctness assumption but increases checkpoint size. The reader
rejects checkpoints above 256 MiB. SHA-256 in the evidence bundle checks on-disk
integrity; it does not authenticate the author.

`moonreduce resume FIRST/checkpoint.json --output SECOND --max-tests 2500`

SECOND must be fresh and outside the original input. Without --output a new temp
result is allocated. Jobs and larger budgets may change. Original bytes, selected
paths, policies, score, pass names, predicate, explicit environment and toolchain
must match. Unsupported or corrupted snapshots, injected paths and edits to
protected files are rejected. Custom library extensions must be supplied again;
the caller's context must identify their behavior/version.

Checkpoints are written at settled boundaries using an exclusive temporary file,
full sync and atomic rename. Pending work is not marked complete. An interrupted
batch may repeat pending candidates; settled cached candidates are skipped.
Final verification always executes again after resume.

Explicit environment values are retained here for replay. Checkpoints are private
local configuration, created with permission 0600 where supported. Environment
summaries and normal reports omit their values. Do not share secrets in argv or
checkpoints. Treat all replay commands as trusted input.

`cache stats --run RESULT` reports settled entry count and serialized bytes.
`cache clean --run RESULT` clears only the checkpoint cache and refreshes its
checksum, preserving the candidate and other state. No recursive deletion occurs.
A filesystem failure during the two-file update may leave a checksum mismatch;
verification fails closed rather than executing an inconsistent bundle.
