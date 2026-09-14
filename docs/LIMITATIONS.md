# Known limitations

- Trusted commands only. Workspace copies are not a security sandbox; commands
  can access files and services outside the copy.
- Process cleanup targets identifiable descendants, with a 3000 ms cleanup
  allowance beyond the predicate timeout. It cannot promise containment against
  reparenting, privilege changes, PID reuse or deliberate escape. See
  PROCESS_VALIDATION.md for exact behavior and measured evidence.
- Native Windows and Ubuntu WSL have been tested. GitHub Actions was not run and
  no GitHub push is allowed. Hosted-platform evidence must not be inferred.
- No persistent cache, resume, concurrent candidates, multi-file reduction,
  full parser, regular expressions or flaky quorum support.
- Candidates require a strict UTF-8 byte decrease. Equal-byte simplifications are
  skipped. Token scanning is tolerant, not a language frontend.
- Limits: 64 KiB target, 1 MiB per file, 1000 files/16 MiB snapshot. Output must be
  new, outside the original, and have an existing parent. Permissions are
  approximated by executable/non-executable mode.
- Original comparison covers the captured regular-file manifest, not ignored
  build/cache directories or symlink targets.
- FNV-1a identifies content; it is not a cryptographic checksum. Cache correctness
  uses full candidate contents.
- Output capture is bounded and non-UTF8 process output is decoded lossily.
- Reports retain argv verbatim; never put secrets in command arguments.
- evaluations counts completed engine verdicts; attempted_commands additionally
  counts interrupted and failed-start attempts. Old schema-1 reports may omit
  attempted_commands and remain readable.
- Final-content determinism was measured for the compiler fixture. Raw event
  hashes include unnormalized process output and can vary with temporary paths.
