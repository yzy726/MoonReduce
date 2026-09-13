# Design

The `model` package defines predicate observations, budgets and terminal status.
`source` owns portable path validation, strict UTF-8 decoding and byte edits.
`predicate/matcher` is pure and ANDs a failure class with normalized stream rules.

`passes/token` scans lossless UTF-16 spans in MoonBit Strings. Those offsets never
cross the `source` byte-edit API. Quoted strings, character literals, nested block
comments and multiline string lines are opaque to bracket matching. This is a
tolerant scanner, not a complete MoonBit parser; malformed input remains reducible.

`reducer/engine` is a request/verdict state machine. Its driver calls `next`,
executes the returned candidate, then calls `record`. Repeated `next` calls before
a verdict are idempotent. A successful candidate restarts coarse reduction.
Candidates must strictly decrease UTF-8 byte length. This is a conservative
subset of the proposed multi-component score: equal-byte simplifications are
not accepted by this initial implementation.

The scheduler starts with balanced ddmin line complements. Granularity grows
after rejection and decreases after acceptance. The twelve passes then run in
fixed order. Proposals retain edit spans and allocate each candidate on demand,
avoiding a quadratic queue of complete source copies. ddmin is not a guarantee
of global minimality for arbitrary non-monotone predicates.

Cache entries use complete candidate strings within one Session. Config, argv,
workspace snapshot and environment are fixed by the native driver for that
session. No persistence or cross-run cache is used. Full content comparison
prevents digest collision from affecting acceptance. FNV-1a hashes in reports
are deterministic identifiers, not cryptographic integrity checks.

`workspace/native` reads a bounded regular-file manifest, skips symlinks and
creates a fresh copy per command. It exports pristine support files rather than
compiler side effects. Cleanup verifies an issued directory, its realpath and
its owner marker; traversal does not follow symlinks. This is a trusted-command
boundary, not protection against a malicious concurrently modifying process.

`evaluator/process` launches direct argv, drains stdout/stderr concurrently and
caps retained bytes. `app` supplies elapsed time, events and artifacts. Process
tree termination is not yet verified; see PROCESS_VALIDATION.md.
