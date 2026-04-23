# appUnblocker Windows unblock flow (PowerShell port of script.bat)
# GitHub: https://github.com/yourworstnightmare1/appunblocker
# Expects to be launched from appunblocker.ps1; can also be run standalone.

$ErrorActionPreference = 'Stop'

if ($Host.Name -eq 'ConsoleHost' -and $Host.UI -and $Host.UI.RawUI) {
    $Host.UI.RawUI.WindowTitle = 'script.ps1 - appUnblocker for Windows by yourworstnightmare1'
}

$banner = @"
          ==============================
       ====================================
      ======================================
     ========================================
    ===================-::-===================
    ================:....... :================
    =============:...:======:...:=============
    ===========.  .============.  .-==========
    =========- .-================-. :=========
    =========- .-================-. :=========
    ==========-.. :============:...-==========
    ============-.  .:======-.. .-============
    +=========-.. :-: ........-: ..-=========+
    +++++++++: .-+++++=:..:-+++++-. -+++++++++
    +++++++++: .-=++++++++++++++=-. -+++++++++
    ++++++++++=...:=++++++++++=.. .=++++++++++
    ++++++++++++=:. .-=++++=:...:=++++++++++++
    +++++++++++++++=: ...... :=+++++++++++++++
    ++++++++++++++++++=-::-=++++++++++++++++++
     ++++++++++++++++++++++++++++++++++++++++
      ++++++++++++++++++++++++++++++++++++++
       ++++++++++++++++++++++++++++++++++++
          ++++++++++++++++++++++++++++++
"@

$iconError = @"
    ####*                        *####
  +#######-                    =#######+
 ###########.                .###########.
  ############              ############
    ############          ############
     .############      ############
       =###########*  *###########-
         ########################
           ####################
             ################
              -############:
             ################
           ####################
         =######################=
       .############  ############.
      ############      ############
    ############          ############
  ############.            .############
 ###########=                =###########.
  ########+                    *########
    #####                        #####
"@

function Show-CriticalError {
    param ([string]$Detail)
    Clear-Host
    Write-Host $iconError -ForegroundColor Red
    Write-Host 'A critical error has occurred.' -ForegroundColor Red
    Write-Host '______________________________' -ForegroundColor Red
    Write-Host $Detail -ForegroundColor Yellow
    Write-Host 'Consider reinstalling your application.' -ForegroundColor Yellow
    Write-Host 'Press Enter to exit appUnblocker.' -ForegroundColor Yellow
    [void][System.Console]::ReadLine()
    exit 1
}

Clear-Host
Write-Host $banner -ForegroundColor Red
Write-Host '______________________________________________' -ForegroundColor Red
Write-Host 'Before we begin, we need to know some things in order to continue.' -ForegroundColor Red
Write-Host ''
Write-Host 'Please type the path to your application (.exe), or drag the file into this window.' -ForegroundColor Red
Write-Host 'If the path has spaces, wrap it in quotes (example: "C:\Users\joe\Downloads\app.exe").' -ForegroundColor Red
Write-Host ''

$application = Read-Host 'Application path'
$application = $application.Trim().Trim('"').Trim("'")

if ([string]::IsNullOrWhiteSpace($application)) {
    Show-CriticalError -Detail 'No path was entered.'
}

if (-not (Test-Path -LiteralPath $application)) {
    Show-CriticalError -Detail "Path not found: $application"
}

$stamp = Get-Date -Format 'HH:mm:ss'
Write-Host "[$stamp | INFO] Running compatibility layer (RunAsInvoker)..." -ForegroundColor Yellow

$env:__COMPAT_LAYER = 'RunAsInvoker'
try {
    # Windows PowerShell 5.1: Start-Process has -FilePath only (no -LiteralPath).
    Start-Process -FilePath $application -ErrorAction Stop
}
catch {
    Show-CriticalError -Detail "Failed to start application with path $application. $($_.Exception.Message)"
}
finally {
    Remove-Item Env:\__COMPAT_LAYER -ErrorAction SilentlyContinue
}

$stamp = Get-Date -Format 'HH:mm:ss'
Write-Host "[$stamp | SUCCESS] Executed application successfully!" -ForegroundColor Green
