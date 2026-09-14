# Automated verification

Run ./scripts/verify.ps1 in PowerShell with the MoonBit native toolchain, a C
compiler and resolved dependencies. It fails at the first failed gate, builds
the test probe and checks format, native types/tests, pure backends and CLI help.
It never pushes code or installs software.

.github/workflows/ci.yml contains the Windows/Linux hosted matrix. The user authorized GitHub push and hosted CI on 2026-09-15; the first hosted run is pending. Local Windows and Ubuntu
WSL executions of the equivalent gates are recorded separately under
artifacts/acceptance/initial/platforms. Do not present these as GitHub Actions runs.

The workflow uses official installers documented at
https://docs.moonbitlang.com/en/stable/tutorial/tour.html .
They currently select stable toolchains, so this is compatibility CI rather than
a reproducible pinned release. Logs record the actual versions.

Local hooks are enabled with git config core.hooksPath .githooks. pre-commit checks
whitespace, format and native types; commit-msg checks Conventional Commits.
pre-push runs scripts/verify.ps1 through pwsh and rejects pushes if verification fails. Hooks never stage/rewrite source and
do not replace full verification. The bounded MoonBit process probes are now part
of normal native verification; historical PowerShell probes remain excluded.
