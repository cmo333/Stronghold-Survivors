# Pull the latest work and relaunch the game. Windows/PowerShell port of play.sh.
#
#   .\play.ps1
#
# Fetches origin/slim, snaps the working tree to it, imports anything new, and
# restarts the game. Local edits are stashed (never discarded) before the reset.
#
# Overrides:
#   .\play.ps1 -Branch main              # different branch
#   .\play.ps1 -Godot 'C:\Godot\Godot_v4.7.1-stable_win64_console.exe'   # remembered
#   .\play.ps1 -NoRun                    # update only, don't launch
#
# If PowerShell refuses to run this ("running scripts is disabled on this
# system"), it is the execution policy, not the script. Once, per user:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#
# NOT the same shape as play.sh in two places, both deliberate:
#
#   - play.sh re-execs itself when a pull rewrites it mid-run, because bash
#     reads a script incrementally and shifting bytes on disk corrupt the rest
#     of the run. PowerShell parses the whole file into an AST before executing
#     a single line, so that failure mode does not exist here and there is no
#     re-exec. A change to THIS file still only takes effect on the next run.
#   - Start-Process cannot point stdout and stderr at one file, so the launch
#     writes .play.log and .play.err.log and both get scanned.

[CmdletBinding()]
param(
	[string]$Branch = 'slim',
	[string]$Godot = '',
	[switch]$NoRun
)

$ErrorActionPreference = 'Continue'

$RepoDir      = $PSScriptRoot
$PidFile      = Join-Path $RepoDir '.play.pid'
$GodotPathFile= Join-Path $RepoDir '.play.godot'
$LogFile      = Join-Path $RepoDir '.play.log'
$ErrLogFile   = Join-Path $RepoDir '.play.err.log'

Set-Location $RepoDir

function Say  { param($m) Write-Host "`n$m" -ForegroundColor White }
function Warn { param($m) Write-Host $m -ForegroundColor Yellow }
function Fail { param($m) Write-Host $m -ForegroundColor Red; exit 1 }

# --- 1. Never lose local edits -----------------------------------------------
if (git status --porcelain) {
	$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
	Warn "You have local changes. Stashing them as 'play-$stamp' so nothing is lost."
	Warn "  Get them back with:  git stash pop"
	git stash push -u -m "play-$stamp" | Out-Null
	if ($LASTEXITCODE -ne 0) { Fail 'Could not stash local changes; stopping.' }
}

# --- 2. Fetch, with retries for flaky wifi -----------------------------------
Say "Fetching origin/$Branch ..."
$fetched = $false
$delay = 2
foreach ($i in 1..4) {
	git fetch origin $Branch
	if ($LASTEXITCODE -eq 0) { $fetched = $true; break }
	Warn "Fetch failed, retrying in ${delay}s ..."
	Start-Sleep -Seconds $delay
	$delay *= 2
}
if (-not $fetched) { Fail 'Could not reach GitHub after 4 tries. Check your connection.' }

# --- 3. Snap to it -----------------------------------------------------------
$old = (git rev-parse --short HEAD).Trim()
git reset --hard "origin/$Branch" | Out-Null
if ($LASTEXITCODE -ne 0) { Fail 'Reset failed.' }
$new = (git rev-parse --short HEAD).Trim()

if ($old -eq $new) {
	Say "Already up to date at $new."
} else {
	Say "Updated $old -> $new"
	git --no-pager log --oneline "$old..$new" | ForEach-Object { "  $_" }
}
Write-Host ''
git --no-pager log --oneline -1 | ForEach-Object { "now at: $_" }

if ($NoRun) { exit 0 }

# --- 4. Find the engine ------------------------------------------------------
# Resolution order: explicit -Godot -> remembered path -> the usual install and
# download locations -> PATH. Whatever wins is remembered so this only happens
# once.
#
# PREFER THE _console.exe BUILD. Godot ships two Windows binaries per release:
# Godot_v4.7.1-stable_win64.exe is a GUI-subsystem executable with no attached
# console, so redirecting its output captures NOTHING -- an empty .play.log next
# to a game that failed to start, which is the exact state play.sh was written
# to end. Godot_v4.7.1-stable_win64_console.exe is the same engine built as a
# console app and its stdout/stderr are real.
$godotBin = ''

function Test-Bin { param($p) if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { return $p } return '' }

# The remembered engine path, or '' if there is not one.
#
# A FUNCTION, not two inline reads. Get-Content -Raw returns $null for a
# zero-byte file and .Trim() on $null throws, and this file is read in two
# places -- the lookup below and the write-back after it. 03e18ab guarded the
# first and left the second, in a commit whose entire subject was that bug. Two
# copies of a fix is one copy too many.
function Get-RememberedGodot {
	if (-not (Test-Path -LiteralPath $GodotPathFile)) { return '' }
	$raw = Get-Content -LiteralPath $GodotPathFile -Raw
	if (-not $raw) { return '' }
	return $raw.Trim()
}

# Within one directory, the console build wins over the plain one.
function Find-InDir {
	param($dir)
	if (-not (Test-Path -LiteralPath $dir)) { return '' }
	$hit = Get-ChildItem -LiteralPath $dir -Filter 'Godot*console.exe' -File -ErrorAction SilentlyContinue |
		Sort-Object Name -Descending | Select-Object -First 1
	if (-not $hit) {
		$hit = Get-ChildItem -LiteralPath $dir -Filter 'Godot*.exe' -File -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -notmatch 'mono' } |
			Sort-Object Name -Descending | Select-Object -First 1
	}
	if ($hit) { return $hit.FullName }
	return ''
}

if (-not $godotBin) { $godotBin = Test-Bin $Godot }
if (-not $godotBin -and $env:GODOT) { $godotBin = Test-Bin $env:GODOT }
if (-not $godotBin) { $godotBin = Test-Bin (Get-RememberedGodot) }
if (-not $godotBin) {
	# Built with an explicit null guard per entry rather than inline Join-Path:
	# Join-Path throws on a null first argument, and a machine missing any one of
	# these environment variables would take the search down instead of simply
	# skipping that directory.
	$searchDirs = @($RepoDir, 'C:\Godot')
	foreach ($pair in @(
		@($env:LOCALAPPDATA, 'Programs\Godot'),
		@($env:ProgramFiles, 'Godot'),
		@($HOME, 'Downloads'),
		@($HOME, 'Desktop'),
		@($HOME, 'scoop\apps\godot\current')
	)) {
		if ($pair[0]) { $searchDirs += (Join-Path $pair[0] $pair[1]) }
	}
	$searchDirs += 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine'
	foreach ($dir in $searchDirs) {
		$godotBin = Find-InDir $dir
		if ($godotBin) { break }
	}
}
if (-not $godotBin) {
	foreach ($c in @('godot4', 'godot')) {
		$cmd = Get-Command $c -ErrorAction SilentlyContinue
		if ($cmd) { $godotBin = $cmd.Source; break }
	}
}

if (-not $godotBin) {
	Warn ''
	Warn "Updated, but couldn't find Godot to launch it."
	Warn ''
	Warn 'Find it with:'
	Warn '  Get-ChildItem -Path $HOME, C:\ -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5 FullName'
	Warn ''
	Warn 'Then point at it once (prefer the _console build):'
	Warn "  .\play.ps1 -Godot 'C:\Godot\Godot_v4.7.1-stable_win64_console.exe'"
	Warn ''
	Warn 'It gets remembered after that, so plain .\play.ps1 works from then on.'
	Warn ''
	Warn 'THE PULL ALREADY SUCCEEDED. The repo is up to date either way -- switch'
	Warn 'to the Godot editor and press F5 if you would rather not bother with this.'
	exit 0
}

if ((Get-RememberedGodot) -ne $godotBin) {
	Set-Content -LiteralPath $GodotPathFile -Value $godotBin -NoNewline
	Write-Host "engine: $godotBin (remembered)"
}

# The engine must match what the project declares, or the run is against the
# wrong build and the failure shows up as something else entirely.
$ver = (& $godotBin --version 2>&1 | Select-Object -First 1)
Write-Host "engine version: $ver"
if ($ver -notmatch '^4\.7') { Warn "  project.godot declares 4.7 -- this is $ver. Expect a conversion prompt or worse." }

# --- 5. Restart the game -----------------------------------------------------
# Only ever kills a game this script started (tracked by PID), so an open Godot
# editor is left alone. PIDs get recycled, so the name is confirmed before
# anything is signalled.
if (Test-Path -LiteralPath $PidFile) {
	# Same $null-Trim trap as the remembered engine path: an interrupted write
	# leaves a zero-byte .play.pid, Get-Content -Raw returns $null for it, and
	# .Trim() on $null throws. Third instance of this pattern in one file.
	$pidRaw = Get-Content -LiteralPath $PidFile -Raw
	$oldPid = if ($pidRaw) { $pidRaw.Trim() } else { '' }
	if ($oldPid -match '^\d+$') {
		$proc = Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue
		if ($proc) {
			if ($proc.ProcessName -match 'odot') {
				Write-Host "closing previous run (pid $oldPid)"
				Stop-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue
				Start-Sleep -Seconds 1
			} else {
				Write-Host "stale pid $oldPid is $($proc.ProcessName), not the engine -- leaving it alone"
			}
		}
	}
	Remove-Item -LiteralPath $PidFile -ErrorAction SilentlyContinue
}

Set-Content -LiteralPath $LogFile -Value '' -NoNewline
Set-Content -LiteralPath $ErrLogFile -Value '' -NoNewline

# --- 5a. Import anything the pull brought in ---------------------------------
# `godot --path .` does NOT run the import pipeline. A texture that arrived in
# the last pull has no entry in .godot/imported, so `load()` returns null and
# the art renders as nothing at all -- not a placeholder, nothing. The .import
# sidecars are gitignored, so this hits every machine for every new asset, and
# it is invisible in the game log unless you know to look for "No loader found".
#
# On a FRESH CLONE this is not a no-op: it is the whole multi-minute first
# import, and it is why the first run of this script takes far longer than the
# rest. Subsequent runs cost engine startup and nothing more.
Say 'Importing assets ...'
& $godotBin --headless --path $RepoDir --import 2>&1 | Tee-Object -FilePath $LogFile -Append | Out-Null
$importText = ''
if (Test-Path -LiteralPath $LogFile) { $importText = Get-Content -LiteralPath $LogFile -Raw }
if ($importText -match 'Parse Error|Failed to load resource') {
	Warn 'Import errors (first 5):'
	Select-String -LiteralPath $LogFile -Pattern 'Parse Error|Failed to load resource' |
		Select-Object -First 5 | ForEach-Object { "  $($_.Line)" }
}

Say 'Launching AVARICE ...'
$proc = Start-Process -FilePath $godotBin -ArgumentList '--path', $RepoDir `
	-RedirectStandardOutput $LogFile -RedirectStandardError $ErrLogFile -PassThru
Set-Content -LiteralPath $PidFile -Value $proc.Id -NoNewline
Write-Host "running (pid $($proc.Id))"

# Surface the startup banner and anything that failed to load, so a bad launch
# announces itself instead of just looking wrong on screen.
Start-Sleep -Seconds 3
foreach ($f in @($LogFile, $ErrLogFile)) {
	if (-not (Test-Path -LiteralPath $f)) { continue }
	Select-String -LiteralPath $f -Pattern '^\[startup\]' | Select-Object -First 3 |
		ForEach-Object { $_.Line }
	$hits = Select-String -LiteralPath $f -Pattern 'SCRIPT ERROR|Parse Error|Failed to compile'
	if ($hits) {
		Warn ''
		Warn "Script errors during startup in $(Split-Path -Leaf $f) (first 5):"
		$hits | Select-Object -First 5 | ForEach-Object { "  $($_.Line)" }
	}
}
Write-Host "full log: $LogFile  (stderr: $ErrLogFile)"
