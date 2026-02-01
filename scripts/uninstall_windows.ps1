# Optional: -DryRun = report what would be removed, no changes. Exit 0 = clean, 2 = artifacts present.
param([switch]$DryRun)

# Log path: ProgramData by default; $env:OPENCLAW_REMOVAL_LOG overrides
$Log = if ($env:OPENCLAW_REMOVAL_LOG) { $env:OPENCLAW_REMOVAL_LOG } else { "C:\ProgramData\OpenClawRemoval.log" }
$HostName = $env:COMPUTERNAME
$UserName = $env:USERNAME

# SIEM-friendly: one line per event, key=value, ts in UTC
function Write-SiemLog {
  param([string]$Event, [string]$Action = "", [string]$Result = "")
  $ts = (Get-Date).ToUniversalTime().ToString("o")
  $line = "ts=$ts host=$HostName user=$UserName event=$Event"
  if ($Action) { $line += " action=$Action" }
  if ($Result) { $line += " result=$Result" }
  Add-Content -Path $Log -Value $line -ErrorAction SilentlyContinue
}

Write-SiemLog -Event "start" -Action $(if ($DryRun) { "detect_only" } else { "uninstall" })

$Result = "success"
$WouldRemove = $false

# Detect: state dirs
$userHome = $env:USERPROFILE
$stateDirs = Get-ChildItem -Path $userHome -Filter ".openclaw*" -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
if ($stateDirs) { $WouldRemove = $true; foreach ($d in $stateDirs) { Write-SiemLog -Event "detect" -Action "state_dir=$($d.FullName)" } }

# Detect: scheduled tasks
try {
  $tasks = schtasks /Query /FO LIST /V 2>$null | Select-String -Pattern "OpenClaw|molt|claw"
  if ($tasks) { $WouldRemove = $true; Write-SiemLog -Event "dry_run" -Action "would_remove_scheduled_tasks" }
} catch {}

if ($DryRun) {
  Write-SiemLog -Event "complete" -Result $(if ($WouldRemove) { "would_remove" } else { "clean" })
  if ($WouldRemove) { exit 2 } else { exit 0 }
}

# Remove Scheduled Task (doc: "OpenClaw Gateway" and "OpenClaw Gateway (<profile>)")
try {
  schtasks /Query /TN "OpenClaw Gateway" *> $null
  Write-SiemLog -Event "manual" -Action "task_delete=OpenClaw Gateway"
  schtasks /Delete /F /TN "OpenClaw Gateway" | Out-Null
} catch {}

# Best-effort: delete any task whose name contains "OpenClaw Gateway" (root or profile variants)
try {
  $all = schtasks /Query /FO LIST /V 2>$null | Select-String "^TaskName:\s+(.+)$"
  foreach ($m in $all) {
    $tn = $m.Matches[0].Groups[1].Value.Trim()
    if ($tn -match "OpenClaw Gateway") {
      Write-SiemLog -Event "manual" -Action "task_delete=$tn"
      schtasks /Delete /F /TN $tn | Out-Null
    }
  }
} catch {}

# Remove gateway.cmd under default and profile state dirs (doc)
Get-ChildItem -Path $userHome -Filter ".openclaw*" -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.PSIsContainer } | ForEach-Object {
    $cmdPath = Join-Path $_.FullName "gateway.cmd"
    if (Test-Path $cmdPath) {
      Write-SiemLog -Event "manual" -Action "remove_gateway_cmd=$cmdPath"
      Remove-Item -Force $cmdPath
    }
    Write-SiemLog -Event "remove_state" -Action "path=$($_.FullName)"
    Remove-Item -Recurse -Force $_.FullName
  }

Write-SiemLog -Event "complete" -Result $Result

if ($Result -eq "success") { exit 0 }
if ($Result -eq "partial") { exit 1 }
exit 2
