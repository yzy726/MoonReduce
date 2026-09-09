# Initial acceptance scope

The 2026-09-09 implementation follows the locally supplied goal.md initial
acceptance baseline: one target MoonBit file in an isolated project copy,
two baseline executions, twelve text/token passes, deterministic ddmin,
run-scoped caching, bounded execution, three uncached final checks and reports.

The engine is a pure step machine: callers request a candidate and return its
evaluation. The native adapter supplies filesystem, process and elapsed time.
This keeps the algorithm testable on native, JavaScript and wasm-gc without
introducing synchronous filesystem calls or a native dependency into the engine.

Work is committed in small verified local steps. Nothing is pushed to GitHub.
Remote CI, public package publication and clean remote installation are separate
acceptance evidence and are not inferred from successful local tests.
