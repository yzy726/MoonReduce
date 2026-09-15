# Native execution security model

Run only trusted projects and trusted commands. The subprocess has the current
user's permissions. Copies provide reproducibility and original-file protection,
not operating-system containment. Commands use argv directly; no implicit shell.

Paths are normalized and validated before copying. Output must be a fresh sibling
or external directory. Traversal, absolute candidate paths, case collisions and
file/directory collisions are rejected. Candidate edits cannot inject new paths.
Symlinks are not followed when capturing input. Cleanup uses run ownership and
verified output roots. Protected files are checked for custom pass edits too.

Captured streams are bounded and extra output is drained. Timeout/cancellation
cleanup attempts to terminate identifiable descendants with a bounded allowance.
It does not contain deliberate reparenting, privilege changes or escape. Tests
use bounded owned helper processes, not antivirus exceptions or disabled controls.

Artifact verification checks ordinary file kinds, complete reduced-file inventory,
relative names, duplicate entries and SHA-256 before replay. Limits apply to
inventory and file sizes. Checksums detect accidental changes, not malicious
re-signing. Replay checks the bundle again after command execution. As with any
path-based API, hostile concurrent filesystem mutation is outside the trust model.

Reports omit environment values. A private checkpoint must preserve explicit
values for exact replay. Arguments remain verbatim. Supply credentials outside
argv and keep checkpoints private. Disk failures are surfaced; no successful
result is claimed when final verification or original preservation fails.
