# appUnblocker created by yourworstnightmare1
# GitHub: https://github.com/yourworstnightmare1/appunblocker

Write-Host "Loading..." -ForegroundColor Yellow
Write-Host "Setting variables..."

$iconappUnblocker = "                                                                                                        
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
"

$iconError = "
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
"

Write-Host "Getting version info..." -ForegroundColor Yellow

# Load version from external file so version updates don't require script edits.
$scriptDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
$versionFile = Join-Path $scriptDir "version.txt"

if (Test-Path $versionFile) {
    $appVersion = (Get-Content $versionFile -Raw).Trim()
}
else {
    $appVersion = "0.0.0"
    Write-Host "version.txt not found. Using fallback version 0.0.0." -ForegroundColor Yellow
}

Write-Host "Current version: $appVersion" -ForegroundColor Green
Write-Host "$iconappUnblocker" -ForegroundColor Red
Write-Host "Welcome to appUnblocker!" -ForegroundColor Red
Write-Host "Version $appVersion" -ForegroundColor Yellow
Write-Host "Created & Programmed by yourworstnightmare1"
Write-Host "___________________________________________"
Write-Host ""
Write-Host "Choose an option:" -ForegroundColor Cyan
Write-Host "[1] Start appUnblocker"
Write-Host "[2] Go to ReBlock website"
Write-Host "[3] Go to GitHub"
Write-Host "[4] Exit"

do {
  $choice = Read-Host "Enter 1-4"
  switch ($choice) {
      "1" {
          $runtime = [System.Runtime.InteropServices.RuntimeInformation]
          if (-not $runtime::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
              Write-Host "This option runs the Windows unblock script only." -ForegroundColor Yellow
              continue
          }

          $windowsFlow = Join-Path $PSScriptRoot "windows\scripts\script.ps1"
          if (-not (Test-Path -LiteralPath $windowsFlow)) {
              Write-Host "$iconError" -ForegroundColor Red
              Write-Host "Windows script not found: $windowsFlow" -ForegroundColor Red
              continue
          }

          & $windowsFlow
      }
      "2" {
          Start-Process "https://sites.google.com/view/reblock"
          Write-Host "Opened website in your browser." -ForegroundColor Green
      }
      "3" {
          Start-Process "https://github.com/yourworstnightmare1/appunblocker"
          Write-Host "Opened GitHub in your browser." -ForegroundColor Green
      }
      "4" {
          Write-Host "Goodbye!" -ForegroundColor Yellow
          exit
      }
      default {
          Write-Host "Invalid choice. Please enter 1, 2, 3, or 4." -ForegroundColor Red
      }
  }
} while ($true)

