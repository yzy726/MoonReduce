# Reduction-oriented MoonBit syntax

`moon_syntax.scan` produces UTF-8 byte spans, opaque strings/characters/comments,
tokens, balanced groups and diagnostics. Declaration and segment helpers identify
functions, tests, types, imports, comma lists and statement boundaries. Unicode
source edits use byte boundaries; string matching preserves surrogate pairs.

This is a lightweight reduction scanner, not the MoonBit compiler parser or a
semantic type checker. Unknown or malformed groups suppress structured proposals.
Text and token passes still run. A parseable candidate is never accepted solely
because it parses: the configured failure predicate remains mandatory.

Structured families (CLI prefix `struct:`):

| Pass | Recognized region / simplification |
| --- | --- |
| import | Complete top-level import group |
| function | Complete function declaration |
| type-declaration | Complete struct, enum, trait, impl or type declaration |
| test | Complete named test declaration |
| parameter | Function parameter/type-parameter comma segment |
| field | Struct or enum member segment |
| statement | Complete statement segment inside a balanced body |
| if-branch | Recognized conditional branch region |
| match-arm | Recognized match arm segment |
| loop-body | Balanced loop body |
| binding | Recognized local binding |
| expression | Replace a recognized expression region with a smaller literal |
| type-annotation | Remove a recognized annotation |
| metadata | Remove recognized attribute/doc metadata |
| identifier-literal | Simplify eligible identifiers or literals |
| format | Remove eligible whitespace, explicitly opt-in |

All edits must be in bounds, non-overlapping for the proposal, and strictly smaller
in UTF-8 bytes. Strings and comments cannot introduce false delimiters. Structural
recognition does not guarantee that every emitted edit preserves syntax; irrelevant
compiler errors are rejected by a sufficiently specific user predicate.

## Structural edit contracts

For every family the common fallback is no structured proposal on malformed
balanced groups, followed by the independent text/token registry. Candidate spans
are UTF-8 byte ranges, never string code-unit offsets.

- import/function/type-declaration/test remove a complete recognized top-level
  unit. This may leave missing names, instances or imports; the predicate rejects
  unrelated errors.
- parameter/field remove one complete comma segment. Call arity, generic argument
  counts and construction patterns may become invalid; no semantic repair is
  assumed.
- statement/if-branch/match-arm/loop-body remove a recognized body segment or
  branch. Exhaustiveness, required returns or scope can break.
- binding/expression/type-annotation replace one recognized expression/annotation
  span. Type inference, expression precedence or generic constraints may break.
- metadata/identifier-literal remove a metadata span or shorten one token. Labels,
  references and escape validity may change, so external validation is mandatory.
- format removes eligible whitespace only when explicitly enabled. Token merging
  may change syntax; strings/comments are opaque and the same predicate applies.
