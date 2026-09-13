# Contributing

Keep changes small, test new behavior first and reproduce bugs before fixing.
Prefer blackbox assertions and use whitebox tests only for internal invariants.
Do not pad implementation or tests to meet code-size targets.

Use ///| blocks, document public APIs and return expected business errors.
Run moon info, moon fmt, moon check --deny-warn and relevant tests before local
commit. Before delivery run docs/TESTING.md checks and inspect .mbti differences.

Use Conventional Commits on feature branches; merge locally after verification.
The user prohibits GitHub upload and push. Every fixture needs source/license
attribution, predicate, expected output and runnable instructions. Do not commit
builds, execution copies, caches or credentials.
