param([string[]]$Fixtures = @('compile_diagnostic','noisy_source','type_diagnostic','test_failure','assert_failure','array_failure','nonzero_exit','exit_code','timeout','multi_file_project'), [string]$RunName = ('run-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')))
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binary = Join-Path $repo '_build/native/release/build/cmd/main/main.exe'
$root = Join-Path $repo ('.moonreduce/final-benchmark/' + $RunName)
if (Test-Path -LiteralPath $root) { throw 'Choose a fresh RunName' }
New-Item -ItemType Directory -Force $root | Out-Null
$results = @()
foreach ($name in $Fixtures) {
  $fixture = Join-Path $repo ('testdata/final/' + $name)
  $inputPath = Join-Path $fixture 'input'
  $output = Join-Path $root $name
  $before = @(Get-ChildItem -LiteralPath $inputPath -Recurse -File | ForEach-Object { [pscustomobject]@{path=$_.FullName; hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
  $watch = [Diagnostics.Stopwatch]::StartNew()
  & $binary reduce --project --config (Join-Path $fixture 'predicate.json') --workspace $inputPath --output $output --quiet 2>&1 | Out-File (Join-Path $root ($name+'.log')) -Encoding utf8
  $code = $LASTEXITCODE
  $watch.Stop()
  $report = Get-Content (Join-Path $output 'report.json') -Raw | ConvertFrom-Json
  $unchanged = @($before | Where-Object { !(Test-Path -LiteralPath $_.path) -or (Get-FileHash -LiteralPath $_.path -Algorithm SHA256).Hash -ne $_.hash }).Count -eq 0
  $replay = Join-Path $root ($name+'-replay')
  & $binary replay (Join-Path $output 'report.json') --output $replay 2>&1 | Out-File (Join-Path $root ($name+'-replay.log')) -Encoding utf8
  $replayCode = $LASTEXITCODE
  $percent = 100 * (1 - $report.reduced_score.bytes / $report.original_score.bytes)
  $tokenPercent = 100 * (1 - $report.reduced_score.tokens / [math]::Max(1,$report.original_score.tokens))
  $row = [pscustomobject]@{fixture=$name;exit_code=$code;replay_exit_code=$replayCode;seconds=$watch.Elapsed.TotalSeconds;status=$report.status;original_bytes=$report.original_score.bytes;reduced_bytes=$report.reduced_score.bytes;reduction_percent=$percent;token_reduction_percent=$tokenPercent;evaluations=$report.evaluations;final_passed=$report.final_passed;original_unchanged=$unchanged;predicate_baseline_ms=@($report.evidence | Where-Object phase -eq 'baseline' | ForEach-Object duration_ms)}
  $results += $row
  $results | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $root 'benchmarks.json') -Encoding utf8
  Write-Output ($name + ': exit=' + $code + ' bytes=' + [math]::Round($percent,2) + '% commands=' + $report.evaluations + ' seconds=' + [math]::Round($watch.Elapsed.TotalSeconds,2) + ' replay=' + $replayCode)
}
Write-Output ('Evidence: ' + $root)
if (@($results | Where-Object { $_.exit_code -ne 0 -or $_.replay_exit_code -ne 0 -or !$_.original_unchanged -or $_.final_passed -lt 3 }).Count -gt 0) { throw 'One or more fixture gates failed; inspect saved evidence' }
