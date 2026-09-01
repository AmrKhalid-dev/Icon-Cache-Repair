# ============================================================
# Icon Cache Repair
# Author: Amr Khalid Al-Mosabi
# Description: Fixes corrupted or missing icon cache in Windows
#              by stopping Explorer, deleting icon cache files,
#              and restarting Explorer. No admin rights required.
# ============================================================

[CmdletBinding()]
param([switch]$Silent)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ----- CONFIG -----
$Global:ToolName = "Icon Cache Repair"
try { $Host.UI.RawUI.WindowTitle = $Global:ToolName } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# ----- HELPERS - LOGGING -----
function Write-Info {
    param([string]$Message)
    if ($Silent) { return }
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] " -NoNewline -ForegroundColor DarkGray
    Write-Host "INFO     " -NoNewline -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor White
}

function Write-Success {
    param([string]$Message)
    if ($Silent) { return }
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] " -NoNewline -ForegroundColor DarkGray
    Write-Host "SUCCESS  " -NoNewline -ForegroundColor Green
    Write-Host $Message -ForegroundColor White
}

function Write-WarningCustom {
    param([string]$Message)
    if ($Silent) { return }
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] " -NoNewline -ForegroundColor DarkGray
    Write-Host "WARNING  " -NoNewline -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor Yellow
}

function Write-ErrorCustom {
    param([string]$Message)
    if ($Silent) { return }
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] " -NoNewline -ForegroundColor DarkGray
    Write-Host "ERROR    " -NoNewline -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
}

function Write-Title {
    param([string]$Message)
    if ($Silent) { return }
    Write-Host ""
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host ("  " + ("-" * $Message.Length)) -ForegroundColor DarkGray
}

function Write-Separator {
    param([string]$Char="─",[int]$Length=62,[string]$Color="DarkGray")
    if ($Silent) { return }
    Write-Host ("  " + ($Char * $Length)) -ForegroundColor $Color
}

function Write-Secondary {
    param([string]$Message)
    if ($Silent) { return }
    Write-Host "  $Message" -ForegroundColor DarkGray
}

# ----- HELPERS - UI -----
function Show-Banner {
    if ($Silent) { return }
    Clear-Host
    Write-Host ""
    $w = 66
    $title = "Icon Cache Repair"
    $pad = [math]::Floor(($w - $title.Length) / 2)
    $titleLine = (" " * $pad) + $title + (" " * ($w - $pad - $title.Length))
    
    # Top border
    Write-Host "  ╔$([string]::new('═',$w))╗" -ForegroundColor Cyan
    
    # Empty line
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * $w) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    
    # Title
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host $titleLine -NoNewline -ForegroundColor White
    Write-Host "║" -ForegroundColor Cyan
    
    # Empty line
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * $w) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    
    # Bottom border
    Write-Host "  ╚$([string]::new('═',$w))╝" -ForegroundColor Cyan
    
    $sub = "   Fix white / black / missing icons • No Admin Required • Safe"
    $subPad = [math]::Max(0, [math]::Floor(($w - $sub.Length) / 2))
    $subRight = [math]::Max(0, $w - $subPad - $sub.Length)
    $subLine = (" " * $subPad) + $sub + (" " * $subRight)
    Write-Host "  $subLine" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-AnimatedBanner {
    param([string]$Text="REPAIRING ICON CACHE")
    if ($Silent) { return }
    $w = 66
    Write-Host ""
    Write-Host "  ╔$([string]::new('═',$w))╗" -ForegroundColor Cyan
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * $w) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    $pad = [math]::Floor(($w - $Text.Length) / 2)
    $line = (" " * $pad) + $Text + (" " * ($w - $pad - $Text.Length))
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host $line -NoNewline -ForegroundColor White
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * $w) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ╚$([string]::new('═',$w))╝" -ForegroundColor Cyan
}

function Show-Spinner {
    param([string]$Message="Working",[int]$DurationMs=700)
    if ($Silent) { return }
    $frames = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
    $end = (Get-Date).AddMilliseconds($DurationMs)
    $idx = 0
    while ((Get-Date) -lt $end) {
        $f = $frames[$idx % $frames.Count]
        Write-Host "`r  $f $Message..." -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 80
        $idx++
    }
    Write-Host "`r  $(" " * ($Message.Length+8))`r" -NoNewline
}

function Set-ConsoleTitle {
    param([string]$Title)
    try { $Host.UI.RawUI.WindowTitle = $Title } catch {}
}

# ----- HELPER - SAFE PROCESS CHECK -----
function Get-ExplorerProcess {
    return Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "explorer" }
}

# ----- CORE - GET CACHE FILES -----
function Get-IconCacheFiles {
    $list = @()
    $local = $env:LOCALAPPDATA
    if (-not $local -or -not (Test-Path $local)) { return @() }
    $legacy = Join-Path $local "IconCache.db"
    if (Test-Path $legacy) { $list += $legacy }
    $explorerPath = Join-Path $local "Microsoft\Windows\Explorer"
    if (Test-Path $explorerPath) {
        try {
            $a = Get-ChildItem -Path $explorerPath -Filter "iconcache*" -Force -ErrorAction SilentlyContinue
            foreach ($x in $a) { $list += $x.FullName }
        } catch {}
        try {
            $b = Get-ChildItem -Path $explorerPath -Filter "thumbcache*" -Force -ErrorAction SilentlyContinue
            foreach ($x in $b) { $list += $x.FullName }
        } catch {}
    }
    return $list | Where-Object { $_ } | Sort-Object -Unique
}

# ----- CORE - REPAIR -----
function Invoke-IconCacheRepair {
    if (-not $Silent) { Clear-Host }
    $start = Get-Date
    Set-ConsoleTitle "$Global:ToolName - Repairing..."
    $deleted = 0
    $failed  = 0
    $restarted = $false
    $wasRunning = $false

    try {
        Show-AnimatedBanner -Text "REPAIRING ICON CACHE"
        Write-Separator -Char "═" -Length 66 -Color Cyan
        Write-Info "Starting repair — no admin required"
        if (-not $Silent) { Write-Host "" }

        # STEP 1 - Detect Explorer
        Write-Title "Step 1/6 - Detecting Explorer"
        Write-Info "Checking explorer.exe status..."
        Show-Spinner -Message "Detecting Explorer" -DurationMs 500
        try {
            $proc = Get-ExplorerProcess
            if ($proc) {
                $wasRunning = $true
                $count = @($proc).Count
                $pidText = if ($proc -is [array]) { $proc[0].Id } else { $proc.Id }
                Write-Success "Explorer is running (PID: $pidText, Instances: $count)"
            } else {
                Write-WarningCustom "Explorer is not running"
            }
        } catch {
            Write-ErrorCustom "Failed to detect Explorer: $($_.Exception.Message)"
        }

        # STEP 2 - Stop Explorer
        Write-Title "Step 2/6 - Stopping Explorer"
        if ($wasRunning) {
            Write-Info "Stopping Explorer..."
            Start-Process -FilePath "taskkill.exe" -ArgumentList "/F /IM explorer.exe" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
            Start-Sleep -Milliseconds 500
            
            if (-not (Get-ExplorerProcess)) {
                Write-Success "Explorer stopped successfully"
            } else {
                Write-WarningCustom "Explorer is still running, continuing anyway..."
            }
        } else {
            Write-Success "Explorer already stopped - skipping"
        }

        # STEP 3 - Search Files
        Write-Title "Step 3/6 - Searching Cache Files"
        Write-Info "Scanning for cache files..."
        Show-Spinner -Message "Scanning cache" -DurationMs 600
        $allTargets = Get-IconCacheFiles
        if ($allTargets.Count -gt 0) {
            Write-Success "Found $($allTargets.Count) cache file(s) total"
            foreach ($t in $allTargets) {
                $name = Split-Path $t -Leaf
                $size = try { (Get-Item $t -Force -ErrorAction SilentlyContinue).Length } catch { 0 }
                $kb = [math]::Round($size/1KB,1)
                Write-Secondary "• $name ($kb KB)"
            }
        } else {
            Write-WarningCustom "No cache files found"
        }

        # STEP 4 - Delete Files
        Write-Title "Step 4/6 - Removing Cache Files"
        if ($allTargets.Count -eq 0) {
            Write-WarningCustom "Nothing to delete"
        } else {
            Write-Info "Deleting $($allTargets.Count) file(s)..."
            $idx = 0
            foreach ($file in $allTargets) {
                $idx++
                $leaf = Split-Path $file -Leaf
                Write-Info "[$idx/$($allTargets.Count)] Deleting $leaf..."
                try {
                    if (Test-Path $file) {
                        try { Set-ItemProperty -Path $file -Name Attributes -Value Normal -ErrorAction SilentlyContinue | Out-Null } catch {}
                        Remove-Item -Path $file -Force -ErrorAction Stop
                        Write-Success "Deleted $leaf"
                        $deleted++
                    } else {
                        Write-WarningCustom "Already gone: $leaf"
                    }
                } catch {
                    Write-ErrorCustom "Failed $leaf : $($_.Exception.Message)"
                    $failed++
                }
            }
            
            $explorerFolder = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Explorer"
            if (Test-Path $explorerFolder) {
                Get-ChildItem -Path $explorerFolder -Force -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -like "*iconcache*" -or $_.Name -like "*thumbcache*" } | 
                    ForEach-Object {
                        try {
                            Remove-Item $_.FullName -Force -ErrorAction Stop
                            $deleted++
                            Write-Success "Deleted leftover $($_.Name)"
                        } catch {
                            Write-Secondary "Skipped leftover $($_.Name) (in use)"
                        }
                    }
            }
            if ($failed -eq 0) { Write-Success "All files removed ($deleted deleted)" }
            else { Write-WarningCustom "Deleted $deleted, Failed $failed" }
        }

        # STEP 5 - Restart Explorer
        Write-Title "Step 5/6 - Restarting Explorer"
        Write-Info "Starting Explorer..."
        try {
            Start-Process -FilePath "explorer.exe" -ErrorAction Stop | Out-Null
            Start-Sleep -Seconds 1
            $tries = 0
            while (-not (Get-ExplorerProcess) -and $tries -lt 4) {
                Start-Sleep -Milliseconds 500
                $tries++
                try { Start-Process "explorer.exe" -ErrorAction SilentlyContinue | Out-Null } catch {}
            }
            if (Get-ExplorerProcess) {
                $restarted = $true
                Write-Success "Explorer restarted"
            } else {
                Write-ErrorCustom "Explorer did not restart"
            }
        } catch {
            Write-ErrorCustom "Start failed: $($_.Exception.Message)"
            try {
                Start-Process -FilePath "$env:WINDIR\explorer.exe" -ErrorAction SilentlyContinue | Out-Null
                $restarted = $true
                Write-Success "Explorer started via fallback"
            } catch { Write-ErrorCustom "Fallback failed" }
        }

        # STEP 6 - Verify & Refresh
        Write-Title "Step 6/6 - Verifying & Refreshing"
        Write-Info "Refreshing icons..."
        try {
            $ie = Join-Path $env:WINDIR "System32\ie4uinit.exe"
            if (Test-Path $ie) {
                Start-Process -FilePath $ie -ArgumentList "-show" -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
                Write-Success "Executed ie4uinit -show"
            } else {
                Write-Secondary "ie4uinit.exe not found - skipped"
            }
        } catch { Write-WarningCustom "ie4uinit failed" }
        try {
            if (-not ([System.Management.Automation.PSTypeName]'TempIconFix.Win32Refresh').Type) {
                $code = '[DllImport("user32.dll")] public static extern int UpdatePerUserSystemParameters(int a,int b,string c,int d);'
                Add-Type -MemberDefinition $code -Name Win32Refresh -Namespace TempIconFix -ErrorAction SilentlyContinue | Out-Null
            }
            [TempIconFix.Win32Refresh]::UpdatePerUserSystemParameters(1,0,"",0) | Out-Null
            Write-Success "Refreshed user parameters"
        } catch {}

        $v = Get-ExplorerProcess
        if ($v) {
            $restarted = $true
            $vp = if ($v -is [array]) { $v[0].Id } else { $v.Id }
            Write-Success "Verified Explorer running (PID $vp)"
        } else {
            Write-ErrorCustom "Explorer not detected"
        }
    }
    finally {
        if (-not (Get-ExplorerProcess)) {
            Start-Process "explorer.exe" -ErrorAction SilentlyContinue | Out-Null
        }
    }

    if (-not $Silent) { Write-Host "" }

    # FINAL SUMMARY
    $dur = (Get-Date) - $start
    $sec = [math]::Round($dur.TotalSeconds,1)
    if (-not $Silent) {
        $sw = 66
        $borderTop = "  ╔$([string]::new('═',$sw))╗"
        $borderMid = "  ╠$([string]::new('═',$sw))╣"
        $borderBot = "  ╚$([string]::new('═',$sw))╝"
        $emptyLine = "  ║$(" " * $sw)║"

        Write-Host $borderTop -ForegroundColor Cyan
        Write-Host $emptyLine -ForegroundColor Cyan

        $titleText = if ($failed -eq 0) { "Repair Completed Successfully" } else { "Repair Completed With Warnings" }
        $tp = [math]::Floor(($sw - $titleText.Length) / 2)
        $titleLine = (" " * $tp) + $titleText + (" " * ($sw - $tp - $titleText.Length))
        $tc = if ($failed -eq 0) { "Green" } else { "Yellow" }

        Write-Host "  ║" -NoNewline -ForegroundColor Cyan
        Write-Host $titleLine -NoNewline -ForegroundColor $tc
        Write-Host "║" -ForegroundColor Cyan

        Write-Host $emptyLine -ForegroundColor Cyan
        Write-Host $borderMid -ForegroundColor Cyan

        $row1 = "  Files Deleted      : $deleted"
        Write-Host "  ║" -NoNewline -ForegroundColor Cyan
        Write-Host $row1.PadRight($sw) -NoNewline -ForegroundColor White
        Write-Host "║" -ForegroundColor Cyan

        $row2 = "  Failed             : $failed"
        Write-Host "  ║" -NoNewline -ForegroundColor Cyan
        Write-Host $row2.PadRight($sw) -NoNewline -ForegroundColor White
        Write-Host "║" -ForegroundColor Cyan

        $expLabel = "  Explorer Restarted : "
        $expValue = if ($restarted) { "Yes" } else { "No" }
        $expColor = if ($restarted) { "Green" } else { "Red" }
        $expContent = $expLabel + $expValue
        $expPad = " " * ($sw - $expContent.Length)
        Write-Host "  ║" -NoNewline -ForegroundColor Cyan
        Write-Host $expLabel -NoNewline -ForegroundColor White
        Write-Host $expValue -NoNewline -ForegroundColor $expColor
        Write-Host $expPad -NoNewline -ForegroundColor White
        Write-Host "║" -ForegroundColor Cyan

        $row4 = "  Duration           : $sec Seconds"
        Write-Host "  ║" -NoNewline -ForegroundColor Cyan
        Write-Host $row4.PadRight($sw) -NoNewline -ForegroundColor White
        Write-Host "║" -ForegroundColor Cyan

        $row5 = "  Timestamp          : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host "  ║" -NoNewline -ForegroundColor Cyan
        Write-Host $row5.PadRight($sw) -NoNewline -ForegroundColor White
        Write-Host "║" -ForegroundColor Cyan

        Write-Host $emptyLine -ForegroundColor Cyan
        Write-Host $borderBot -ForegroundColor Cyan
        Write-Host ""
        if ($failed -eq 0 -and $deleted -gt 0) {
            Write-Success "Icons should be fixed now!"
            Write-Info "Tip: Restart PC if icons still look wrong."
        } elseif ($deleted -eq 0) {
            Write-WarningCustom "No files deleted - cache already clean."
        } else {
            Write-WarningCustom "Some files failed. Restart PC and try again."
        }
    }
    Set-ConsoleTitle "$Global:ToolName - Done"
    return @{ Deleted=$deleted; Failed=$failed; Restarted=$restarted; Duration=$sec; Success=($failed -eq 0) }
}

# ----- MENU -----
function Show-Menu {
    if ($Silent) { return }
    $w = 66
    
    # Top Border
    Write-Host "  ┌$([string]::new('─',$w))┐" -ForegroundColor Cyan
    
    # Title Line
    $title = " MAIN MENU"
    $titleLine = $title.PadRight($w)
    Write-Host "  │" -NoNewline -ForegroundColor Cyan
    Write-Host $titleLine -NoNewline -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan
    
    # Middle Divider Line
    Write-Host "  ├$([string]::new('─',$w))┤" -ForegroundColor Cyan
    
    # Empty Space Line
    Write-Host "  │" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * $w) -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    
    # Options
    $opt1 = "   [1] Repair Icon Cache"
    Write-Host "  │" -NoNewline -ForegroundColor Cyan
    Write-Host $opt1.PadRight($w) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor Cyan
    
    $opt2 = "   [2] Exit"
    Write-Host "  │" -NoNewline -ForegroundColor Cyan
    Write-Host $opt2.PadRight($w) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor Cyan
    
    # Empty Space Line
    Write-Host "  │" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * $w) -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    
    # Bottom Border
    Write-Host "  └$([string]::new('─',$w))┘" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-MenuLoop {
    while ($true) {
        Show-Menu
        Write-Host "  Select an option [1-2]: " -NoNewline -ForegroundColor Cyan
        $choice = (Read-Host).Trim()
        switch ($choice) {
            "1" {
                Clear-Host
                $null = Invoke-IconCacheRepair
                Write-Host ""
                Write-Host "  Press [Enter] to return to main menu or Press [Ctrl + C] to exit..." -ForegroundColor Yellow
                Write-Host "  > " -NoNewline -ForegroundColor Yellow
                [void](Read-Host)
                Clear-Host
                Show-Banner
            }
            "2" {
                Write-Host ""
                Write-Host "  Thank you for using Icon Cache Repair!" -ForegroundColor Cyan
                Write-Host "  Goodbye!" -ForegroundColor Cyan
                Write-Host ""
                Set-ConsoleTitle "PowerShell"
                Start-Sleep -Milliseconds 600
                return
            }
            default {
                Write-WarningCustom "Invalid choice '$choice' - please enter 1 or 2"
                Start-Sleep -Milliseconds 800
            }
        }
    }
}

# ----- ENTRY -----
if ($Silent) {
    Set-ConsoleTitle "$Global:ToolName - Silent"
    $r = Invoke-IconCacheRepair
    
    $code = if ($r.Success) { 0 } else { 1 }

    if ($Host.Name -eq "ConsoleHost" -and $MyInvocation.Line -match '\.ps1') {
        $global:LASTEXITCODE = $code
        return
    } else {
        [Environment]::Exit($code)
    }
}

Show-Banner
Invoke-MenuLoop
