# Known limitations

- Trusted commands only. Copies do not restrict filesystem/network access or
  contain deliberate process escape. Identifiable descendants are cleaned with a
  bounded allowance; hostile reparenting and privilege changes are outside scope.
- Syntax scanning is reduction-oriented, not a full parser or type checker.
  Malformed structures skip structured edits and permit text/token fallback.
- Built-in source proposals decrease bytes. Equal-byte rewrites are skipped;
  scoring strategies are lexicographic bytes/tokens/lines, not arbitrary weights.
- Regex is a bounded Thompson-NFA subset; unsupported constructs are rejected.
  Exhausted matching budgets are inconclusive, never cached negatives.
- Candidate cache identity currently stores exact framed contents. Large runs may
  have large checkpoints; resume rejects files above 256 MiB. SHA-256 seals disk
  evidence but is not an authenticity signature.
- Parallel content determinism applies to stable predicates without a binding
  wall-time stop. Timings, temporary paths and flaky outcomes need not agree.
- Snapshot limits: 1000 regular files/16 MiB, 1 MiB per file, 64 KiB per source.
  ACLs, symlink targets and ignored build/cache directories are not preserved or
  included in original-manifest comparison.
- Replay requires a matching toolchain identity and at least one source file in
  the reduced project. Command arguments and private checkpoint environment values
  require care when sharing evidence.
- Interrupted pending batches may repeat unfinished work. Settled cache entries
  are reused; final trials intentionally execute again.
- Native events are bounded. Process streams decode invalid UTF-8 lossily and mark
  truncation. The scanner rejects invalid UTF-8 source rather than replacing it.
