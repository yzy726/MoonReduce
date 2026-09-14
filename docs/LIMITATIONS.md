# Known limitations

- Initial acceptance remains incomplete until all goal.md gates have evidence.
- Per-attempt descendant process cleanup is not guaranteed. PowerShell/process
  tree probes were suspended after a user warning about Huorong antivirus.
- No security sandbox: commands can access files or services outside their copy.
- Timeout, cancellation and cleanup depend on the native runtime and OS. A
  detached descendant can outlive its parent; avoid such predicates.
- Only Windows native runtime evidence is currently available. Remote CI and
  public package installation have not been performed. No GitHub push is allowed.
- No persistent cache, resume, concurrent candidates, multi-file reduction,
  full parser, regular-expression matching or flaky quorum support.
- Score requires a strict UTF-8 byte decrease; equal-byte simplifications are
  skipped. The scanner is tolerant and not a full language frontend.
- Target is limited to 64 KiB; one file to 1 MiB; snapshot to 1000 files/16 MiB.
  Output must be a new directory outside the original workspace, with an existing
  parent. Permissions are approximated by executable/non-executable mode.
- The unchanged-input comparison includes regular files in the captured manifest,
  not ignored build/cache directories or symlink targets.
- FNV-1a is a stable identifier, not a cryptographic checksum. Cache correctness
  relies on full candidate content, not the digest.
- Retained process output is bounded; malformed UTF-8 output is decoded lossily.
- Reports preserve command arguments verbatim; do not pass secrets in argv.
- Resource accounting still needs further fault tests:
  an interrupted
  command may not increment the recorded completed-evaluation counter.
