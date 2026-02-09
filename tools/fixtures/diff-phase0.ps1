param(
  [string]$BaselinePath = "fixtures/baseline/phase0-legacy.csv",
  [string]$CurrentPath = "fixtures/current/phase0-legacy.csv"
)

if (-not (Test-Path -Path $BaselinePath -PathType Leaf)) {
  throw "Baseline file not found: $BaselinePath"
}
if (-not (Test-Path -Path $CurrentPath -PathType Leaf)) {
  throw "Current fixture file not found: $CurrentPath"
}

function Normalize-Lines {
  param([string[]]$Lines)
  return $Lines | ForEach-Object { $_.TrimEnd() }
}

$baseline = Normalize-Lines -Lines (Get-Content -Path $BaselinePath)
$current = Normalize-Lines -Lines (Get-Content -Path $CurrentPath)

$differences = Compare-Object -ReferenceObject $baseline -DifferenceObject $current -CaseSensitive
if ($null -eq $differences) {
  Write-Host "Fixture diff passed: files are identical."
  exit 0
}

Write-Host "Fixture diff failed between baseline and current output."
Write-Host "Showing first 60 differing lines:"
$differences | Select-Object -First 60 | ForEach-Object {
  Write-Host "$($_.SideIndicator) $($_.InputObject)"
}
exit 1
