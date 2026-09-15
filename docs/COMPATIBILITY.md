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

Final local installation was tested from source on Windows 11 and Ubuntu under
WSL2, using the same compiler version. `moon install ./cmd/main --bin DEST`
installs `main.exe` on Windows and `main` on Linux; invoke that installed file or
rename it to `moonreduce` for your PATH. Both installed binaries reduced a real
compiler failure and replayed the result with three fresh successful trials.

Linux verification used a clean Git archive on its native filesystem and an
isolated SDK. The async 0.20.4 registry index/archive came from the existing local
cache because registry network access was unavailable. This demonstrates a clean
source build with cached dependencies, not an online registry installation.
Keep the SDK and timing-sensitive tests on the Linux filesystem: the earlier
Windows-mounted filesystem run failed one real compiler test under its deadline.