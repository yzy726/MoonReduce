# Process validation status

2026-09-10 local Windows observations:

- Direct `moon version` invocation, bounded stdout and missing executable tests pass.
- Basic timeout and cancellation tests passed using a waiting process.
- A descendant-process regression demonstrated that the official hard-cancel
  handler terminates the direct child but does not guarantee descendant cleanup.
- A proposed tree-cleanup adapter remains unvalidated and is not shipped.
- The PowerShell descendant fixture intermittently failed to create its PID
  evidence. The cause is undetermined; no antivirus-block claim is made.
- After the user's Huorong warning, PowerShell/forced process-tree probes were
  suspended. No antivirus settings, exclusions or protections were changed.

The current implementation does not promise per-attempt descendant termination.
Use predicates that do not detach or spawn persistent descendants. Full process
tree validation is still required before initial acceptance can be declared.
Do not count the suspended tests toward the verified test total.
