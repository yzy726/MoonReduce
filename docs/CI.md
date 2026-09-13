# Local and future CI checks

Run `./scripts/verify.ps1` in PowerShell from a checkout with the MoonBit native
toolchain, a C compiler, and project dependencies already installed.
It fails immediately on a failed gate and does not install software or access remotes.
The same script is used by the Windows/Linux workflow.

The workflow file is local preparation only. No upload or hosted job has run.
It uses the official MoonBit installers documented at
https://docs.moonbitlang.com/en/stable/tutorial/tour.html .
Hosted jobs resolve dependencies first and log exact toolchain versions. Installers
currently select their latest stable toolchain; this is compatibility CI, not proof
of a reproducible pinned release. The locally measured toolchain is in acceptance evidence.

Optional local hooks: `git config core.hooksPath .githooks`.
pre-commit checks whitespace, format and native types; commit-msg checks the subject.
Hooks never automatically stage or rewrite files. pre-push rejects every push,
including tags, for the user's local-only development instruction.
These hooks do not replace the full verification script or a security audit.
Suspended process-tree probes are not in the standard suite and must not be counted
as passing. Hosted CI will not establish the missing timeout/tree acceptance gate.
