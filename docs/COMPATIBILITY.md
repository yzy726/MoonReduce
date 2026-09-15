# Compatibility

Pinned development toolchain: moonc 0.10.10+f8a486b6f, moon 0.1.20260824.
Native dependency: moonbitlang/async 0.20.4. Pure libraries support native,
JavaScript and wasm-gc. Process/filesystem/CLI packages require native.

Windows needs the native C toolchain configured for MoonBit. Linux needs a C
compiler. The tested toolchain names native outputs `main.exe` on both platforms;
on Linux this is an ELF executable. Use `moon run cmd/main -- ...` during local
development to avoid assuming output layout across future toolchain versions.

Tests exercise Unicode paths, CRLF, invalid UTF-8, portable separators and
case-collision rejection. Pattern matching is case sensitive on all platforms.
Executable/non-executable bits are preserved approximately; ACLs and extended
attributes are not copied. Case-only distinct files are intentionally rejected.

Replay/resume compare the recorded toolchain identity. A different installation
or compiler can require a new reduction instead of silently changing semantics.
Current Windows/Linux verification and installation evidence is recorded in the
final acceptance artifacts. Historical initial results are not final evidence.
