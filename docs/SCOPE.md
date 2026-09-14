# Scope

MoonReduce reduces one UTF-8 `.mbt` target in a trusted local MoonBit project.
The native CLI has runtime evidence on Windows and Ubuntu WSL. The pure packages are tested on
JavaScript and wasm-gc as well as native.

Initial scope includes two baseline runs, a deterministic deletion scheduler,
twelve text/token passes, a run-scoped cache, budgets, cancellation, three final
checks, pristine copies and report artifacts. Multi-file reduction, full syntax
trees, flaky quorum rules, checkpoint/resume and parallel candidates are deferred.

This is an initial acceptance candidate, not a completed public release. Consult
artifacts/acceptance/initial/summary.md for evidence and unmet gates.
