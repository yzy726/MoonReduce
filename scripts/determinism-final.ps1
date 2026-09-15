param([string]$RunName = ('det-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')))
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binary = Join-Path $repo '_build/native/release/build/cmd/main/main.exe'
$root = Join-Path $repo ('.moonreduce/' + $RunName)
if (Test-Path -LiteralPath $root) { throw 'Choose a fresh RunName' }
New-Item -ItemType Directory -Force $root | Out-Null
$fixture = Join-Path $repo 'testdata/final/multi_file_project'
$rows = @()
foreach ($jobs in @(1,4)) {
  foreach ($iteration in 1..10) {
    $name = 'jobs-' + $jobs + '-run-' + $iteration
    $out = Join-Path $root $name
    & $binary reduce --project --config (Join-Path $fixture 'predicate.json') --workspace (Join-Path $fixture 'input') --output $out --jobs $jobs --quiet 2>&1 | Out-File (Join-Path $root ($name+'.log')) -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw ('Reduction failed: '+$name) }
    $report = Get-Content (Join-Path $out 'report.json') -Raw | ConvertFrom-Json
    $identity = (@($report.reduced_files | ForEach-Object { $_.path + ':' + $_.sha256 }) -join "`n")
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identity))).ToLowerInvariant()
    $rows += [pscustomobject]@{jobs=$jobs;iteration=$iteration;tree_sha256=$hash;evaluations=$report.evaluations;cache_hits=$report.cache_hits;final_passed=$report.final_passed;original_unchanged=$report.original_unchanged}
    $rows | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $root 'determinism.json') -Encoding utf8
    Write-Output ($name+': '+$hash)
  }
}
if (@($rows.tree_sha256 | Select-Object -Unique).Count -ne 1) { throw 'Non-deterministic reduced tree' }
if (@($rows | Where-Object { $_.final_passed -ne 3 -or !$_.original_unchanged }).Count) { throw 'Final validation or preservation failed' }
Write-Output ('PASS: all 20 runs agree. Evidence: '+$root)
