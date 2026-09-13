$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
  moon version --all
  if ($LASTEXITCODE -ne 0) { throw 'Toolchain unavailable' }
  moon info --target native
  if ($LASTEXITCODE -ne 0) { throw 'Interface generation failed' }
  moon fmt --check
  if ($LASTEXITCODE -ne 0) { throw 'Formatting failed' }
  moon check --target native --warn-list +73 --deny-warn
  if ($LASTEXITCODE -ne 0) { throw 'Native check failed' }
  moon test --target native --deny-warn
  if ($LASTEXITCODE -ne 0) { throw 'Native tests failed' }
  moon test --target js --deny-warn
  if ($LASTEXITCODE -ne 0) { throw 'JS tests failed' }
  moon test --target wasm-gc --deny-warn
  if ($LASTEXITCODE -ne 0) { throw 'wasm-gc tests failed' }
  moon run cmd/main -- --help
  if ($LASTEXITCODE -ne 0) { throw 'CLI smoke failed' }
  git diff --exit-code -- '*.mbti'
  if ($LASTEXITCODE -ne 0) { throw 'Public interfaces changed; review and commit them' }
} finally {
  Pop-Location
}
