# Local release procedure

1. Run `scripts/verify.ps1`, clean coverage export, fixed benchmarks, determinism,
   interruption/resume and evidence replay gates.
2. Audit generated `.mbti`, schema versions, documentation and fixture licenses.
3. Build the native release CLI on Windows and Linux; copy it into a clean local
   install directory and run help plus a real fixture and replay.
4. Record toolchain, OS, hardware, SHA-256 and all exit statuses in final artifacts.
5. Update module version only after local gates pass.

Remote push, hosted CI dispatch, GitHub release and registry publication are
separate actions. The current user instruction authorizes local Git only; these
remote steps remain pending. Do not infer remote acceptance from local tests.
The project proposal is ignored local material and must never be force-added.
