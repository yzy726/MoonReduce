# Process validation

The 2026-09-10 direct-child implementation did not reap all identifiable
descendants. Earlier PowerShell probes had unreliable readiness evidence and
were suspended after the user's Huorong warning. They remain excluded.

On 2026-09-14 a bounded MoonBit-only probe reproduced the defect: after parent
timeout, the descendant heartbeat continued from 11 to 15. The probe uses
spawn_orphan to avoid accidentally relying on its parent's async cleanup.
Every probe branch expires within ten seconds even if cleanup fails.

The adapter now uses the runtime-provided parent PID:
- Windows: direct argv taskkill.exe /PID <pid> /T /F.
- Unix: a ps PID/PPID snapshot, descendant traversal, leaf-first kill and root
  termination by the async runtime.
- Cleanup has a separate 3000 ms bound and direct-parent termination fallback.
  Cleanup time is included in measured duration and can extend the nominal
  predicate timeout.

Windows and Ubuntu tests cover descendant timeout/cancellation, direct execution,
bounded output, missing executables, original preservation, and artifact export
after cancellation. A missing heartbeat fails readiness instead of passing.
These tests do not change antivirus settings, exclusions, or protections, and do
not terminate unrelated processes by name.

This is best-effort identifiable-tree cleanup for trusted commands. It is not a
sandbox and does not guarantee containment against PID reuse, reparenting,
privilege changes or descendants that escape before enumeration. Unix child kill
exit codes are not separately certified; root reaping is owned by the runtime.
