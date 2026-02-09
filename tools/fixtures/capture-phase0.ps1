param(
  [string]$Port = "",
  [int]$BaudRate = 115200,
  [int]$TimeoutSeconds = 30,
  [string]$Tag = "phase0-legacy",
  [string]$OutputPath = "fixtures/current/phase0-legacy.csv"
)

$beginSentinel = "PHASE0_FIXTURE_BEGIN:$Tag"
$endSentinel = "PHASE0_FIXTURE_END:$Tag"

function Resolve-Port {
  param([string]$RequestedPort)
  if ($RequestedPort) {
    return $RequestedPort
  }

  $ports = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
  if ($ports.Count -eq 0) {
    throw "No serial ports detected. Pass -Port COMx explicitly."
  }
  if ($ports.Count -gt 1) {
    throw "Multiple serial ports detected ($($ports -join ', ')). Pass -Port COMx explicitly."
  }
  return $ports[0]
}

$resolvedPort = Resolve-Port -RequestedPort $Port
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$capturing = $false
$foundEnd = $false
$rows = New-Object System.Collections.Generic.List[string]

$serial = [System.IO.Ports.SerialPort]::new($resolvedPort, $BaudRate, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
$serial.NewLine = "`n"
$serial.ReadTimeout = 250
$serial.DtrEnable = $true
$serial.RtsEnable = $true

try {
  $serial.Open()
  Start-Sleep -Milliseconds 300
  $serial.DiscardInBuffer()

  while ((Get-Date) -lt $deadline) {
    $line = $null
    try {
      $line = $serial.ReadLine()
    } catch [System.TimeoutException] {
      continue
    }

    if ($null -eq $line) {
      continue
    }

    $line = $line.TrimEnd("`r", "`n")

    if (-not $capturing) {
      if ($line -eq $beginSentinel) {
        $capturing = $true
      }
      continue
    }

    if ($line -eq $endSentinel) {
      $foundEnd = $true
      break
    }

    if ($line.Length -gt 0) {
      $rows.Add($line)
    }
  }
} finally {
  if ($serial.IsOpen) {
    $serial.Close()
  }
  $serial.Dispose()
}

if (-not $capturing) {
  throw "Timed out waiting for begin sentinel: $beginSentinel"
}
if (-not $foundEnd) {
  throw "Timed out waiting for end sentinel: $endSentinel"
}
if ($rows.Count -eq 0) {
  throw "Fixture capture succeeded but no CSV rows were captured."
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Set-Content -Path $OutputPath -Value $rows -Encoding ascii
Write-Host "Captured $($rows.Count) fixture lines from $resolvedPort to $OutputPath"
