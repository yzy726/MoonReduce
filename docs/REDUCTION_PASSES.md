# Reduction passes

| Name | Proposal |
|---|---|
| line-block | Delete contiguous line groups at descending widths |
| line | Delete one physical line, including its newline |
| blank-line | Delete a whitespace-only line |
| line-comment | Delete lexer-recognized `//` comments |
| block-comment | Delete nested `/* */` comments |
| doc-comment | Delete `///` comments |
| trim-edge | Remove a leading or trailing half of the line sequence |
| balanced | Delete an interior of correctly balanced brackets |
| token-range | Delete contiguous groups of significant tokens |
| token | Delete a single significant token |
| string | Replace a nonempty quoted string with an empty string |
| number | Replace a multi-character numeric token with `0` or `1` |

The engine also runs adaptive line ddmin before these registered passes.
Every candidate must decrease UTF-8 bytes and satisfy the external predicate.
Parsing success alone does not authorize acceptance. Strings/comments are opaque
to delimiter matching. The scanner tolerates unfinished text; unbalanced
structures produce no `balanced` proposals and still permit text/token deletion.

List the stable registry with `moon run cmd/main -- passes`.
