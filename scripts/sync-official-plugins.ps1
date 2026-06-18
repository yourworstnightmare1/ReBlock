[CmdletBinding()]
param(
    [string]$PluginId = '',
    [string]$ReleaseTag = '',
    [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}

$manifestPath = Join-Path $PSScriptRoot 'official-plugins.json'
. (Join-Path $PSScriptRoot 'OfficialPlugins.ps1')

$manifest = Get-OfficialPluginManifest -ManifestPath $manifestPath
$pluginsRoot = Join-Path $RepoRoot 'plugins'
$results = New-Object System.Collections.Generic.List[object]

$targets = if ([string]::IsNullOrWhiteSpace($PluginId)) {
    @($manifest.plugins)
}
else {
    @(Get-OfficialPluginDefinition -Manifest $manifest -PluginId $PluginId)
}

foreach ($plugin in $targets) {
    Write-Host "Syncing $($plugin.id)..."

    try {
        $result = if ($plugin.syncMode -eq 'branch') {
            Sync-OfficialPluginFromBranch -PluginDefinition $plugin -PluginsRoot $pluginsRoot
        }
        else {
            Sync-OfficialPluginFromRelease -PluginDefinition $plugin -PluginsRoot $pluginsRoot -Tag $ReleaseTag
        }

        $results.Add($result) | Out-Null
        Write-Host "Synced $($result.PluginId) -> $($result.Version) ($($result.Asset))"
    }
    catch {
        $isOptional = $false
        if ($null -ne $plugin.optional) {
            $isOptional = [bool]$plugin.optional
        }

        if ($isOptional) {
            Write-Warning "Skipped optional plugin $($plugin.id): $($_.Exception.Message)"
            continue
        }

        throw
    }
}

if ($results.Count -eq 0) {
    throw 'No plugins were synced.'
}

$summaryPath = Join-Path $RepoRoot 'sync-summary.json'
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "Wrote $summaryPath"
