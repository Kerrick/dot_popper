# Dot Popper's Windows playtest (PACKAGING.md, "Playtest kits").
#
# Right-click this file and choose "Run with PowerShell". It records a few
# facts about this computer, starts Dot Popper with DOT_POPPER_PERF=1 (it
# then prints how smoothly it runs), asks the hand checks one at a time
# while you play, collects the game's saved files from %APPDATA%\dot_popper,
# and writes everything into one file, dot-popper-results.txt, beside this
# script. It changes no setting, needs no administrator, and writes only
# that file (keeping an earlier one under another name), besides the save
# folder the game itself writes.
#
# script/playtest_kit.rb writes this file from playtest/playtest.ps1 and
# playtest/checks.yml, which holds the checks' words. It must run in
# Windows PowerShell 5.1 and in PowerShell 7, so it uses nothing newer than
# 5.1 has, and it is ASCII, since 5.1 reads a file without a byte order
# mark as ANSI.
#
# For CI only: answers may come on redirected standard input, one line
# each, and -NoPause skips the last "Press Enter".

[CmdletBinding()]
param([switch] $NoPause)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$KitBuild = @'
@BUILD@
'@

# @CHECKS@

$Kit = $PSScriptRoot
if (-not $Kit) { $Kit = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ResultsPath = Join-Path $Kit 'dot-popper-results.txt'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Lines = New-Object System.Collections.Generic.List[string]
$Sessions = New-Object System.Collections.ArrayList
$script:Game = $null
$script:InputEnded = $false
$Started = Get-Date

# ---------------------------------------------------------------- results

function Get-Stamp { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz') }

# The results file is written again after every line, so that whatever
# happens, what was recorded so far is in it.
function Save-Results { [IO.File]::WriteAllLines($ResultsPath, $Lines.ToArray(), $Utf8) }

function Add-Line([string] $Text) {
  foreach ($line in ($Text -split "`r?`n")) { $Lines.Add($line) }
  Save-Results
}

function Add-Heading([string] $Text) {
  $Lines.Add('')
  $Lines.Add("== $Text")
  Save-Results
}

# Runs one fact-finding step; a failure is written down and skipped.
function Add-Fact([string] $Label, [scriptblock] $Body) {
  try { & $Body } catch { Add-Line "${Label}: could not read it ($($_.Exception.Message))" }
}

function Say([string] $Text) { Write-Host $Text }

# ------------------------------------------------------------------ input

# One line the player types, or $null once redirected input has ended.
# Input redirected from a file (CI) is read line by line and echoed.
function Read-Answer([string] $Prompt) {
  if ($script:InputEnded) { return $null }
  if ([Console]::IsInputRedirected) {
    Write-Host -NoNewline "$Prompt "
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) { $script:InputEnded = $true; Write-Host '(no more input)'; return $null }
    Write-Host $line
    return $line
  }
  return (Read-Host $Prompt)
}

# Asks until the answer is one of the forms $Accept turns into a value,
# three times at most; then keeps what was typed.
function Read-Choice([string] $Prompt, [scriptblock] $Accept) {
  for ($try = 0; $try -lt 3; $try++) {
    $typed = Read-Answer $Prompt
    if ($null -eq $typed) { return 'not answered' }
    $value = & $Accept ($typed.Trim().ToLowerInvariant())
    if ($value) { return $value }
    Say '  Sorry, I did not understand that. Please try again.'
  }
  return "unclear: $typed"
}

function Read-YesNo([string] $Prompt, [switch] $NotShown) {
  Read-Choice $Prompt {
    param($a)
    if ($a -match '^(y|yes)$') { return 'yes' }
    if ($a -match '^(n|no)$') { return 'no' }
    if ($a -match '^(s|skip)?$') { return 'skipped' }
    if ($NotShown -and $a -match '^(ns|not shown)$') { return 'not shown' }
    return $null
  }
}

function Read-Rating([string] $Prompt) {
  Read-Choice $Prompt {
    param($a)
    if ($a -match '^[1-5]$') { return $a }
    if ($a -match '^(s|skip)?$') { return 'skipped' }
    return $null
  }
}

function Read-Option([string] $Prompt, $Options) {
  Read-Choice $Prompt {
    param($a)
    if ($a -match '^(s|skip)?$') { return 'skipped' }
    for ($i = 0; $i -lt $Options.Count; $i++) {
      if ($a -eq "$($i + 1)" -or $a -eq $Options[$i].ToLowerInvariant()) { return $Options[$i] }
    }
    return $null
  }
}

# Lines typed or pasted until an empty one.
function Read-Lines([string] $Prompt) {
  Say $Prompt
  $typed = New-Object System.Collections.ArrayList
  for ($i = 0; $i -lt 40; $i++) {
    $line = Read-Answer '  >'
    if ($null -eq $line -or -not $line.Trim()) { break }
    [void]$typed.Add($line)
  }
  return ,$typed.ToArray()
}

# ------------------------------------------------------------- the game

# Starts Dot Popper with DOT_POPPER_PERF=1, its output read as it comes,
# so that it never waits on a full pipe.
function Start-Game([string] $Why) {
  $info = New-Object System.Diagnostics.ProcessStartInfo
  $info.FileName = $GameExe
  $info.WorkingDirectory = Split-Path -Parent $GameExe
  $info.UseShellExecute = $false
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $info.StandardOutputEncoding = $Utf8
  $info.StandardErrorEncoding = $Utf8
  $info.EnvironmentVariables['DOT_POPPER_PERF'] = '1'
  $process = [System.Diagnostics.Process]::Start($info)
  $session = [pscustomobject]@{
    Number = $Sessions.Count + 1; Why = $Why; Started = Get-Stamp; Process = $process
    Out = $process.StandardOutput.ReadToEndAsync(); Err = $process.StandardError.ReadToEndAsync()
  }
  [void]$Sessions.Add($session)
  $script:Game = $session
  Add-Line "Dot Popper started ($Why) at $($session.Started), session $($session.Number)"
}

# Closes the game and anything it started, as Task Manager's "End task"
# would.
function Stop-Game($Process) {
  try { & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $Process.Id /T /F 2>&1 | Out-Null } catch { }
  try { if (-not $Process.HasExited) { $Process.Kill() } } catch { }
  [void]$Process.WaitForExit(10000)
}

function Test-GameRunning { return ($null -ne $script:Game -and -not $script:Game.Process.HasExited) }

# Starts the game again if it has closed by itself since the last check.
function Confirm-GameRunning([string] $Before) {
  if (Test-GameRunning) { return }
  $code = 'unknown'
  if ($script:Game) { $code = $script:Game.Process.ExitCode }
  Add-Line "Dot Popper had closed before $Before (exit code $code); the kit started it again."
  Say ''
  Say 'Dot Popper had closed, so I am starting it again.'
  Start-Game "again, before $Before"
}

# Waits for the player to quit the game. Enter, typed here, closes it.
function Wait-GameExit([string] $Why) {
  if (-not (Test-GameRunning)) { return }
  Say "  Waiting for Dot Popper to close. If it is stuck, press Enter here and I will close it."
  $process = $script:Game.Process
  while (-not $process.WaitForExit(500)) {
    if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) {
      $key = [Console]::ReadKey($true)
      if ($key.Key -eq 'Enter') {
        Add-Line "The kit closed Dot Popper ($Why), when asked to."
        Stop-Game $process
        break
      }
    }
  }
}

# ----------------------------------------------------------------- checks

function Ask-Part($Check, $Part, [string] $Label) {
  switch ($Part.Answer) {
    'yes_no' { $value = Read-YesNo '  y / n / skip:' }
    'yes_no_not_shown' { $value = Read-YesNo '  y / n / ns (not shown) / skip:' -NotShown }
    'rating' {
      Say "  $($Part.Scale)"
      $value = Read-Rating '  1 to 5 / skip:'
    }
    'choice' {
      for ($i = 0; $i -lt $Part.Options.Count; $i++) { Say "  $($i + 1). $($Part.Options[$i])" }
      $value = Read-Option '  number / skip:' $Part.Options
    }
    'paste' {
      $value = Read-YesNo '  y / n / skip:'
      $pasted = Read-Lines '  Now paste the result here (right-click, or Ctrl+V), then press Enter on an empty line:'
      Add-Line "    ${Label}: $value"
      Add-Line '    pasted:'
      foreach ($line in $pasted) { Add-Line "      $line" }
      return
    }
    default {
      $typed = Read-Lines '  Type your answer, then press Enter on an empty line:'
      $value = ($typed -join ' / ')
      if (-not $value) { $value = '(nothing)' }
    }
  }
  Add-Line "    ${Label}: $value"
}

function Ask-Check($Check) {
  Confirm-GameRunning "check $($Check.Id)"
  Say ''
  Say "---- Check $($Check.Id) of $LastId ----"
  if ($Check.Try) { Say "Try this: $($Check.Try)" }
  if ($Check.Restart) {
    Wait-GameExit "for check $($Check.Id)"
    Start-Game "again, for check $($Check.Id)"
    Say '  Dot Popper is starting again.'
  }
  Say $Check.Ask
  Add-Line ''
  Add-Line "[$($Check.Id)] $($Check.Ask)"
  if ($Check.Answer) { Ask-Part $Check $Check 'answer' }
  foreach ($part in $Check.Parts) {
    Say "  $($part.Ask)"
    Ask-Part $Check $part $part.Ask.TrimEnd(':')
  }
  $note = Read-Answer '  Note (optional, Enter for none):'
  if ($note -and $note.Trim()) { Add-Line "    note: $($note.Trim())" }
  if ($Check.After) { Say "  $($Check.After)" }
}

# ------------------------------------------------------------ this computer

function Add-Displays {
  Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DotPopperKit {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct MONITORINFOEX {
    public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szDevice;
  }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public int dmFields;
    public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
    public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels; public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
    public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
  }
  [StructLayout(LayoutKind.Sequential)] public struct XINPUT_STATE {
    public uint dwPacketNumber; public ushort wButtons; public byte bLeftTrigger, bRightTrigger;
    public short sThumbLX, sThumbLY, sThumbRX, sThumbRY;
  }
  public delegate bool MonitorProc(IntPtr monitor, IntPtr dc, ref RECT rect, IntPtr data);
  [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorProc proc, IntPtr data);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFOEX info);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool EnumDisplaySettings(string device, int mode, ref DEVMODE devMode);
  [DllImport("shcore.dll")] static extern int GetDpiForMonitor(IntPtr monitor, int type, out uint x, out uint y);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("xinput1_4.dll")] static extern int XInputGetState(int index, out XINPUT_STATE state);

  public static List<string> Displays() {
    List<string> lines = new List<string>();
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, delegate (IntPtr monitor, IntPtr dc, ref RECT rect, IntPtr data) {
      MONITORINFOEX info = new MONITORINFOEX();
      info.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));
      GetMonitorInfo(monitor, ref info);
      DEVMODE mode = new DEVMODE();
      mode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
      string refresh = EnumDisplaySettings(info.szDevice, -1, ref mode) ? mode.dmDisplayFrequency + " Hz" : "refresh rate unknown";
      uint x, y;
      string scale = GetDpiForMonitor(monitor, 0, out x, out y) == 0 ? (x * 100 / 96) + "% (" + x + " dpi)" : "scale unknown";
      RECT r = info.rcMonitor;
      lines.Add(info.szDevice + ": " + (r.Right - r.Left) + "x" + (r.Bottom - r.Top) + " pixels at " + r.Left + "," + r.Top +
        ", " + refresh + ", display scale " + scale + ((info.dwFlags & 1) == 1 ? ", main display" : ""));
      return true;
    }, IntPtr.Zero);
    return lines;
  }

  public static List<string> XInput() {
    List<string> lines = new List<string>();
    for (int i = 0; i < 4; i++) {
      XINPUT_STATE state;
      if (XInputGetState(i, out state) == 0) lines.Add("XInput controller in slot " + (i + 1));
    }
    return lines;
  }
}
'@
  # Pixels and scale come out true only in a process aware of each
  # display's scale (-4 is per-monitor v2).
  try { [void][DotPopperKit]::SetProcessDpiAwarenessContext([IntPtr](-4)) } catch { }
}

function Add-ComputerFacts {
  Add-Heading 'This computer'
  Add-Fact 'windows' {
    $os = Get-CimInstance Win32_OperatingSystem
    $version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    Add-Line "windows: $($os.Caption) $($version.DisplayVersion), build $($version.CurrentBuild).$($version.UBR) ($($os.OSArchitecture))"
  }
  Add-Fact 'computer' {
    $computer = Get-CimInstance Win32_ComputerSystem
    Add-Line "computer: $($computer.Manufacturer) $($computer.Model), $([Math]::Round($computer.TotalPhysicalMemory / 1GB, 1)) GB of memory"
    foreach ($cpu in @(Get-CimInstance Win32_Processor)) { Add-Line "processor: $($cpu.Name.Trim()), $($cpu.NumberOfLogicalProcessors) threads" }
  }
  Add-Fact 'graphics' {
    foreach ($gpu in @(Get-CimInstance Win32_VideoController)) {
      $date = ''
      if ($gpu.DriverDate) { $date = " of $($gpu.DriverDate.ToString('yyyy-MM-dd'))" }
      Add-Line "graphics: $($gpu.Name), driver $($gpu.DriverVersion)$date, $($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution) at $($gpu.CurrentRefreshRate) Hz"
    }
  }
  Add-Fact 'displays' {
    Add-Displays
    foreach ($line in [DotPopperKit]::Displays()) { Add-Line "display $line" }
  }
  Add-Fact 'sound' {
    foreach ($sound in @(Get-CimInstance Win32_SoundDevice)) { Add-Line "sound device: $($sound.Name) ($($sound.Status))" }
  }
  Add-Fact 'controllers' {
    $found = 0
    try { foreach ($line in [DotPopperKit]::XInput()) { Add-Line "controller: $line"; $found++ } } catch { }
    $pads = @(Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.PNPClass -in 'XnaComposite', 'XboxComposite' -or ($_.PNPClass -in 'HIDClass', 'USB', 'Bluetooth' -and
          "$($_.Name)" -match 'game|xbox|joystick|gamepad|dualsense|dualshock|wireless controller|pro controller|8bitdo' -and
          "$($_.Name)" -notmatch 'host controller|root hub')
      })
    foreach ($pad in $pads) { Add-Line "controller: $($pad.Name) [$($pad.PNPClass)], $($pad.Status)"; $found++ }
    if (-not $found) { Add-Line 'controllers: none found' }
  }
  Add-Fact 'powershell' { Add-Line "powershell: $($PSVersionTable.PSVersion) $($PSVersionTable.PSEdition)" }
  Add-Line "kit folder: $Kit"
}

# ----------------------------------------------------------- what it left

function Add-GameOutput {
  foreach ($session in $Sessions) {
    $process = $session.Process
    if (-not $process.HasExited) {
      Add-Line "Dot Popper session $($session.Number) was still open; the kit closed it."
      Stop-Game $process
    }
    [void]$process.WaitForExit(15000)
    Add-Heading "Dot Popper's output, session $($session.Number) (started $($session.Why), at $($session.Started))"
    $code = 'unknown'
    try { $code = $process.ExitCode } catch { }
    Add-Line "exit code: $code"
    Add-Line '-- standard output'
    Add-Line $session.Out.Result.TrimEnd()
    Add-Line '-- standard error'
    Add-Line $session.Err.Result.TrimEnd()
  }
}

function Add-SaveFolder {
  $save = Join-Path $env:APPDATA 'dot_popper'
  Add-Heading "The game's save folder, $save"
  if (-not (Test-Path -LiteralPath $save)) { Add-Line 'It does not exist.'; return }
  $files = @(Get-ChildItem -LiteralPath $save -File -Force | Sort-Object Name)
  foreach ($file in $files) { Add-Line ("{0,10} bytes  {1}  {2}" -f $file.Length, $file.LastWriteTime.ToString('s'), $file.Name) }
  foreach ($file in $files) {
    if ($file.Extension -notin '.csv', '.txt') { continue }
    Add-Line ''
    Add-Line "-- $($file.Name)"
    if ($file.Length -gt 500KB) { Add-Line '(too big to copy here)'; continue }
    Add-Line ([IO.File]::ReadAllText($file.FullName, $Utf8).TrimEnd())
  }
}

# ------------------------------------------------------------------ start

if (Test-Path -LiteralPath $ResultsPath) {
  $earlier = Join-Path $Kit ("dot-popper-results-earlier-{0}.txt" -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
  Move-Item -LiteralPath $ResultsPath -Destination $earlier
}

Say 'Dot Popper playtest'
Say '==================='
Say 'Thank you for trying Dot Popper! This takes about 15 minutes.'
Say 'I will start the game, then ask about one thing at a time here.'
Say 'Answer each with y (yes), n (no), or just Enter to skip, and add a note if you like.'
Say 'Keep this window beside the game, and click back into it to answer.'
Say ''

Add-Line 'Dot Popper playtest results (Windows)'
Add-Line "started: $(Get-Stamp)"
Add-Line ''
Add-Line 'The kit:'
foreach ($line in ($KitBuild -split "`r?`n")) { Add-Line "  $line" }

Say 'First, a few facts about this computer (graphics, display, controllers)...'
Add-ComputerFacts

$GameExe = $null
$found = @(Get-ChildItem -LiteralPath $Kit -Recurse -File -Filter 'Dot Popper.exe' -ErrorAction SilentlyContinue)
if ($found.Count) { $GameExe = $found[0].FullName }
if (-not $GameExe) {
  Add-Line ''
  Add-Line "Dot Popper.exe is not in the kit folder, $Kit."
  Say "I can't find Dot Popper.exe in this folder. Please unzip the whole kit and try again."
} else {
  # Files unzipped from a download carry Windows' download mark; this
  # removes only that mark, so the game starts without a warning.
  $marked = 0
  Get-ChildItem -LiteralPath $Kit -Recurse -File | ForEach-Object {
    if (Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $_.FullName; $marked++ }
  }
  Add-Line "game: $GameExe ($((Get-Item -LiteralPath $GameExe).VersionInfo.ProductVersion)); download marks removed from $marked files"

  $padChecks = @($Checks | Where-Object { $_.Group -eq 'controller' })
  $hasPad = 'no'
  if ($padChecks.Count) {
    Say ''
    Say 'Do you have a game controller (Xbox, PlayStation, or similar) connected to this computer?'
    $hasPad = Read-YesNo '  y / n:'
    Add-Line "controller to play with (the player's answer): $hasPad"
  }
  $asked = @($Checks | Where-Object { $_.Group -ne 'controller' -or $hasPad -eq 'yes' })
  $LastId = $asked[-1].Id

  Say ''
  Say 'Starting Dot Popper now. Its window opens in a moment.'
  Add-Heading 'Hand checks'
  Start-Game 'for the hand checks'
  foreach ($check in $asked) { Ask-Check $check }
  foreach ($check in $Checks) {
    if ($asked -notcontains $check) { Add-Line ''; Add-Line "[$($check.Id)] $($check.Ask)"; Add-Line '    answer: not asked (no controller)' }
  }

  Say ''
  Say 'That was the last question. Now please quit Dot Popper (Escape on Home, or close its window).'
  Wait-GameExit 'after the checks'
  Say 'Collecting what the game printed and saved...'
  Add-GameOutput
  Add-SaveFolder
}

Add-Line ''
Add-Line "finished: $(Get-Stamp)"
Save-Results

Say ''
Say '=================================================================='
Say 'All done. Thank you!'
Say ''
Say 'Your answers, and everything the kit recorded, are in this one file:'
Say ''
Say "    $ResultsPath"
Say ''
Say 'Please send that file back to Kerrick: attach it to an email or a message.'
Say '(A File Explorer window opens with the file selected.)'
Say '=================================================================='
if (-not [Console]::IsInputRedirected) {
  try { Start-Process -FilePath 'explorer.exe' -ArgumentList "/select,`"$ResultsPath`"" } catch { }
}
if (-not $NoPause -and -not [Console]::IsInputRedirected) { [void](Read-Host 'Press Enter to close this window') }
exit 0
