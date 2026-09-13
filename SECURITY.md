# Security policy

MoonReduce executes user-selected commands with the user's privileges. It is
not a sandbox. Only use trusted commands/projects; copies cannot prevent absolute
path writes, credential access, network access or detached child processes.

Commands use direct argv. Source is strict UTF-8. Targets/cwd are validated,
symlinks are omitted from snapshots, and output is new and outside the input tree.
Cleanup checks issued directories, real paths and owner markers. It does not
defend against malicious concurrent filesystem mutation.

Input and captured output have bounds. Environment override values are omitted
from reports. Command arguments are preserved verbatim: never place secrets there.
FNV identifiers are not security hashes.

Open issue: per-attempt descendant termination is not guaranteed. Antivirus
protections must not be disabled or broadly excluded to make tests pass.
Record blocked behavior rather than assuming its cause.

No private reporting endpoint is configured for this local project. Report
concerns privately to the owner with minimal non-sensitive reproduction details.
