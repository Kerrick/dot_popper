# Checks a Windows build of Dot Popper on a computer with no Ruby on its
# PATH, without opening a window (CI runners have no GPU or audio): it
# unpacks the .zip, runs the program with DOT_POPPER_SMOKE (bin/dot_popper)
# and reads its report, then installs the setup program silently, runs
# the installed program the same way, and uninstalls it. Exits non-zero
# on any failed check.
#
#   pwsh -NoProfile -File script/smoke-windows.ps1 -Dist dist -Results smoke

param(
  [Parameter(Mandatory)] [string] $Dist,
  [Parameter(Mandatory)] [string] $Results
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Results | Out-Null
$Results = (Resolve-Path -LiteralPath $Results).Path
$failures = @()

function Check([string] $What, [bool] $Ok) {
  if ($Ok) { Write-Host "ok: $What" } else { Write-Host "FAILED: $What"; $script:failures += $What }
}

# Runs $Program in smoke mode, waits at most two minutes, and returns
# whether it exited 0 and reported everything present.
function Smoke([string] $Label, [string] $Program) {
  $report = Join-Path $Results "$Label.txt"
  $env:DOT_POPPER_SMOKE = $report
  $process = Start-Process -FilePath $Program -PassThru
  $null = $process.Handle # so ExitCode is kept once it exits
  if (-not $process.WaitForExit(120000)) {
    $process.Kill()
    Write-Host "$Label did not exit within two minutes"
    return $false
  }
  Write-Host "--- $Label exited $($process.ExitCode); its report:"
  if (-not (Test-Path -LiteralPath $report)) { Write-Host '(none)'; return $false }
  $text = Get-Content -LiteralPath $report -Raw
  Write-Host $text
  return ($process.ExitCode -eq 0 -and $text -match 'lota 0\.' -and $text -match 'status 0')
}

$zip = Get-ChildItem -LiteralPath $Dist -Filter '*.zip' | Select-Object -First 1
$setup = Get-ChildItem -LiteralPath $Dist -Filter '*-setup.exe' | Select-Object -First 1
Check 'the build wrote a .zip' ($null -ne $zip)
Check 'the build wrote a -setup.exe' ($null -ne $setup)
if ($failures) { exit 1 }

# Windows' own folders only, so a Ruby on the runner cannot help.
$system = $env:SystemRoot
$env:PATH = "$system\System32;$system;$system\System32\Wbem;$system\System32\WindowsPowerShell\v1.0"
Check 'no Ruby on PATH' ($null -eq (Get-Command ruby -ErrorAction SilentlyContinue))

$place = Join-Path $env:RUNNER_TEMP 'Dot Popper unpacked'
Expand-Archive -LiteralPath $zip.FullName -DestinationPath $place -Force
$unpacked = Get-ChildItem -LiteralPath $place -Recurse -Filter 'Dot Popper.exe' | Select-Object -First 1
Check 'the .zip holds Dot Popper.exe' ($null -ne $unpacked)
if ($unpacked) { Check 'the unpacked app starts and finds Lota and the game' (Smoke 'unpacked' $unpacked.FullName) }

$install = Start-Process -FilePath $setup.FullName -ArgumentList '/S' -Wait -PassThru
Check 'the setup program installs silently' ($install.ExitCode -eq 0)
$installed = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs') -Recurse -Filter 'Dot Popper.exe' -ErrorAction SilentlyContinue |
  Select-Object -First 1
Check 'the setup program installs Dot Popper.exe' ($null -ne $installed)
if ($installed) {
  Write-Host "installed at $($installed.FullName)"
  Check 'the installed app starts and finds Lota and the game' (Smoke 'installed' $installed.FullName)
  $shortcut = Get-ChildItem -LiteralPath ([Environment]::GetFolderPath('Programs')) -Recurse -Filter 'Dot Popper*.lnk' |
    Select-Object -First 1
  Check 'the setup program makes a Start menu shortcut' ($null -ne $shortcut)
  $uninstaller = Join-Path $installed.DirectoryName 'uninstall.exe'
  if (Test-Path -LiteralPath $uninstaller) {
    $uninstall = Start-Process -FilePath $uninstaller -ArgumentList '/S' -Wait -PassThru
    Write-Host "silent uninstall exit status: $($uninstall.ExitCode)"
    Start-Sleep -Seconds 5 # NSIS's uninstaller runs from a copy of itself and returns at once
    Write-Host "installed folder still there after uninstalling: $(Test-Path -LiteralPath $installed.DirectoryName)"
  } else {
    Write-Host "no uninstall.exe beside the installed program"
  }
}

if ($failures) { Write-Host "`n$($failures.Count) check(s) failed"; exit 1 }
Write-Host "`nevery check passed"
