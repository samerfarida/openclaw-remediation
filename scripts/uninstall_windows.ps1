# Optional: -DryRun = report what would be removed, no changes. Exit 0 = clean, 2 = artifacts present.
param([switch]$DryRun)

# Log path: ProgramData by default; $env:OPENCLAW_REMOVAL_LOG overrides
$Log = if ($env:OPENCLAW_REMOVAL_LOG) { $env:OPENCLAW_REMOVAL_LOG } else { "C:\ProgramData\OpenClawRemoval.log" }
$HostName = $env:COMPUTERNAME
$UserName = $env:USERNAME

# OS and arch for SIEM (enterprise context)
$OsName = "Windows"
$OsVersion = "unknown"
$OsArch = $env:PROCESSOR_ARCHITECTURE
try {
  $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
  if ($os) {
    $OsVersion = $os.Version
    if ($os.OSArchitecture) { $OsArch = $os.OSArchitecture }
  }
} catch {}

# Script version for SIEM (from repo VERSION file when present)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$versionFile = Join-Path (Split-Path -Parent $scriptDir) "VERSION"
$ScriptVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim() } else { "unknown" }

# SIEM-friendly: one line per event, key=value, ts in UTC; quote values with space or = for parsing
function SiemQuote([string]$v) {
  if ($v -match '[\s=]') { return '"{0}"' -f ($v -replace '"', '\"') }
  return $v
}
function Write-SiemLog {
  param([string]$Event, [string]$Action = "", [string]$Result = "", [string]$Severity = "info")
  $ts = (Get-Date).ToUniversalTime().ToString("o")
  $line = "ts=$ts host=$(SiemQuote $HostName) user=$(SiemQuote $UserName) os=$OsName os_version=$(SiemQuote $OsVersion) os_arch=$(SiemQuote $OsArch) event=$Event script=openclaw_remediation version=$ScriptVersion"
  if ($Action) { $line += " action=$(SiemQuote $Action)" }
  if ($Result) { $line += " result=$(SiemQuote $Result)" }
  $line += " severity=$Severity"
  Add-Content -Path $Log -Value $line -ErrorAction SilentlyContinue
}

Write-SiemLog -Event "start" -Action $(if ($DryRun) { "detect_only" } else { "uninstall" })
[Console]::Error.WriteLine("openclaw-remediation: logging to $Log")

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

# Detect: global CLI (npm/pnpm/bun) and common Windows install paths (per docs/compatibility)
$npmGlobal = $false
try {
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    $out = npm list -g openclaw --depth=0 2>$null
    if ($out -match "openclaw@") { $npmGlobal = $true }
  }
} catch {}
if (-not $npmGlobal -and (Test-Path -LiteralPath "$env:APPDATA\npm\openclaw.cmd" -ErrorAction SilentlyContinue)) { $npmGlobal = $true }
if ($npmGlobal) { $WouldRemove = $true; Write-SiemLog -Event "detect" -Action "cli_npm_global" }

try {
  if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    $out = pnpm list -g openclaw 2>$null
    if ($out -match "openclaw") { $WouldRemove = $true; Write-SiemLog -Event "detect" -Action "cli_pnpm_global" }
  }
} catch {}
try {
  if (Get-Command bun -ErrorAction SilentlyContinue) {
    $out = bun pm ls -g 2>$null
    if ($out -match "openclaw") { $WouldRemove = $true; Write-SiemLog -Event "detect" -Action "cli_bun_global" }
  }
} catch {}

# Detect: common Windows install dirs (standalone or installer layout)
$localPaths = @(
  (Join-Path $env:LOCALAPPDATA "openclaw"),
  (Join-Path $env:LOCALAPPDATA "OpenClaw"),
  (Join-Path $env:LOCALAPPDATA "Programs\openclaw"),
  (Join-Path $env:LOCALAPPDATA "Programs\OpenClaw")
)
foreach ($p in $localPaths) {
  if (Test-Path -LiteralPath $p -ErrorAction SilentlyContinue) {
    $WouldRemove = $true
    Write-SiemLog -Event "detect" -Action "install_path=$p"
  }
}

if ($DryRun) {
  [Console]::Error.WriteLine("openclaw-remediation: dry-run (detect only), no removal")
  $dryResult = if ($WouldRemove) { "would_remove" } else { "clean" }
  $drySev = if ($WouldRemove) { "warning" } else { "info" }
  Write-SiemLog -Event "complete" -Result $dryResult -Severity $drySev
  if ($WouldRemove) { exit 2 } else { exit 0 }
}

# Already clean: skip removal when nothing is present
if (-not $WouldRemove) {
  Write-SiemLog -Event "complete" -Action "already_clean" -Result "" -Severity "info"
  [Console]::Error.WriteLine("openclaw-remediation: result=success (already clean, nothing to remove)")
  exit 0
}

# Remove Scheduled Task (doc: "OpenClaw Gateway" and "OpenClaw Gateway (<profile>)")
# Redirect stderr so "The system cannot find the file specified" doesn't appear when task is missing
try {
  $null = schtasks /Query /TN "OpenClaw Gateway" 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-SiemLog -Event "manual" -Action "task_delete=OpenClaw Gateway"
    schtasks /Delete /F /TN "OpenClaw Gateway" 2>$null | Out-Null
  }
} catch {}

# Best-effort: delete any task whose name contains "OpenClaw Gateway" (root or profile variants)
try {
  $all = schtasks /Query /FO LIST /V 2>$null | Select-String "^TaskName:\s+(.+)$"
  foreach ($m in $all) {
    $tn = $m.Matches[0].Groups[1].Value.Trim()
    if ($tn -match "OpenClaw Gateway") {
      Write-SiemLog -Event "manual" -Action "task_delete=$tn"
      schtasks /Delete /F /TN $tn 2>$null | Out-Null
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

# Remove global CLI (npm/pnpm/bun) per docs/compatibility
try {
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-SiemLog -Event "cli_remove" -Action "npm_uninstall_global"
    npm uninstall -g openclaw 2>$null | Out-Null
  }
} catch {}
try {
  if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    Write-SiemLog -Event "cli_remove" -Action "pnpm_remove_global"
    pnpm remove -g openclaw 2>$null | Out-Null
  }
} catch {}
try {
  if (Get-Command bun -ErrorAction SilentlyContinue) {
    Write-SiemLog -Event "cli_remove" -Action "bun_remove_global"
    bun remove -g openclaw 2>$null | Out-Null
  }
} catch {}
# Best-effort: remove CLI shims from %APPDATA%\npm if still present
$npmBin = Join-Path $env:APPDATA "npm"
foreach ($name in @("openclaw.cmd", "openclaw", "openclaw.ps1")) {
  $fp = Join-Path $npmBin $name
  if (Test-Path -LiteralPath $fp -ErrorAction SilentlyContinue) {
    Write-SiemLog -Event "manual" -Action "remove_npm_shim=$fp"
    Remove-Item -Force $fp -ErrorAction SilentlyContinue
  }
}

# Remove common Windows install dirs (standalone layout)
foreach ($p in $localPaths) {
  if (Test-Path -LiteralPath $p -ErrorAction SilentlyContinue) {
    Write-SiemLog -Event "remove_state" -Action "path=$p"
    Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue
  }
}

$sev = if ($Result -eq "success") { "info" } elseif ($Result -eq "partial") { "warning" } else { "error" }
Write-SiemLog -Event "complete" -Result $Result -Severity $sev
[Console]::Error.WriteLine("openclaw-remediation: result=$Result (see $Log)")

if ($Result -eq "success") { exit 0 }
if ($Result -eq "partial") { exit 1 }
exit 2
