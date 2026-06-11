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

$settingsFile = Join-Path $appRoot "settings.txt"

$script:OfficialPluginCatalog = @(
    [PSCustomObject]@{ Name = "appUnblocker"; InstallUrl = "https://github.com/yourworstnightmare1/appunblocker/releases/latest" }
    [PSCustomObject]@{ Name = "packageExpander"; InstallUrl = "https://github.com/yourworstnightmare1/packageExpander/releases/latest" }
    [PSCustomObject]@{ Name = "packageSpoofer"; InstallUrl = "https://github.com/yourworstnightmare1/packageSpoofer/releases/latest" }
    [PSCustomObject]@{ Name = "hiddenfiles"; InstallUrl = $null }
)

function Get-ReBlockSettingDefaults {
    return @{
        showUnsupportedPlugins = "1"
        showNotInstalled = "0"
        allowPluginEditions = "1"
        showArtwork = "1"
        enableColor = "1"
        onlyLoadOfficialPlugins = "0"
        enableUnsupportedPluginUpdates = "0"
        enablePreReleasePluginUpdates = "0"
        reblockEnablePreReleasePluginUpdates = "0"
        reblockUpdaterUrl = "1"
    }
}

function Get-ReBlockSettings {
    param (
        [string]$SettingsPath
    )

    $settings = Get-ReBlockSettingDefaults
    if (-not (Test-Path $SettingsPath)) {
        return $settings
    }

    foreach ($line in Get-Content -Path $SettingsPath) {
        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -match '^\s*([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($settings.ContainsKey($key)) {
                $settings[$key] = $value
            }
        }
    }

    return $settings
}

function Save-SettingsFile {
    param (
        [string]$SettingsPath,
        [hashtable]$Settings
    )

    $lines = @()
    if (Test-Path $SettingsPath) {
        $lines = @(Get-Content -Path $SettingsPath)
    }

    $writtenKeys = @{}
    $output = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match '^\s*([^=#\s]+)=(.*)$') {
            $key = $matches[1].Trim()
            if ($Settings.ContainsKey($key)) {
                $null = $output.Add("$key=$($Settings[$key])")
                $writtenKeys[$key] = $true
                continue
            }
        }

        $null = $output.Add($line)
    }

    foreach ($key in $Settings.Keys) {
        if (-not $writtenKeys.ContainsKey($key)) {
            $null = $output.Add("$key=$($Settings[$key])")
        }
    }

    $output | Set-Content -Path $SettingsPath -Encoding UTF8
}

function Save-ReBlockSettings {
    param (
        [string]$SettingsPath,
        [hashtable]$Settings
    )

    Save-SettingsFile -SettingsPath $SettingsPath -Settings $Settings
}

function Get-PluginSettingsApiDefaults {
    return @{
        enablePreReleasePluginUpdates = "0"
        updaterUrlStable = ""
        updaterUrlCanary = ""
        enableNetworkAccess = "2"
        enableFileAccess = "1"
        enableRootAccess = "0"
        forcePlatformCompatibility = "0"
    }
}

function Get-PluginSettingsDefaults {
    param (
        [string]$PluginName
    )

    $defaults = Get-PluginSettingsApiDefaults

    switch ($PluginName) {
        "appUnblocker" {
            $defaults.skipConfirmation = "0"
            $defaults.skipBanner = "0"
            $defaults.autoLaunch = "1"
            $defaults.macMethod = "1"
            $defaults.updaterUrlStable = "https://api.github.com/repos/yourworstnightmare1/appUnblocker/releases/latest"
            $defaults.updaterUrlCanary = "https://api.github.com/repos/yourworstnightmare1/appUnblocker/releases"
        }
        "hiddenFiles" {
            $defaults.showPluginBanner = "1"
            $defaults.restartExplorer = "1"
        }
        "packageExpander" {
            $defaults.defaultMethod = "1"
            $defaults.updaterUrlStable = "https://api.github.com/repos/yourworstnightmare1/packageExpander/releases/latest"
            $defaults.updaterUrlCanary = "https://api.github.com/repos/yourworstnightmare1/packageExpander/releases"
        }
        "packageSpoofer" {
            $defaults.defaultBinaryPatch = "0"
            $defaults.updaterUrlStable = "https://api.github.com/repos/yourworstnightmare1/packageSpoofer/releases/latest"
            $defaults.updaterUrlCanary = "https://api.github.com/repos/yourworstnightmare1/packageSpoofer/releases"
        }
    }

    return $defaults
}

function Get-PluginSettingType {
    param (
        [string]$Key
    )

    switch ($Key) {
        "enableNetworkAccess" { return "AccessLevel" }
        "enableFileAccess" { return "AccessLevel" }
        "enableRootAccess" { return "RootAccess" }
        "forcePlatformCompatibility" { return "ForcePlatform" }
        "updaterUrlStable" { return "Url" }
        "updaterUrlCanary" { return "Url" }
        "macMethod" { return "MacMethod" }
        "defaultMethod" { return "DefaultMethod" }
        "enablePreReleasePluginUpdates" { return "Toggle" }
        default { return "Toggle" }
    }
}

function Get-PluginSettingTitle {
    param (
        [string]$Key
    )

    switch ($Key) {
        "skipConfirmation" { return "Skip confirmation" }
        "skipBanner" { return "Skip banner" }
        "autoLaunch" { return "Auto-launch target app" }
        "macMethod" { return "Default macOS method" }
        "showPluginBanner" { return "Show plugin banner" }
        "restartExplorer" { return "Restart Explorer after changes" }
        "defaultMethod" { return "Default extraction method" }
        "defaultBinaryPatch" { return "Apply binary patch by default" }
        "enablePreReleasePluginUpdates" { return "Use pre-release updates" }
        "enableNetworkAccess" { return "Network access" }
        "enableFileAccess" { return "File access outside plugin folder" }
        "enableRootAccess" { return "Administrator / elevated access" }
        "forcePlatformCompatibility" { return "Force platform compatibility" }
        default {
            $spaced = ($Key -creplace '([A-Z])', ' $1').Trim()
            if ($spaced.Length -gt 0) {
                return ($spaced.Substring(0, 1).ToUpper() + $spaced.Substring(1))
            }
            return $Key
        }
    }
}

function Parse-SettingsFile {
    param (
        [string]$SettingsPath,
        [hashtable]$DefaultValues = @{}
    )

    $values = @{}
    foreach ($key in $DefaultValues.Keys) {
        $values[$key] = [string]$DefaultValues[$key]
    }

    $entries = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path $SettingsPath)) {
        return @{
            SettingValues = $values
            SettingEntries = @($entries.ToArray())
        }
    }

    $lines = @(Get-Content -Path $SettingsPath)
    $currentSection = "Plugin"
    $index = 0

    while ($index -lt $lines.Count) {
        $line = $lines[$index]
        $index++

        if ($line -match '^\s*#\s*(Updater|Security|ReBlock)\s*$') {
            $currentSection = $matches[1]
            continue
        }

        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -notmatch '^\s*([^=]+)=(.*)$') {
            continue
        }

        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $values[$key] = $value

        $description = ""
        while ($index -lt $lines.Count) {
            $peek = $lines[$index]
            if ($peek -match '^\s*([^=]+)=(.*)$' -and $peek -notmatch '^\s*#') {
                break
            }
            if ($peek -match '^\s*#\s*(Updater|Security|ReBlock)\s*$') {
                break
            }
            if ($peek -match '^\s*#\s*(\d.+)$') {
                $index++
                continue
            }
            if ($peek -match '^\s*#\s*(.+)$') {
                $comment = $matches[1].Trim()
                if ($comment -notmatch '^(Plugin settings config|Settings config|Looking for)') {
                    if ([string]::IsNullOrWhiteSpace($description)) {
                        $description = $comment
                    }
                }
            }
            $index++
        }

        $type = Get-PluginSettingType -Key $key
        $null = $entries.Add([PSCustomObject]@{
            Section = $currentSection
            Key = $key
            Title = (Get-PluginSettingTitle -Key $key)
            Type = $type
            Description = $description
        })
    }

    return @{
        SettingValues = $values
        SettingEntries = @($entries.ToArray())
    }
}

function Get-PluginSettings {
    param (
        [object]$Plugin
    )

    $settingsPath = Join-Path $Plugin.Directory "settings.txt"
    $defaults = Get-PluginSettingsDefaults -PluginName $Plugin.Name
    $parsed = Parse-SettingsFile -SettingsPath $settingsPath -DefaultValues $defaults

    return @{
        Path = $settingsPath
        SettingValues = $parsed['SettingValues']
        SettingEntries = $parsed['SettingEntries']
    }
}

function Save-PluginSettings {
    param (
        [object]$Plugin,
        [hashtable]$Settings
    )

    $settingsPath = Join-Path $Plugin.Directory "settings.txt"
    Save-SettingsFile -SettingsPath $settingsPath -Settings $Settings
}

function Get-PluginSettingStatusLabel {
    param (
        [string]$Type,
        [string]$Value
    )

    switch ($Type) {
        "Toggle" {
            if (Test-ReBlockSettingEnabled -Value $Value) { return "Enabled" }
            return "Disabled"
        }
        "AccessLevel" {
            switch ($Value) {
                "0" { return "Disabled" }
                "1" { return "Enabled" }
                "2" { return "Ask on first time" }
                "3" { return "Ask each time" }
                default { return "Unknown ($Value)" }
            }
        }
        "RootAccess" {
            switch ($Value) {
                "0" { return "Disabled" }
                "1" { return "Enabled" }
                "2" { return "Ask on first time" }
                "3" { return "Ask each time" }
                "4" { return "Enabled using appUnblocker" }
                default { return "Unknown ($Value)" }
            }
        }
        "ForcePlatform" {
            switch ($Value) {
                "0" { return "Disabled" }
                "1" { return "Force Windows" }
                "2" { return "Force macOS" }
                default { return "Unknown ($Value)" }
            }
        }
        "MacMethod" {
            switch ($Value) {
                "1" { return "Folder Manipulation" }
                "2" { return "Gatekeeper Bypass" }
                "3" { return "Both" }
                default { return "Unknown ($Value)" }
            }
        }
        "DefaultMethod" {
            switch ($Value) {
                "1" { return "Payload Extraction" }
                "2" { return "Package Extraction" }
                default { return "Unknown ($Value)" }
            }
        }
        default { return $Value }
    }
}

function Get-PluginSettingStatusColor {
    param (
        [string]$Type,
        [string]$Value
    )

    switch ($Type) {
        "Toggle" {
            if (Test-ReBlockSettingEnabled -Value $Value) { return "Green" }
            return "Red"
        }
        "AccessLevel" {
            switch ($Value) {
                "0" { return "Red" }
                "1" { return "Green" }
                default { return "Yellow" }
            }
        }
        "RootAccess" {
            switch ($Value) {
                "0" { return "Red" }
                "1" { return "Green" }
                "4" { return "Green" }
                default { return "Yellow" }
            }
        }
        "ForcePlatform" {
            if ($Value -eq "0") { return "Red" }
            return "Green"
        }
        default { return "Cyan" }
    }
}

function Write-PluginSettingMenuEntry {
    param (
        [string]$Number,
        [object]$Entry,
        [string]$Value
    )

    Write-Host -NoNewline "[$Number] $($Entry.Title): "
    $label = Get-PluginSettingStatusLabel -Type $Entry.Type -Value $Value
    $color = Get-PluginSettingStatusColor -Type $Entry.Type -Value $Value
    Write-Host $label -ForegroundColor $color
    if (-not [string]::IsNullOrWhiteSpace($Entry.Description)) {
        Write-Host "    $($Entry.Description)" -ForegroundColor DarkGray
    }
}

function Invoke-PluginSettingCycle {
    param (
        [object]$Entry,
        [string]$CurrentValue
    )

    switch ($Entry.Type) {
        "Toggle" {
            return if (Test-ReBlockSettingEnabled -Value $CurrentValue) { "0" } else { "1" }
        }
        "AccessLevel" {
            $next = [int]$CurrentValue + 1
            if ($next -gt 3 -or $CurrentValue -notmatch '^\d+$') { return "0" }
            return [string]$next
        }
        "RootAccess" {
            $next = [int]$CurrentValue + 1
            if ($next -gt 4 -or $CurrentValue -notmatch '^\d+$') { return "0" }
            return [string]$next
        }
        "ForcePlatform" {
            $next = [int]$CurrentValue + 1
            if ($next -gt 2 -or $CurrentValue -notmatch '^\d+$') { return "0" }
            return [string]$next
        }
        "MacMethod" {
            $next = [int]$CurrentValue + 1
            if ($next -gt 3 -or $CurrentValue -notmatch '^\d+$') { return "1" }
            return [string]$next
        }
        "DefaultMethod" {
            return if ($CurrentValue -eq "1") { "2" } else { "1" }
        }
        default {
            return if (Test-ReBlockSettingEnabled -Value $CurrentValue) { "0" } else { "1" }
        }
    }
}

function Show-PluginSettingsMenu {
    param (
        [object]$Plugin
    )

    $pluginSettings = Get-PluginSettings -Plugin $Plugin
    $values = $pluginSettings['SettingValues']

    do {
        Clear-Host
        Write-ReBlockHost -Message "$($Plugin.Name) Settings" -Color "Red"
        Write-Host "Values are saved to settings.txt in the plugin folder"
        Write-Host "___________________________________________"
        Write-Host ""

        $currentSection = $null
        $menuMap = @{}
        $menuNumber = 1

        foreach ($entry in $pluginSettings['SettingEntries']) {
            if ($entry.Section -ne $currentSection) {
                if ($null -ne $currentSection) {
                    Write-Host ""
                }
                Write-ReBlockHost -Message $entry.Section -Color "Cyan"
                $currentSection = $entry.Section
            }

            $value = $values[$entry.Key]
            if ($entry.Type -eq "Url") {
                Write-Host "    $($entry.Title): $value" -ForegroundColor DarkGray
                if (-not [string]::IsNullOrWhiteSpace($entry.Description)) {
                    Write-Host "    $($entry.Description)" -ForegroundColor DarkGray
                }
                Write-Host ""
                continue
            }

            Write-PluginSettingMenuEntry -Number ([string]$menuNumber) -Entry $entry -Value $value
            $menuMap[[string]$menuNumber] = $entry
            $menuNumber++
            Write-Host ""
        }

        Write-Host "[X] Back"
        Write-Host ""
        $choice = Read-Host "Choose setting to change (1-$($menuNumber - 1)) or X"
        if ($choice -eq "X" -or $choice -eq "x") {
            return
        }

        if ($menuMap.ContainsKey($choice)) {
            $entry = $menuMap[$choice]
            $values[$entry.Key] = Invoke-PluginSettingCycle -Entry $entry -CurrentValue $values[$entry.Key]
            Save-PluginSettings -Plugin $Plugin -Settings $values
            Write-ReBlockHost -Message "Setting saved." -Color "Green"
            Start-Sleep -Milliseconds 400
        }
        else {
            Write-ReBlockHost -Message "Invalid choice." -Color "Red"
            $null = Read-Host "Press Enter to continue"
        }
    } while ($true)
}

function Test-PermissionPromptAllowed {
    param (
        [string]$Response
    )

    $normalized = $Response.Trim().ToLowerInvariant()
    return $normalized -in @("y", "yes", "1")
}

function Wait-MenuContinue {
    param (
        [string]$Message = "Press Enter to continue..."
    )

    Write-Host ""
    $null = Read-Host $Message
}

function Get-PluginPermissionValue {
    param (
        [hashtable]$Settings,
        [string]$Key,
        [string]$Default = "1"
    )

    if ($null -eq $Settings) {
        return $Default
    }

    if (-not $Settings.ContainsKey($Key)) {
        return $Default
    }

    $value = [string]$Settings[$Key]
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return $value.Trim()
}

function Resolve-PluginPermission {
    param (
        [string]$PluginName,
        [string]$PermissionName,
        [string]$Value,
        [string]$Description,
        [switch]$PersistOnFirstAllow,
        [switch]$ConfirmLaunch
    )

    $normalizedValue = if ([string]::IsNullOrWhiteSpace($Value)) { "1" } else { $Value.Trim() }

    switch ($normalizedValue) {
        "0" { return $false }
        "1" { return $true }
        "2" {
            if ($ConfirmLaunch) {
                if ($PersistOnFirstAllow) {
                    return "persist-allow"
                }
                return $true
            }

            $prompt = Read-Host "$PluginName needs $PermissionName. $Description Allow? (Y/N/1)"
            $allowed = Test-PermissionPromptAllowed -Response $prompt
            if ($allowed -and $PersistOnFirstAllow) {
                return "persist-allow"
            }
            return $allowed
        }
        "3" {
            if ($ConfirmLaunch) {
                return $true
            }

            $prompt = Read-Host "$PluginName needs $PermissionName. $Description Allow? (Y/N/1)"
            return (Test-PermissionPromptAllowed -Response $prompt)
        }
        default { return $false }
    }
}

function Test-PluginLaunchPermissions {
    param (
        [object]$Plugin,
        [hashtable]$Settings,
        [switch]$ConfirmLaunch
    )

    if ($null -eq $Settings) {
        $Settings = (Get-PluginSettings -Plugin $Plugin)['SettingValues']
    }

    $network = Resolve-PluginPermission `
        -PluginName $Plugin.Name `
        -PermissionName "network access" `
        -Value (Get-PluginPermissionValue -Settings $Settings -Key "enableNetworkAccess" -Default "2") `
        -Description "This lets the plugin reach update servers or online resources." `
        -PersistOnFirstAllow `
        -ConfirmLaunch:$ConfirmLaunch
    if ($network -eq "persist-allow") {
        $Settings['enableNetworkAccess'] = "1"
        Save-PluginSettings -Plugin $Plugin -Settings $Settings
        $network = $true
    }
    if (-not $network) {
        Show-ErrorMessage -Message "ERROR: Plugin launch blocked by network access settings. Enable it in Plugin settings if this plugin needs network access."
        return $false
    }

    $fileAccess = Resolve-PluginPermission `
        -PluginName $Plugin.Name `
        -PermissionName "file access outside its folder" `
        -Value (Get-PluginPermissionValue -Settings $Settings -Key "enableFileAccess" -Default "1") `
        -Description "This plugin needs to read or modify files outside its own directory." `
        -PersistOnFirstAllow `
        -ConfirmLaunch:$ConfirmLaunch
    if ($fileAccess -eq "persist-allow") {
        $Settings['enableFileAccess'] = "1"
        Save-PluginSettings -Plugin $Plugin -Settings $Settings
        $fileAccess = $true
    }
    if (-not $fileAccess) {
        Show-ErrorMessage -Message "ERROR: Plugin launch blocked by file access settings. Enable it in Plugin settings if this plugin needs file access."
        return $false
    }

    $rootAccessValue = Get-PluginPermissionValue -Settings $Settings -Key "enableRootAccess" -Default "0"
    if ($rootAccessValue -in @("2", "3")) {
        $rootAccess = Resolve-PluginPermission `
            -PluginName $Plugin.Name `
            -PermissionName "administrator / elevated access" `
            -Value $rootAccessValue `
            -Description "This plugin may need elevated permissions to complete its task." `
            -PersistOnFirstAllow:($rootAccessValue -eq "2") `
            -ConfirmLaunch:$ConfirmLaunch
        if ($rootAccess -eq "persist-allow") {
            $Settings['enableRootAccess'] = "1"
            Save-PluginSettings -Plugin $Plugin -Settings $Settings
        }
        elseif (-not $rootAccess) {
            Show-ErrorMessage -Message "ERROR: Plugin launch blocked by administrator access settings."
            return $false
        }
    }

    return $true
}

function Get-PluginLaunchArguments {
    param (
        [object]$Plugin,
        [hashtable]$Settings
    )

    $arguments = @{}

    switch ($Plugin.Name) {
        "appUnblocker" {
            if (Test-ReBlockSettingEnabled -Value $Settings.skipConfirmation) { $arguments["NoConfirm"] = $true }
            if (Test-ReBlockSettingEnabled -Value $Settings.skipBanner) { $arguments["SkipBanner"] = $true }
            if (-not (Test-ReBlockSettingEnabled -Value $Settings.autoLaunch)) { $arguments["NoLaunch"] = $true }
            $macMethod = switch ($Settings.macMethod) {
                "2" { "Gatekeeper" }
                "3" { "Both" }
                default { "Folder" }
            }
            $arguments["MacMethod"] = $macMethod
        }
    }

    return $arguments
}

function Test-PluginOsSupportedWithSettings {
    param (
        [object]$Plugin,
        [object]$OsInfo,
        [hashtable]$Settings
    )

    if ($null -ne $Settings) {
        if ($Settings.forcePlatformCompatibility -eq "1" -and $OsInfo.Platform -eq "Windows") {
            return $true
        }
        if ($Settings.forcePlatformCompatibility -eq "2" -and $OsInfo.Platform -eq "macOS") {
            return $true
        }
    }

    return Test-PluginOsSupported -Plugin $Plugin -OsInfo $OsInfo
}

function Test-ReBlockSettingEnabled {
    param (
        [string]$Value
    )

    return $Value -eq "1"
}

function Get-ReBlockArtwork {
    param (
        [string]$Artwork
    )

    if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.showArtwork) {
        return $Artwork
    }

    return ""
}

function Write-ReBlockHost {
    param (
        [string]$Message,
        [string]$Color,
        [switch]$NoNewline
    )

    $useColor = Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.enableColor
    if ($useColor -and -not [string]::IsNullOrWhiteSpace($Color)) {
        if ($NoNewline) {
            Write-Host $Message -ForegroundColor $Color -NoNewline
        }
        else {
            Write-Host $Message -ForegroundColor $Color
        }
        return
    }

    if ($NoNewline) {
        Write-Host $Message -NoNewline
    }
    else {
        Write-Host $Message
    }
}

function Get-ReBlockUpdaterUrlLabel {
    param (
        [string]$Value
    )

    switch ($Value) {
        "0" { return "Disabled" }
        "1" { return "GitHub" }
        "2" { return "ReBlock API" }
        default { return "Unknown ($Value)" }
    }
}

function Get-ReBlockSettingMenuEntries {
    return @(
        [PSCustomObject]@{
            Number = "1"
            Section = "ReBlock"
            Title = "Show unsupported plugins"
            Key = "showUnsupportedPlugins"
            Type = "Toggle"
            Description = "Shows plugins that are not supported on the current system."
        }
        [PSCustomObject]@{
            Number = "2"
            Section = "ReBlock"
            Title = "Show not installed plugins"
            Key = "showNotInstalled"
            Type = "Toggle"
            Description = "Shows official ReBlock plugins, even when they are not currently installed. They will be labeled as [Not Installed] and you will be asked to install."
        }
        [PSCustomObject]@{
            Number = "3"
            Section = "ReBlock"
            Title = "Allow plugin editions (CLI/GUI)"
            Key = "allowPluginEditions"
            Type = "Toggle"
            Description = "Enables both CLI and GUI editions of a plugin to be chosen when it is available for that specific plugin."
        }
        [PSCustomObject]@{
            Number = "4"
            Section = "ReBlock"
            Title = "Show ASCII artwork"
            Key = "showArtwork"
            Type = "Toggle"
            Description = "Enables ASCII artwork. If you're on a low end device, disabling this may improve performance."
        }
        [PSCustomObject]@{
            Number = "5"
            Section = "ReBlock"
            Title = "Enable colors"
            Key = "enableColor"
            Type = "Toggle"
            Description = "Gives color to all text and art."
        }
        [PSCustomObject]@{
            Number = "6"
            Section = "ReBlock"
            Title = "Only load official plugins"
            Key = "onlyLoadOfficialPlugins"
            Type = "Toggle"
            Description = 'Only allows plugins from author "yourworstnightmare1" to be detected by ReBlock.'
        }
        [PSCustomObject]@{
            Number = "7"
            Section = "Updater"
            Title = "Check unsupported plugins for updates"
            Key = "enableUnsupportedPluginUpdates"
            Type = "Toggle"
            Description = "Will check unsupported plugins for updates even though they can't be used on your system."
        }
        [PSCustomObject]@{
            Number = "8"
            Section = "Updater"
            Title = "Use pre-release plugin updates"
            Key = "enablePreReleasePluginUpdates"
            Type = "Toggle"
            Description = "Will use the plugin's pre-release updater URL instead of the stable one."
        }
        [PSCustomObject]@{
            Number = "9"
            Section = "Updater"
            Title = "Use pre-release ReBlock updates"
            Key = "reblockEnablePreReleasePluginUpdates"
            Type = "Toggle"
            Description = "Will update ReBlock using pre-release versions instead of stable versions."
        }
        [PSCustomObject]@{
            Number = "10"
            Section = "Updater"
            Title = "Update server"
            Key = "reblockUpdaterUrl"
            Type = "UpdaterUrl"
            Description = "Decides the update server used to update ReBlock."
        }
    )
}

function Write-SettingStatusLabel {
    param (
        [string]$Value,
        [ValidateSet("Toggle", "UpdaterUrl")]
        [string]$Type = "Toggle"
    )

    if ($Type -eq "UpdaterUrl") {
        $label = Get-ReBlockUpdaterUrlLabel -Value $Value
        $color = if ($Value -eq "0") { "Red" } else { "Green" }
        Write-Host $label -ForegroundColor $color -NoNewline
        return
    }

    if (Test-ReBlockSettingEnabled -Value $Value) {
        Write-Host "Enabled" -ForegroundColor Green -NoNewline
    }
    else {
        Write-Host "Disabled" -ForegroundColor Red -NoNewline
    }
}

function Write-SettingMenuEntry {
    param (
        [string]$Number,
        [string]$Title,
        [string]$Value,
        [string]$Description,
        [ValidateSet("Toggle", "UpdaterUrl")]
        [string]$Type = "Toggle"
    )

    Write-Host -NoNewline "[$Number] ${Title}: "
    Write-SettingStatusLabel -Value $Value -Type $Type
    Write-Host ""
    Write-Host "    $Description" -ForegroundColor DarkGray
}

$script:ReBlockSettings = Get-ReBlockSettings -SettingsPath $settingsFile

Write-Host "Initalizing..." -ForegroundColor Yellow

function Test-PluginEntryPointAvailable {
    param (
        [string]$EntryPath,
        [object]$OsInfo
    )

    if ([string]::IsNullOrWhiteSpace($EntryPath) -or -not (Test-Path -LiteralPath $EntryPath)) {
        return $false
    }

    if ($EntryPath -match '\.app$') {
        return $OsInfo.Platform -eq "macOS"
    }

    if ($EntryPath -match '\.(exe|msi)$') {
        return $OsInfo.Platform -eq "Windows"
    }

    return $true
}

function Get-PluginMetadata {
    param (
        [string]$PluginRoot
    )

    if (-not (Test-Path $PluginRoot)) {
        return @()
    }

    $pluginFiles = Get-ChildItem -Path $PluginRoot -Filter "plugin.xml" -Recurse -File
    $plugins = @()
    $osInfo = Get-CurrentOsInfo

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
                        $entryPath = Join-Path $pluginFile.DirectoryName ([string]$entry.path)
                        if (-not (Test-PluginEntryPointAvailable -EntryPath $entryPath -OsInfo $osInfo)) {
                            continue
                        }

                        $entryPoints += [PSCustomObject]@{
                            Name = $entryName
                            Path = $entryPath
                        }
                    }
                }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($xml.plugin.entryScript)) {
                $legacyEntryPath = Join-Path $pluginFile.DirectoryName ([string]$xml.plugin.entryScript)
                if (Test-PluginEntryPointAvailable -EntryPath $legacyEntryPath -OsInfo $osInfo) {
                    $entryPoints += [PSCustomObject]@{
                        Name = "Default"
                        Path = $legacyEntryPath
                    }
                }
            }

            if ($entryPoints.Count -eq 0) {
                Write-Host "Skipping plugin without entryScript or entryPoints: $($pluginFile.FullName)" -ForegroundColor Yellow
                continue
            }

            $author = if ($xml.plugin.author) { $xml.plugin.author } else { "unknown" }
            if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.onlyLoadOfficialPlugins) {
                if ($author -ne "yourworstnightmare1") {
                    continue
                }
            }

            $plugins += [PSCustomObject]@{
                Name = if ($xml.plugin.name) { $xml.plugin.name } else { Split-Path $pluginFile.DirectoryName -Leaf }
                Version = if ($xml.plugin.version) { $xml.plugin.version } else { "unknown" }
                Description = if ($xml.plugin.description) { $xml.plugin.description } else { "No description" }
                Author = $author
                MinWindowsVer = if ($xml.plugin.minWindowsVer) { $xml.plugin.minWindowsVer } else { "any" }
                MinMacOSVer = if ($xml.plugin.minMacOSVer) { $xml.plugin.minMacOSVer } else { "any" }
                EntryPoints = $entryPoints
                Directory = $pluginFile.DirectoryName
                Installed = $true
                InstallUrl = $null
            }
        }
        catch {
            Write-ReBlockHost -Message "Failed to parse plugin XML: $($pluginFile.FullName)" -Color "Red"
        }
    }

    return $plugins
}

function Test-PluginOsSupported {
    param (
        [object]$Plugin,
        [object]$OsInfo
    )

    if ($OsInfo.Platform -eq "Unknown") {
        return $false
    }

    $requiredVersionText = if ($OsInfo.Platform -eq "Windows") {
        $Plugin.MinWindowsVer
    }
    else {
        $Plugin.MinMacOSVer
    }

    if (Test-IsUnsupportedMarker -Value $requiredVersionText) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($requiredVersionText) -or $requiredVersionText -eq "any") {
        return $true
    }

    $requiredVersion = Convert-ToComparableVersion -VersionText $requiredVersionText
    if ($null -eq $requiredVersion -or $null -eq $OsInfo.VersionObj) {
        return $false
    }

    return $OsInfo.VersionObj -ge $requiredVersion
}

function Get-PluginMenuItems {
    param (
        [string]$PluginRoot
    )

    $plugins = @(Get-PluginMetadata -PluginRoot $PluginRoot)
    $osInfo = Get-CurrentOsInfo
    $menuItems = @()

    foreach ($plugin in $plugins) {
        $supported = Test-PluginOsSupported -Plugin $plugin -OsInfo $osInfo
        if (-not $supported -and -not (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.showUnsupportedPlugins)) {
            continue
        }

        $menuItems += [PSCustomObject]@{
            Plugin = $plugin
            Supported = $supported
            LabelSuffix = if ($supported) { "" } else { " [Unsupported]" }
        }
    }

    if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.showNotInstalled) {
        $installedNames = @($plugins | ForEach-Object { $_.Name })
        foreach ($catalogEntry in $script:OfficialPluginCatalog) {
            if ($installedNames -contains $catalogEntry.Name) {
                continue
            }

            $menuItems += [PSCustomObject]@{
                Plugin = [PSCustomObject]@{
                    Name = $catalogEntry.Name
                    Version = "unknown"
                    Description = "Official ReBlock plugin (not installed)"
                    Author = "yourworstnightmare1"
                    MinWindowsVer = "any"
                    MinMacOSVer = "any"
                    EntryPoints = @()
                    Directory = $null
                    Installed = $false
                    InstallUrl = $catalogEntry.InstallUrl
                }
                Supported = $false
                LabelSuffix = " [Not Installed]"
            }
        }
    }

    return @($menuItems)
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
    $errorArt = Get-ReBlockArtwork -Artwork $iconError
    if (-not [string]::IsNullOrWhiteSpace($errorArt)) {
        Write-ReBlockHost -Message $errorArt -Color "Red"
    }
    Write-ReBlockHost -Message $Message -Color "Red"
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

    if (-not (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.allowPluginEditions)) {
        return $entryPoints[0]
    }

    Write-Host ""
    Write-ReBlockHost -Message "Choose launch mode for $($Plugin.Name):" -Color "Cyan"
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
        [string]$Platform,
        [object]$Plugin = $null,
        [hashtable]$PluginSettings = $null,
        [hashtable]$ExtraArguments = @{}
    )

    $previousLocation = Get-Location
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory) -and (Test-Path $WorkingDirectory)) {
        Set-Location $WorkingDirectory
    }

    $useRunAsInvoker = $false
    if ($null -ne $PluginSettings) {
        $rootAccess = $PluginSettings['enableRootAccess']
        if ($rootAccess -eq "1" -or $rootAccess -eq "4") {
            $useRunAsInvoker = $true
        }
    }

    $env:REBLOCK_PLUGIN_DIR = $WorkingDirectory
    $env:REBLOCK_PLUGIN_NAME = if ($null -ne $Plugin) { $Plugin.Name } else { "" }

    $entryWorkingDirectory = Split-Path -Parent $EntryPath
    if ([string]::IsNullOrWhiteSpace($entryWorkingDirectory) -or -not (Test-Path -LiteralPath $entryWorkingDirectory)) {
        $entryWorkingDirectory = $WorkingDirectory
    }

    try {
    if ($Platform -eq "Windows") {
        if ($EntryPath -match "\.ps1$") {
            # Run in current PowerShell instance to keep a single window.
            if ($useRunAsInvoker) {
                $env:__COMPAT_LAYER = "RunAsInvoker"
            }
            try {
                if ($ExtraArguments.Count -gt 0) {
                    & $EntryPath @ExtraArguments
                }
                else {
                    & $EntryPath
                }
                if (-not $?) {
                    throw "Plugin PowerShell script failed: $EntryPath"
                }
            }
            finally {
                Remove-Item Env:__COMPAT_LAYER -ErrorAction SilentlyContinue
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

        Start-Process -FilePath $EntryPath -WorkingDirectory $entryWorkingDirectory
        return
    }

    if ($Platform -eq "macOS") {
        if ($EntryPath -match "\.app$") {
            Start-Process -FilePath "open" -ArgumentList @("`"$EntryPath`"") -WorkingDirectory $entryWorkingDirectory
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

        Start-Process -FilePath $EntryPath -WorkingDirectory $entryWorkingDirectory
        return
    }

    if ($EntryPath -match "\.ps1$") {
        if ($useRunAsInvoker) {
            $env:__COMPAT_LAYER = "RunAsInvoker"
        }
        try {
            if ($ExtraArguments.Count -gt 0) {
                & $EntryPath @ExtraArguments
            }
            else {
                & $EntryPath
            }
            if (-not $?) {
                throw "Plugin PowerShell script failed: $EntryPath"
            }
        }
        finally {
            Remove-Item Env:__COMPAT_LAYER -ErrorAction SilentlyContinue
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

    if ($useRunAsInvoker) {
        $env:__COMPAT_LAYER = "RunAsInvoker"
        try {
            Start-Process -FilePath $EntryPath -WorkingDirectory $entryWorkingDirectory
        }
        finally {
            Remove-Item Env:__COMPAT_LAYER -ErrorAction SilentlyContinue
        }
    }
    else {
        Start-Process -FilePath $EntryPath -WorkingDirectory $entryWorkingDirectory
    }
    }
    finally {
        Remove-Item Env:REBLOCK_PLUGIN_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:REBLOCK_PLUGIN_NAME -ErrorAction SilentlyContinue
        Set-Location $previousLocation
    }
}

function Show-PluginActionMenu {
    param (
        [object]$Plugin,
        [hashtable]$Settings
    )

    do {
        Clear-Host
        Write-ReBlockHost -Message $Plugin.Name -Color "Red"
        Write-Host "$($Plugin.Description)"
        Write-Host ""
        Write-Host "[1] Launch"
        Write-Host "[2] Plugin settings"
        Write-Host "[X] Back"
        Write-Host ""
        $action = (Read-Host "Choose an option").Trim()

        switch ($action) {
            "1" {
                if (-not (Test-PluginLaunchPermissions -Plugin $Plugin -Settings $Settings -ConfirmLaunch)) {
                    Wait-MenuContinue
                    break
                }
                return "Launch"
            }
            "2" {
                Show-PluginSettingsMenu -Plugin $Plugin
            }
            "X" { return "Back" }
            "x" { return "Back" }
            default {
                Write-ReBlockHost -Message "Invalid choice. Enter 1, 2, or X." -Color "Red"
                Wait-MenuContinue
            }
        }
    } while ($true)
}

function Show-NotInstalledPluginPrompt {
    param (
        [object]$Plugin
    )

    Write-Host ""
    Write-ReBlockHost -Message "$($Plugin.Name) is not installed." -Color "Yellow"

    if ([string]::IsNullOrWhiteSpace($Plugin.InstallUrl)) {
        Write-ReBlockHost -Message "This plugin is not available for download yet." -Color "Yellow"
        return
    }

    $installChoice = Read-Host "Open the download page in your browser? (Y/N)"
    if ($installChoice -eq "Y" -or $installChoice -eq "y") {
        Start-Process $Plugin.InstallUrl
        Write-ReBlockHost -Message "Opened download page in your browser." -Color "Green"
    }
}

function Write-PluginSelectionMenu {
    param (
        [object[]]$MenuItems
    )

    Clear-Host
    Write-Host ""
    Write-ReBlockHost -Message "Available plugins:" -Color "Cyan"
    for ($i = 0; $i -lt $MenuItems.Count; $i++) {
        $item = $MenuItems[$i]
        $plugin = $item.Plugin
        Write-Host "[$($i + 1)] $($plugin.Name) ($($plugin.Version))$($item.LabelSuffix) - $($plugin.Description)"
        Write-ReBlockHost -Message "    Author: $($plugin.Author) | Min Windows: $($plugin.MinWindowsVer) | Min macOS: $($plugin.MinMacOSVer)" -Color "DarkGray"
    }
    Write-Host "[X] Back"
    Write-Host ""
}

function Show-PluginMenu {
    param (
        [string]$PluginRoot
    )

    $menuItems = @(Get-PluginMenuItems -PluginRoot $PluginRoot)
    if ($menuItems.Count -eq 0) {
        Clear-Host
        Write-ReBlockHost -Message "No plugins available in $PluginRoot" -Color "Yellow"
        Write-ReBlockHost -Message "Try enabling unsupported or not-installed plugins in Settings." -Color "DarkGray"
        return $false
    }

    do {
        Write-PluginSelectionMenu -MenuItems $menuItems
        $selection = (Read-Host "Choose plugin number").Trim()

        if ($selection -eq "X" -or $selection -eq "x") {
            return $false
        }

        if ($selection -match "^\d+$") {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $menuItems.Count) {
                $selectedItem = $menuItems[$index]
                $selectedPlugin = $selectedItem.Plugin

                if (-not $selectedPlugin.Installed) {
                    Show-NotInstalledPluginPrompt -Plugin $selectedPlugin
                    Wait-MenuContinue
                    continue
                }

                $osInfo = Get-CurrentOsInfo
                if ($osInfo.Platform -eq "Unknown") {
                    Show-ErrorMessage -Message "ERROR: Plugin cannot be launched because your OS is unsupported."
                    Write-ReBlockHost -Message "This plugin system currently supports Windows and macOS only." -Color "Yellow"
                    Wait-MenuContinue
                    continue
                }

                $pluginSettingsData = Get-PluginSettings -Plugin $selectedPlugin
                $pluginSettings = $pluginSettingsData['SettingValues']

                if (-not (Test-PluginOsSupportedWithSettings -Plugin $selectedPlugin -OsInfo $osInfo -Settings $pluginSettings)) {
                    Show-ErrorMessage -Message "ERROR: Plugin cannot be launched because the OS is unsupported."
                    $requiredVersionText = if ($osInfo.Platform -eq "Windows") {
                        $selectedPlugin.MinWindowsVer
                    }
                    else {
                        $selectedPlugin.MinMacOSVer
                    }
                    Write-ReBlockHost -Message "Required $($osInfo.Platform): $requiredVersionText | Current: $($osInfo.VersionText)" -Color "Yellow"
                    Wait-MenuContinue
                    continue
                }

                $action = Show-PluginActionMenu -Plugin $selectedPlugin -Settings $pluginSettings
                if ($action -ne "Launch") {
                    continue
                }

                $chosenEntryPoint = Select-PluginEntryPoint -Plugin $selectedPlugin
                if ($null -eq $chosenEntryPoint) {
                    continue
                }

                if (-not (Test-Path $chosenEntryPoint.Path)) {
                    Show-ErrorMessage -Message "Plugin entry script not found: $($chosenEntryPoint.Path)"
                    Wait-MenuContinue
                    continue
                }

                $launchArgs = Get-PluginLaunchArguments -Plugin $selectedPlugin -Settings $pluginSettings
                Write-ReBlockHost -Message "Launching $($selectedPlugin.Name) [$($chosenEntryPoint.Name)]..." -Color "Green"
                try {
                    Start-PluginEntry `
                        -EntryPath $chosenEntryPoint.Path `
                        -WorkingDirectory $selectedPlugin.Directory `
                        -Platform $osInfo.Platform `
                        -Plugin $selectedPlugin `
                        -PluginSettings $pluginSettings `
                        -ExtraArguments $launchArgs
                    return $true
                }
                catch {
                    Show-ErrorMessage -Message "ERROR: Failed to run plugin."
                    Write-ReBlockHost -Message $_.Exception.Message -Color "Yellow"
                    Write-ReBlockHost -Message "Returning to the main menu..." -Color "Yellow"
                    return $false
                }
            }
        }

        Write-ReBlockHost -Message "Invalid choice. Enter a valid number or X." -Color "Red"
        Wait-MenuContinue
    } while ($true)
}

function Show-SettingsMenu {
    param (
        [string]$SettingsPath
    )

    do {
        Clear-Host
        $menuArt = Get-ReBlockArtwork -Artwork $iconReBlock
        if (-not [string]::IsNullOrWhiteSpace($menuArt)) {
            Write-ReBlockHost -Message $menuArt -Color "Red"
        }
        Write-ReBlockHost -Message "ReBlock Settings" -Color "Red"
        Write-Host "Values are saved to settings.txt"
        Write-Host "___________________________________________"
        Write-Host ""

        $currentSection = $null
        foreach ($entry in Get-ReBlockSettingMenuEntries) {
            if ($entry.Section -ne $currentSection) {
                if ($null -ne $currentSection) {
                    Write-Host ""
                }

                Write-ReBlockHost -Message $entry.Section -Color "Cyan"
                $currentSection = $entry.Section
            }

            $value = $script:ReBlockSettings[$entry.Key]
            Write-SettingMenuEntry `
                -Number $entry.Number `
                -Title $entry.Title `
                -Value $value `
                -Description $entry.Description `
                -Type $entry.Type
            Write-Host ""
        }
        Write-Host "[X] Back"
        Write-Host ""

        $choice = Read-Host "Choose setting to toggle (1-10) or X"
        if ($choice -eq "X" -or $choice -eq "x") {
            return
        }

        $changed = $false
        switch ($choice) {
            "1" {
                $script:ReBlockSettings.showUnsupportedPlugins = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.showUnsupportedPlugins) { "0" } else { "1" }
                $changed = $true
            }
            "2" {
                $script:ReBlockSettings.showNotInstalled = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.showNotInstalled) { "0" } else { "1" }
                $changed = $true
            }
            "3" {
                $script:ReBlockSettings.allowPluginEditions = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.allowPluginEditions) { "0" } else { "1" }
                $changed = $true
            }
            "4" {
                $script:ReBlockSettings.showArtwork = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.showArtwork) { "0" } else { "1" }
                $changed = $true
            }
            "5" {
                $script:ReBlockSettings.enableColor = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.enableColor) { "0" } else { "1" }
                $changed = $true
            }
            "6" {
                $script:ReBlockSettings.onlyLoadOfficialPlugins = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.onlyLoadOfficialPlugins) { "0" } else { "1" }
                $changed = $true
            }
            "7" {
                $script:ReBlockSettings.enableUnsupportedPluginUpdates = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.enableUnsupportedPluginUpdates) { "0" } else { "1" }
                $changed = $true
            }
            "8" {
                $script:ReBlockSettings.enablePreReleasePluginUpdates = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.enablePreReleasePluginUpdates) { "0" } else { "1" }
                $changed = $true
            }
            "9" {
                $script:ReBlockSettings.reblockEnablePreReleasePluginUpdates = if (Test-ReBlockSettingEnabled -Value $script:ReBlockSettings.reblockEnablePreReleasePluginUpdates) { "0" } else { "1" }
                $changed = $true
            }
            "10" {
                $nextUrl = switch ($script:ReBlockSettings.reblockUpdaterUrl) {
                    "0" { "1" }
                    "1" { "2" }
                    default { "0" }
                }
                $script:ReBlockSettings.reblockUpdaterUrl = $nextUrl
                $changed = $true
            }
            default {
                Write-ReBlockHost -Message "Invalid choice. Enter 1-10 or X." -Color "Red"
                $null = Read-Host "Press Enter to continue"
            }
        }

        if ($changed) {
            Save-ReBlockSettings -SettingsPath $SettingsPath -Settings $script:ReBlockSettings
            Write-ReBlockHost -Message "Setting saved." -Color "Green"
            Start-Sleep -Milliseconds 400
        }
    } while ($true)
}

function Show-MainMenu {
    param (
        [string]$Version
    )

    Clear-Host
    $menuArt = Get-ReBlockArtwork -Artwork $iconReBlock
    if (-not [string]::IsNullOrWhiteSpace($menuArt)) {
        Write-ReBlockHost -Message $menuArt -Color "Red"
    }
    Write-ReBlockHost -Message "Welcome to ReBlock!" -Color "Red"
    Write-ReBlockHost -Message "Version $Version" -Color "Yellow"
    Write-Host "Created & Programmed by yourworstnightmare1"
    Write-Host "___________________________________________"
    Write-Host ""
    Write-ReBlockHost -Message "Choose an option:" -Color "Cyan"
    Write-Host "[1] Select a Plugin"
    Write-Host "[2] Go to ReBlock website"
    Write-Host "[3] Go to GitHub"
    Write-Host "[4] Settings"
    Write-Host "[5] Exit"
    Write-Host ""
}

$pluginsRoot = Join-Path $appRoot "plugins"

do {
    Show-MainMenu -Version $appVersion
    $choice = Read-Host "Enter 1-5"
    switch ($choice) {
        "1" {
            $pluginLaunched = Show-PluginMenu -PluginRoot $pluginsRoot
            if ($pluginLaunched) {
                exit
            }
        }
        "2" {
            Start-Process "https://sites.google.com/view/reblock"
            Write-ReBlockHost -Message "Opened website in your browser." -Color "Green"
        }
        "3" {
            Start-Process "https://github.com/yourworstnightmare1/reblock"
            Write-ReBlockHost -Message "Opened GitHub in your browser." -Color "Green"
        }
        "4" {
            Show-SettingsMenu -SettingsPath $settingsFile
        }
        "5" {
            Write-ReBlockHost -Message "Goodbye!" -Color "Yellow"
            exit
        }
        default {
            Write-ReBlockHost -Message "Invalid choice. Please enter 1, 2, 3, 4, or 5." -Color "Red"
        }
    }
} while ($true)
 
