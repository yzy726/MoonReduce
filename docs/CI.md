# Automated verification

Run ./scripts/verify.ps1 in PowerShell with the MoonBit native toolchain, a C
compiler and resolved dependencies. It fails at the first failed gate, builds
the test probe and checks format, native types/tests, pure backends and CLI help.
It never pushes code or installs software.

.github/workflows/ci.yml contains the Windows/Linux hosted matrix. The user authorized GitHub push and hosted CI on 2026-09-15; the first hosted run failed because the latest formatter changed record trailing commas. The workflow now pins the locally verified toolchain; [run 34868084603](https://github.com/yzy726/MoonReduce/actions/runs/34868084603) passed on Windows and Linux at commit efca2d163d3ced8d793aae05a15802afd24abbd9. Local Windows and Ubuntu
WSL executions of the equivalent gates are recorded separately under
artifacts/acceptance/initial/platforms. Do not present these as GitHub Actions runs.

The workflow uses official installers documented at
https://docs.moonbitlang.com/en/stable/tutorial/tour.html .
The installers use MOONBIT_INSTALL_VERSION=0.10.10+f8a486b6f, matching the locally verified compiler. This version is the compiler release identifier, not the moon build-tool version. Upgrade it deliberately with formatting and interface review. Logs record actual versions.

Local hooks are enabled with git config core.hooksPath .githooks. pre-commit checks
whitespace, format and native types; commit-msg checks Conventional Commits.
pre-push runs scripts/verify.ps1 through pwsh and rejects pushes if verification fails. Hooks never stage/rewrite source and
do not replace full verification. The bounded MoonBit process probes are now part
of normal native verification; historical PowerShell probes remain excluded.
