function Test-PermissionPromptAllowed {
    param (
        [string]$Response
    )

    $normalized = $Response.Trim().ToLowerInvariant()
    return $normalized -in @('y', 'yes', '1')
}

function Get-PluginPermissionValue {
    param (
        [hashtable]$Settings,
        [string]$Key,
        [string]$Default = '1'
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
        [string]$SettingValue,
        [string]$Description,
        [switch]$PersistOnFirstAllow,
        [switch]$ConfirmLaunch,
        [switch]$SecurityDefaultsConfirmed
    )

    $normalizedValue = if ([string]::IsNullOrWhiteSpace($SettingValue)) { '1' } else { $SettingValue.Trim() }

    switch ($normalizedValue) {
        '0' { return $false }
        '1' { return $true }
        '2' {
            if ($SecurityDefaultsConfirmed) {
                return $true
            }
            if ($ConfirmLaunch) {
                if ($PersistOnFirstAllow) {
                    return 'persist-allow'
                }
                return $true
            }

            $promptMessage = '{0} needs {1}. {2} Allow? (Y/N/1)' -f $PluginName, $PermissionName, $Description
            $prompt = Read-Host $promptMessage
            $allowed = Test-PermissionPromptAllowed -Response $prompt
            if ($allowed -and $PersistOnFirstAllow) {
                return 'persist-allow'
            }
            return $allowed
        }
        '3' {
            if ($ConfirmLaunch) {
                return $true
            }

            $promptMessage = '{0} needs {1}. {2} Allow? (Y/N/1)' -f $PluginName, $PermissionName, $Description
            $prompt = Read-Host $promptMessage
            return (Test-PermissionPromptAllowed -Response $prompt)
        }
        default { return $false }
    }
}

function Test-PluginLaunchPermissions {
    param (
        [object]$Plugin,
        [hashtable]$Settings,
        [switch]$ConfirmLaunch,
        [switch]$SecurityDefaultsConfirmed
    )

    if ($null -eq $Settings) {
        $Settings = (Get-PluginSettings -Plugin $Plugin)['SettingValues']
    }

    $network = Resolve-PluginPermission -PluginName $Plugin.Name -PermissionName 'network access' -SettingValue (Get-PluginPermissionValue -Settings $Settings -Key 'enableNetworkAccess' -Default '2') -Description 'This lets the plugin reach update servers or online resources.' -PersistOnFirstAllow -ConfirmLaunch:$ConfirmLaunch -SecurityDefaultsConfirmed:$SecurityDefaultsConfirmed
    if ($network -eq 'persist-allow') {
        $Settings['enableNetworkAccess'] = '1'
        Save-PluginSettings -Plugin $Plugin -Settings $Settings
        $network = $true
    }
    if (-not $network) {
        Show-ErrorMessage -Message 'ERROR: Plugin launch blocked by network access settings. Enable it in Plugin settings if this plugin needs network access.'
        return $false
    }

    $fileAccess = Resolve-PluginPermission -PluginName $Plugin.Name -PermissionName 'file access outside its folder' -SettingValue (Get-PluginPermissionValue -Settings $Settings -Key 'enableFileAccess' -Default '1') -Description 'This plugin needs to read or modify files outside its own directory.' -PersistOnFirstAllow -ConfirmLaunch:$ConfirmLaunch -SecurityDefaultsConfirmed:$SecurityDefaultsConfirmed
    if ($fileAccess -eq 'persist-allow') {
        $Settings['enableFileAccess'] = '1'
        Save-PluginSettings -Plugin $Plugin -Settings $Settings
        $fileAccess = $true
    }
    if (-not $fileAccess) {
        Show-ErrorMessage -Message 'ERROR: Plugin launch blocked by file access settings. Enable it in Plugin settings if this plugin needs file access.'
        return $false
    }

    $rootAccessValue = Get-PluginPermissionValue -Settings $Settings -Key 'enableRootAccess' -Default '0'
    if ($rootAccessValue -in @('2', '3')) {
        $rootAccess = Resolve-PluginPermission -PluginName $Plugin.Name -PermissionName 'administrator / elevated access' -SettingValue $rootAccessValue -Description 'This plugin may need elevated permissions to complete its task.' -PersistOnFirstAllow:($rootAccessValue -eq '2') -ConfirmLaunch:$ConfirmLaunch -SecurityDefaultsConfirmed:$SecurityDefaultsConfirmed
        if ($rootAccess -eq 'persist-allow') {
            $Settings['enableRootAccess'] = '1'
            Save-PluginSettings -Plugin $Plugin -Settings $Settings
        }
        elseif (-not $rootAccess) {
            Show-ErrorMessage -Message 'ERROR: Plugin launch blocked by administrator access settings.'
            return $false
        }
    }

    return $true
}

function Get-PluginSecuritySettingKeys {
    return @(
        'enableNetworkAccess',
        'enableFileAccess',
        'enableRootAccess',
        'forcePlatformCompatibility'
    )
}

function Get-PluginSecurityReviewMarkerPath {
    param (
        [object]$Plugin
    )

    return Join-Path $Plugin.Directory '.reblock-security-confirmed'
}

function Test-PluginSecurityDefaultsConfirmed {
    param (
        [object]$Plugin
    )

    return Test-Path -LiteralPath (Get-PluginSecurityReviewMarkerPath -Plugin $Plugin)
}

function Set-PluginSecurityDefaultsConfirmed {
    param (
        [object]$Plugin
    )

    $markerPath = Get-PluginSecurityReviewMarkerPath -Plugin $Plugin
    Set-Content -LiteralPath $markerPath -Value (Get-Date).ToString('o') -Encoding UTF8 -NoNewline
}

function New-PluginSecurityReviewEntry {
    param (
        [string]$Key
    )

    return [PSCustomObject]@{
        Section = 'Security'
        Key = $Key
        Title = (Get-PluginSettingTitle -Key $Key)
        Type = (Get-PluginSettingType -Key $Key)
        Description = ''
    }
}

function Get-PluginSecuritySettingsForReview {
    param (
        [object]$Plugin,
        [hashtable]$Settings,
        [object[]]$SettingEntries
    )

    $securityKeys = Get-PluginSecuritySettingKeys
    $entryByKey = @{}
    foreach ($entry in $SettingEntries) {
        if ($entry.Section -eq 'Security' -and $entry.Key -in $securityKeys) {
            $entryByKey[$entry.Key] = $entry
        }
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($key in $securityKeys) {
        if ($entryByKey.ContainsKey($key)) {
            $null = $results.Add($entryByKey[$key])
        }
        else {
            $null = $results.Add((New-PluginSecurityReviewEntry -Key $key))
        }
    }

    return @($results.ToArray())
}

function Write-PluginSecurityReviewEntry {
    param (
        [object]$Entry,
        [string]$Value
    )

    Write-Host -NoNewline "  - $($Entry.Title): "
    $label = Get-PluginSettingStatusLabel -Type $Entry.Type -Value $Value
    $color = Get-PluginSettingStatusColor -Type $Entry.Type -Value $Value
    Write-Host $label -ForegroundColor $color
    if (-not [string]::IsNullOrWhiteSpace($Entry.Description)) {
        Write-Host "    $($Entry.Description)" -ForegroundColor DarkGray
    }
}

function Confirm-PluginSecurityDefaults {
    param (
        [object]$Plugin,
        [hashtable]$Settings
    )

    if (Test-PluginSecurityDefaultsConfirmed -Plugin $Plugin) {
        return $true
    }

    $pluginSettings = Get-PluginSettings -Plugin $Plugin
    $settingEntries = $pluginSettings['SettingEntries']
    $securitySettings = @(Get-PluginSecuritySettingsForReview -Plugin $Plugin -Settings $Settings -SettingEntries $settingEntries)

    Clear-Host
    Write-ReBlockHost -Message "First launch: $($Plugin.Name)" -Color 'Red'
    Write-Host 'This is the first time you are launching this plugin.'
    Write-Host 'Review its security settings before continuing.'
    Write-Host '___________________________________________'
    Write-Host ''
    Write-ReBlockHost -Message 'Security' -Color 'Cyan'

    foreach ($entry in $securitySettings) {
        $defaultValue = $pluginSettings['SettingValues'][$entry.Key]
        $value = Get-PluginPermissionValue -Settings $Settings -Key $entry.Key -Default $defaultValue
        Write-PluginSecurityReviewEntry -Entry $entry -Value $value
        Write-Host ''
    }

    $hasBlockingDisabledAccess = $false
    foreach ($entry in $securitySettings) {
        $value = Get-PluginPermissionValue -Settings $Settings -Key $entry.Key
        if ($value -eq '0' -and $entry.Key -in @('enableNetworkAccess', 'enableFileAccess')) {
            $hasBlockingDisabledAccess = $true
            break
        }
    }
    if ($hasBlockingDisabledAccess) {
        Write-ReBlockHost -Message 'Note: Disabled network or file access may block launch until changed in Plugin settings.' -Color 'Yellow'
        Write-Host ''
    }

    Write-Host 'You can change these later in Plugin settings.'
    Write-Host ''
    $response = Read-Host 'Allow this plugin to run with these security settings? (Y/N/1)'
    if (-not (Test-PermissionPromptAllowed -Response $response)) {
        Show-ErrorMessage -Message 'Plugin launch cancelled. Review security settings in Plugin settings if needed.'
        return $false
    }

    Set-PluginSecurityDefaultsConfirmed -Plugin $Plugin
    return $true
}
