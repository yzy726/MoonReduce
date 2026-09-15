param([string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../artifacts/acceptance/final'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($EvidenceDirectory)
function Require([bool]$Condition, [string]$Message) {
  if (!$Condition) { throw $Message }
}
function Read-Json([string]$Relative) {
  Get-Content -LiteralPath (Join-Path $root $Relative) -Raw | ConvertFrom-Json
}
function Median([object[]]$Values) {
  $sorted = @($Values | Sort-Object)
  Require ($sorted.Count -gt 0) 'Empty median input'
  $middle = [int][math]::Floor($sorted.Count / 2)
  if ($sorted.Count % 2) { return [double]$sorted[$middle] }
  return ([double]$sorted[$middle-1] + [double]$sorted[$middle]) / 2
}
$bench = @(Read-Json 'benchmarks.json')
Require ($bench.Count -eq 10) 'Expected ten benchmark fixtures'
Require (@($bench.fixture | Select-Object -Unique).Count -eq 10) 'Duplicate fixture'
$hashed = 0
foreach ($row in $bench) {
  Require ($row.fixture -match '^[a-z_]+$') 'Invalid fixture path'
  Require ($row.exit_code -eq 0 -and $row.replay_exit_code -eq 0 -and $row.original_unchanged -and $row.final_passed -ge 3) ('Reduction gate: '+$row.fixture)
  $replay = Read-Json ('replays/'+$row.fixture+'.json')
  Require ($replay.decision -eq 'Interesting' -and $replay.statistics.passed -ge 3 -and !$replay.cache_used -and $replay.original_unchanged) ('Replay gate: '+$row.fixture)
  $bundle = Join-Path $root ('benchmarks/'+$row.fixture)
  $seen = @{}
  foreach ($line in Get-Content -LiteralPath (Join-Path $bundle 'checksums.txt')) {
    Require ($line -match '^([0-9a-f]{64})  (.+)$') 'Invalid checksum line'
    $expected = $Matches[1]
    $relative = $Matches[2]
    $full = [IO.Path]::GetFullPath((Join-Path $bundle $relative))
    Require ($full.StartsWith($bundle+[IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Checksum path escapes bundle'
    Require (!$seen.ContainsKey($relative)) 'Duplicate checksum path'
    $seen[$relative] = $true
    Require ((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLower() -eq $expected) ('Checksum mismatch: '+$relative)
    $hashed++
  }
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $bundle 'reduced') -Recurse -File) {
    $relative = [IO.Path]::GetRelativePath($bundle,$file.FullName).Replace('\','/')
    Require ($seen.ContainsKey($relative)) ('Unsealed reduced file: '+$relative)
  }
  $summary = Get-Content -LiteralPath (Join-Path $bundle 'original-summary.json') -Raw | ConvertFrom-Json
  $fixtureRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('../testdata/final/'+$row.fixture+'/input')))
  foreach ($entry in $summary) {
    $full = [IO.Path]::GetFullPath((Join-Path $fixtureRoot $entry.path))
    Require ($full.StartsWith($fixtureRoot+[IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Original path escapes fixture'
    Require ((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLower() -eq $entry.sha256) ('Original fixture changed: '+$row.fixture+'/'+$entry.path)
  }
}
$deterministic = @($bench | Where-Object fixture -ne 'timeout')
Require ($deterministic.Count -eq 9) 'Expected nine non-timeout fixtures'
Require (@($deterministic | Where-Object reduction_percent -ge 50).Count -ge 8) 'Byte reduction threshold'
Require ((Median $deterministic.reduction_percent) -ge 70) 'Median byte reduction threshold'
Require ((Median $deterministic.token_reduction_percent) -ge 60) 'Median token reduction threshold'
Require (@($bench | Where-Object { $_.seconds -le 600 -and $_.evaluations -le 2500 }).Count -ge 9) 'Budget threshold'
$project = $bench | Where-Object fixture -eq 'multi_file_project'
Require ($project.reduction_percent -ge 60) 'Multi-file reduction threshold'
$runs = @(Read-Json 'determinism/runs.json')
Require ($runs.Count -eq 20) 'Expected twenty determinism runs'
foreach ($jobs in @(1,4)) {
  $group = @($runs | Where-Object jobs -eq $jobs)
  Require ($group.Count -eq 10) 'Expected ten runs per worker setting'
  Require (@($group.iteration | Select-Object -Unique).Count -eq 10) 'Duplicate determinism iteration'
}
Require (@($runs.tree_sha256 | Select-Object -Unique).Count -eq 1) 'Determinism hash mismatch'
Require (@($runs | Where-Object { $_.final_passed -lt 3 -or !$_.original_unchanged }).Count -eq 0) 'Determinism verification gate'
$coverage = @(Read-Json 'core-coverage.json')
$covered = ($coverage | Measure-Object covered_lines -Sum).Sum
$instrumented = ($coverage | Measure-Object instrumented_lines -Sum).Sum
Require ($instrumented -gt 0 -and 100*$covered/$instrumented -ge 85) 'Core coverage threshold'
$resume = Read-Json 'resume-verification.json'
Require ($resume.known_candidates_minimum -ge 20 -and $resume.repeat_percent -le 5 -and $resume.final_uncached_passes -ge 3) 'Resume threshold'
foreach ($platform in @('windows','linux')) {
  $log = Get-Content -LiteralPath (Join-Path $root ('platforms/'+$platform+'-verify.log')) -Raw
  Require ($log.Contains('Total tests: 492, passed: 492, failed: 0.')) ($platform+' native log gate')
  Require ([regex]::Matches($log,'Total tests: 435, passed: 435, failed: 0\.').Count -eq 2) ($platform+' portable log gate')
  $installed = Read-Json ('platforms/'+$platform+'-installed-replay.json')
  Require ($installed.decision -eq 'Interesting' -and $installed.statistics.passed -eq 3 -and !$installed.cache_used) ($platform+' installation replay gate')
}
Write-Output ('PASS: ten sealed bundles, '+$hashed+' SHA-256 entries, original fixture hashes, twenty deterministic runs, resume, coverage and local platform evidence.')
Write-Output ('Nine-fixture median byte reduction: '+[math]::Round((Median $deterministic.reduction_percent),2)+'%; core line coverage: '+[math]::Round(100*$covered/$instrumented,2)+'%.')
Write-Output 'This audits saved local evidence; it does not run tests, publish packages or certify remote CI.'