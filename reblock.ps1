Write-Host "Loading..." -ForegroundColor yellow
Write-Host "Setting variables..."

# CLI Icons
$iconReBlock = "
           =============================           
         ==================================        
       ======================================      
      ========================================     
     ===========================--=============    
     =======================:........-=========    
     ======================..-======:.:========    
     =====================:.-=======+..-=======    
     =====================..=========: -=======    
     =====================..=========: -=======    
     =========::::..........:=========:========    
     =======-.               .=======+++======+    
     =====++-                 =====+++++======+    
     +++++++-                 =++++++++++++++++    
     +++++++-                 =++++++++++++++++    
     +++++++-                 =++++++++++++++++     
     +++++++-                 =++++++++++++++++    
     +++++++=.               .=++++++++++++++++    
     +++++++++--------------=++++++++++++++++++    
      ++++++++++++++++++++++++++++++++++++++++     
       ++++++++++++++++++++++++++++++++++++++      
         ++++++++++++++++++++++++++++++++++        
            ++++++++++++++++++++++++++++
"

$iconLoading = "
                 KGV                    
              MAADTZ                 
             ZLAAAAARZ               
         ZODAAAAAAAAACY              
       YIAAAABFAAAAANZ      ZOX      
     ZNAAAAJZ SAAAHX       QAAALZ    
    ZFAAAIZ   TADV         ZFAAAEZ   
   ZIAAAO     VR             OAAAHZ  
   UAAAK                      KAAAT  
   HAAC                        BAAH  
   CAAG                        HAAB  
   DAAG                        GAAC  
   LAAAX                      YAAAK  
   XBAACZ                     FAABV  
   ZOAAAG            YGR     JAAAMZ  
     RAAAAQZ       ZMAAQ   TCAAAO    
      VCABV       TCAAAPZRBAAABU     
       ZYZ      WEAAAAAAAAAAASZ      
               YHAAAAAAAADNWZ        
                 YJAAAAM             
                    NBAK
"

$iconWarning = "
                     ...                   
                    .....                  
                  ........                 
                 ....   ....               
                ....     ....              
               ......   ......             
              .......   .......            
             ........   ........           
            .........   .........          
           ..........   ..........         
          ...........   ...........        
         ............   ............       
        .............. ..............      
       ...............................     
      ...............   ...............    
     ................   ................   
    .....................................  
   .......................................
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

$iconSuccess = "
                                    ===    
                                  =======  
                                ===========
                              ============ 
                             ===========   
                           ===========     
                         ===========       
     ====              ============        
   ========          ============          
  ============      ============            
  =============  ============              
    =======================                
      ===================                  
        ===============                    
          ===========                      
            ========                       
              ==== 
"

Write-Host "Getting version info..." -ForegroundColor Yellow

# Load version from external file so version updates don't require script edits.
# Use multiple fallbacks because invocation context can differ between hosts.
$scriptDir = $null
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $scriptDir = $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptDir = Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation -and $MyInvocation.MyCommand -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    $scriptDir = (Get-Location).Path
    Write-Host "Could not resolve script path from invocation context. Using current directory." -ForegroundColor Yellow
}

# Try multiple candidate roots so compiled launches can still locate packaged assets.
$candidateRoots = @(
    $scriptDir,
    (Join-Path $scriptDir "data"),
    (Join-Path $scriptDir "ReBlock"),
    (Get-Location).Path,
    (Join-Path (Get-Location).Path "data"),
    (Join-Path (Get-Location).Path "ReBlock")
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

$appRoot = $null
foreach ($candidate in $candidateRoots) {
    $candidateVersion = Join-Path $candidate "version.txt"
    $candidatePlugins = Join-Path $candidate "plugins"
    if ((Test-Path $candidateVersion) -and (Test-Path $candidatePlugins)) {
        $appRoot = $candidate
        break
    }
}

if ([string]::IsNullOrWhiteSpace($appRoot)) {
    $appRoot = $scriptDir
}

$versionFile = Join-Path $appRoot "version.txt"

if (Test-Path $versionFile) {
    $appVersion = (Get-Content $versionFile -Raw).Trim()
}
else {
    $appVersion = "0.0.0"
    Write-Host "version.txt not found. Using fallback version 0.0.0." -ForegroundColor Yellow
}

Write-Host "Current version: $appVersion" -ForegroundColor Green

Write-Host "Initalizing..." -ForegroundColor Yellow

function Get-PluginMetadata {
    param (
        [string]$PluginRoot
    )

    if (-not (Test-Path $PluginRoot)) {
        return @()
    }

    $pluginFiles = Get-ChildItem -Path $PluginRoot -Filter "plugin.xml" -Recurse -File
    $plugins = @()

    foreach ($pluginFile in $pluginFiles) {
        try {
            [xml]$xml = Get-Content -Path $pluginFile.FullName -Raw

            if (-not $xml.plugin) {
                Write-Host "Skipping invalid plugin file: $($pluginFile.FullName)" -ForegroundColor Yellow
                continue
            }

            $entryPoints = @()
            if ($xml.plugin.entryPoints -and $xml.plugin.entryPoints.entry) {
                foreach ($entry in @($xml.plugin.entryPoints.entry)) {
                    if (-not [string]::IsNullOrWhiteSpace($entry.path)) {
                        $entryName = if ($entry.name) { [string]$entry.name } else { "Default" }
                        $entryPoints += [PSCustomObject]@{
                            Name = $entryName
                            Path = Join-Path $pluginFile.DirectoryName ([string]$entry.path)
                        }
                    }
                }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($xml.plugin.entryScript)) {
                $entryPoints += [PSCustomObject]@{
                    Name = "Default"
                    Path = Join-Path $pluginFile.DirectoryName ([string]$xml.plugin.entryScript)
                }
            }

            if ($entryPoints.Count -eq 0) {
                Write-Host "Skipping plugin without entryScript or entryPoints: $($pluginFile.FullName)" -ForegroundColor Yellow
                continue
            }

            $plugins += [PSCustomObject]@{
                Name = if ($xml.plugin.name) { $xml.plugin.name } else { Split-Path $pluginFile.DirectoryName -Leaf }
                Version = if ($xml.plugin.version) { $xml.plugin.version } else { "unknown" }
                Description = if ($xml.plugin.description) { $xml.plugin.description } else { "No description" }
                Author = if ($xml.plugin.author) { $xml.plugin.author } else { "unknown" }
                MinWindowsVer = if ($xml.plugin.minWindowsVer) { $xml.plugin.minWindowsVer } else { "any" }
                MinMacOSVer = if ($xml.plugin.minMacOSVer) { $xml.plugin.minMacOSVer } else { "any" }
                EntryPoints = $entryPoints
                Directory = $pluginFile.DirectoryName
            }
        }
        catch {
            Write-Host "Failed to parse plugin XML: $($pluginFile.FullName)" -ForegroundColor Red
        }
    }

    return $plugins
}

function Convert-ToComparableVersion {
    param (
        [string]$VersionText
    )

    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        return $null
    }

    $match = [regex]::Match($VersionText, "\d+(\.\d+){0,3}")
    if (-not $match.Success) {
        return $null
    }

    try {
        return [version]$match.Value
    }
    catch {
        return $null
    }
}

function Get-CurrentOsInfo {
    $runtime = [System.Runtime.InteropServices.RuntimeInformation]

    if ($runtime::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        # Do not trust Environment.OSVersion on Windows PowerShell because it can
        # report legacy versions (for example 6.2 on Windows 10/11).
        $versionText = ""
        try {
            $cv = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
            $major = 0
            $minor = 0
            if ($null -ne $cv.CurrentMajorVersionNumber -and $null -ne $cv.CurrentMinorVersionNumber) {
                $major = [int]$cv.CurrentMajorVersionNumber
                $minor = [int]$cv.CurrentMinorVersionNumber
            }
            else {
                $majorMinor = [Environment]::OSVersion.Version
                $major = [int]$majorMinor.Major
                $minor = [int]$majorMinor.Minor
            }

            $build = if ($cv.CurrentBuildNumber) { [int]$cv.CurrentBuildNumber } else { [int][Environment]::OSVersion.Version.Build }
            $ubr = if ($null -ne $cv.UBR) { [int]$cv.UBR } else { 0 }
            $versionText = "$major.$minor.$build.$ubr"
        }
        catch {
            $versionText = [Environment]::OSVersion.Version.ToString()
        }

        return [PSCustomObject]@{
            Platform = "Windows"
            VersionText = $versionText
            VersionObj = Convert-ToComparableVersion -VersionText $versionText
        }
    }

    if ($runtime::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        $versionText = ""
        try {
            $versionText = (sw_vers -productVersion).Trim()
        }
        catch {
            $versionText = ""
        }

        return [PSCustomObject]@{
            Platform = "macOS"
            VersionText = $versionText
            VersionObj = Convert-ToComparableVersion -VersionText $versionText
        }
    }

    return [PSCustomObject]@{
        Platform = "Unknown"
        VersionText = "unknown"
        VersionObj = $null
    }
}

function Show-ErrorMessage {
    param (
        [string]$Message
    )

    Write-Host ""
    Write-Host "$iconError" -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
}

function Test-IsUnsupportedMarker {
    param (
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $normalized = $Value.Trim().ToLowerInvariant()
    return $normalized -in @("unsupported", "not supported", "none", "n/a")
}

function Select-PluginEntryPoint {
    param (
        [object]$Plugin
    )

    $entryPoints = @($Plugin.EntryPoints)
    if ($entryPoints.Count -eq 1) {
        return $entryPoints[0]
    }

    Write-Host ""
    Write-Host "Choose launch mode for $($Plugin.Name):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $entryPoints.Count; $i++) {
        Write-Host "[$($i + 1)] $($entryPoints[$i].Name)"
    }
    Write-Host "[X] Back"
    Write-Host ""

    do {
        $entrySelection = Read-Host "Choose mode number"
        if ($entrySelection -eq "X" -or $entrySelection -eq "x") {
            return $null
        }

        if ($entrySelection -match "^\d+$") {
            $entryIndex = [int]$entrySelection - 1
            if ($entryIndex -ge 0 -and $entryIndex -lt $entryPoints.Count) {
                return $entryPoints[$entryIndex]
            }
        }

        Write-Host "Invalid choice. Enter a valid number or X." -ForegroundColor Red
    } while ($true)
}

function Start-PluginEntry {
    param (
        [string]$EntryPath,
        [string]$WorkingDirectory,
        [string]$Platform
    )

    $previousLocation = Get-Location
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory) -and (Test-Path $WorkingDirectory)) {
        Set-Location $WorkingDirectory
    }

    try {
    if ($Platform -eq "Windows") {
        if ($EntryPath -match "\.ps1$") {
            # Run in current PowerShell instance to keep a single window.
            & $EntryPath
            if (-not $?) {
                throw "Plugin PowerShell script failed: $EntryPath"
            }
            return
        }

        if ($EntryPath -match "\.bat$") {
            # Run in current console window.
            & cmd.exe /c "`"$EntryPath`""
            if ($LASTEXITCODE -ne 0) {
                throw "Plugin batch script failed with exit code ${LASTEXITCODE}: $EntryPath"
            }
            return
        }

        Start-Process -FilePath $EntryPath -WorkingDirectory $WorkingDirectory
        return
    }

    if ($Platform -eq "macOS") {
        if ($EntryPath -match "\.app$") {
            Start-Process -FilePath "open" -ArgumentList @("`"$EntryPath`"") -WorkingDirectory $WorkingDirectory
            return
        }

        if ($EntryPath -match "\.sh$") {
            # Run in current terminal/session.
            & bash $EntryPath
            if ($LASTEXITCODE -ne 0) {
                throw "Plugin shell script failed with exit code ${LASTEXITCODE}: $EntryPath"
            }
            return
        }

        Start-Process -FilePath $EntryPath -WorkingDirectory $WorkingDirectory
        return
    }

    if ($EntryPath -match "\.ps1$") {
        & $EntryPath
        if (-not $?) {
            throw "Plugin PowerShell script failed: $EntryPath"
        }
        return
    }

    if ($EntryPath -match "\.sh$") {
        & bash $EntryPath
        if ($LASTEXITCODE -ne 0) {
            throw "Plugin shell script failed with exit code ${LASTEXITCODE}: $EntryPath"
        }
        return
    }

    if ($EntryPath -match "\.bat$") {
        & cmd.exe /c "`"$EntryPath`""
        if ($LASTEXITCODE -ne 0) {
            throw "Plugin batch script failed with exit code ${LASTEXITCODE}: $EntryPath"
        }
        return
    }

    Start-Process -FilePath $EntryPath -WorkingDirectory $WorkingDirectory
    }
    finally {
        Set-Location $previousLocation
    }
}

function Show-PluginMenu {
    param (
        [string]$PluginRoot
    )

    $plugins = @(Get-PluginMetadata -PluginRoot $PluginRoot)
    if ($plugins.Count -eq 0) {
        Write-Host "No plugins detected in $PluginRoot" -ForegroundColor Yellow
        return $false
    }

    Write-Host ""
    Write-Host "Detected plugins:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $plugins.Count; $i++) {
        $plugin = $plugins[$i]
        Write-Host "[$($i + 1)] $($plugin.Name) ($($plugin.Version)) - $($plugin.Description)"
        Write-Host "    Author: $($plugin.Author) | Min Windows: $($plugin.MinWindowsVer) | Min macOS: $($plugin.MinMacOSVer)" -ForegroundColor DarkGray
    }
    Write-Host "[X] Back"
    Write-Host ""

    do {
        $selection = Read-Host "Choose plugin number"

        if ($selection -eq "X" -or $selection -eq "x") {
            return $false
        }

        if ($selection -match "^\d+$") {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $plugins.Count) {
                $selectedPlugin = $plugins[$index]
                $osInfo = Get-CurrentOsInfo
                if ($osInfo.Platform -eq "Unknown") {
                    Show-ErrorMessage -Message "ERROR: Plugin cannot be launched because your OS is unsupported."
                    Write-Host "This plugin system currently supports Windows and macOS only." -ForegroundColor Yellow
                    continue
                }

                $requiredVersionText = if ($osInfo.Platform -eq "Windows") {
                    $selectedPlugin.MinWindowsVer
                }
                else {
                    $selectedPlugin.MinMacOSVer
                }

                if (Test-IsUnsupportedMarker -Value $requiredVersionText) {
                    Show-ErrorMessage -Message "ERROR: Plugin cannot be launched because the OS is unsupported."
                    Write-Host "Plugin $($selectedPlugin.Name) does not support $($osInfo.Platform)." -ForegroundColor Yellow
                    continue
                }

                if (-not [string]::IsNullOrWhiteSpace($requiredVersionText) -and $requiredVersionText -ne "any") {
                    $requiredVersion = Convert-ToComparableVersion -VersionText $requiredVersionText
                    if ($null -eq $requiredVersion) {
                        Show-ErrorMessage -Message "ERROR: Plugin cannot be launched because its minimum version requirement is invalid."
                        Write-Host "Plugin: $($selectedPlugin.Name) | Required $($osInfo.Platform): $requiredVersionText" -ForegroundColor Yellow
                        continue
                    }

                    if ($null -eq $osInfo.VersionObj) {
                        Show-ErrorMessage -Message "ERROR: Plugin cannot be launched because your OS version could not be detected."
                        continue
                    }

                    if ($osInfo.VersionObj -lt $requiredVersion) {
                        Show-ErrorMessage -Message "ERROR: Plugin cannot be launched because the OS is unsupported."
                        Write-Host "Required $($osInfo.Platform): $requiredVersion | Current: $($osInfo.VersionText)" -ForegroundColor Yellow
                        continue
                    }
                }

                $chosenEntryPoint = Select-PluginEntryPoint -Plugin $selectedPlugin
                if ($null -eq $chosenEntryPoint) {
                    continue
                }

                if (-not (Test-Path $chosenEntryPoint.Path)) {
                    Show-ErrorMessage -Message "Plugin entry script not found: $($chosenEntryPoint.Path)"
                    continue
                }

                Write-Host "Launching $($selectedPlugin.Name) [$($chosenEntryPoint.Name)]..." -ForegroundColor Green
                try {
                    Start-PluginEntry -EntryPath $chosenEntryPoint.Path -WorkingDirectory $selectedPlugin.Directory -Platform $osInfo.Platform
                    return $true
                }
                catch {
                    Show-ErrorMessage -Message "ERROR: Failed to run plugin."
                    Write-Host $_.Exception.Message -ForegroundColor Yellow
                    Write-Host "Returning to the main menu..." -ForegroundColor Yellow
                    return $false
                }
            }
        }

        Write-Host "Invalid choice. Enter a valid number or X." -ForegroundColor Red
    } while ($true)
}

function Show-MainMenu {
    param (
        [string]$Version
    )

    Clear-Host
    Write-Host "$iconReBlock" -ForegroundColor Red
    Write-Host "Welcome to ReBlock!" -ForegroundColor Red
    Write-Host "Version $Version" -ForegroundColor Yellow
    Write-Host "Created & Programmed by yourworstnightmare1"
    Write-Host "___________________________________________"
    Write-Host ""
    Write-Host "Choose an option:" -ForegroundColor Cyan
    Write-Host "[1] Select a Plugin"
    Write-Host "[2] Go to ReBlock website"
    Write-Host "[3] Go to GitHub"
    Write-Host "[4] Exit"
    Write-Host ""
}

$pluginsRoot = Join-Path $appRoot "plugins"

do {
    Show-MainMenu -Version $appVersion
    $choice = Read-Host "Enter 1-4"
    switch ($choice) {
        "1" {
            $pluginLaunched = Show-PluginMenu -PluginRoot $pluginsRoot
            if ($pluginLaunched) {
                exit
            }
        }
        "2" {
            Start-Process "https://sites.google.com/view/reblock"
            Write-Host "Opened website in your browser." -ForegroundColor Green
        }
        "3" {
            Start-Process "https://github.com/yourworstnightmare1/reblock"
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
 
