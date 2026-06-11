Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-OfficialPluginManifest {
    param (
        [string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Official plugin manifest not found: $ManifestPath"
    }

    $raw = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}

function Get-OfficialPluginDefinition {
    param (
        [object]$Manifest,
        [string]$PluginId
    )

    $match = @($Manifest.plugins | Where-Object { $_.id -eq $PluginId })
    if ($match.Count -eq 0) {
        throw "Unknown official plugin id: $PluginId"
    }

    return $match[0]
}

function ConvertTo-PluginVersionText {
    param (
        [string]$TagName
    )

    if ([string]::IsNullOrWhiteSpace($TagName)) {
        return 'unknown'
    }

    return $TagName.Trim().TrimStart('v', 'V')
}

function Test-AssetPatternMatch {
    param (
        [string]$Name,
        [string]$Pattern
    )

    $regex = '^' + [regex]::Escape($Pattern).Replace('\*', '.*') + '$'
    return $Name -match $regex
}

function Get-GitHubRelease {
    param (
        [string]$Repo,
        [string]$Tag = ''
    )

    $headers = @{ 'User-Agent' = 'ReBlock-Plugin-Sync' }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
    }

    $uri = if ([string]::IsNullOrWhiteSpace($Tag)) {
        "https://api.github.com/repos/$Repo/releases/latest"
    }
    else {
        "https://api.github.com/repos/$Repo/releases/tags/$Tag"
    }

    return Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
}

function Select-ReleaseAsset {
    param (
        [object]$Release,
        [string]$Pattern
    )

    foreach ($asset in @($Release.assets)) {
        if (Test-AssetPatternMatch -Name $asset.name -Pattern $Pattern) {
            return $asset
        }
    }

    return $null
}

function Invoke-DownloadFile {
    param (
        [string]$Uri,
        [string]$Destination
    )

    $headers = @{ 'User-Agent' = 'ReBlock-Plugin-Sync' }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
    }

    Invoke-WebRequest -Uri $Uri -OutFile $Destination -Headers $headers -UseBasicParsing
}

function Expand-ArchiveToDirectory {
    param (
        [string]$ArchivePath,
        [string]$Destination,
        [switch]$CleanDestination
    )

    if ($CleanDestination -and (Test-Path -LiteralPath $Destination)) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $Destination -Force
}

function Copy-DirectoryMerge {
    param (
        [string]$Source,
        [string]$Destination,
        [string[]]$PreserveRelativePaths = @()
    )

    $preserve = @{}
    foreach ($item in $PreserveRelativePaths) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $preserve[$item.ToLowerInvariant()] = $true
        }
    }

    $sourceRoot = (Resolve-Path -LiteralPath $Source).Path
    Get-ChildItem -LiteralPath $Source -Recurse -Force | ForEach-Object {
        $relative = $_.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
        if ([string]::IsNullOrWhiteSpace($relative)) {
            return
        }

        foreach ($preserved in $preserve.Keys) {
            if ($relative.Equals($preserved, [System.StringComparison]::OrdinalIgnoreCase)) {
                return
            }
        }

        $target = Join-Path $Destination $relative
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
        else {
            $parent = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        }
    }
}

function Set-PluginVersionFiles {
    param (
        [string]$PluginDirectory,
        [string]$VersionText
    )

    $versionPath = Join-Path $PluginDirectory 'version.txt'
    Set-Content -LiteralPath $versionPath -Value $VersionText -Encoding UTF8 -NoNewline

    $pluginXmlPath = Join-Path $PluginDirectory 'plugin.xml'
    if (Test-Path -LiteralPath $pluginXmlPath) {
        $xml = Get-Content -LiteralPath $pluginXmlPath -Raw -Encoding UTF8
        $updated = [regex]::Replace($xml, '(<version>)[^<]*(</version>)', "`${1}$VersionText`${2}", 1)
        Set-Content -LiteralPath $pluginXmlPath -Value $updated -Encoding UTF8 -NoNewline
    }
}

function Import-ReleaseAssetToPlugin {
    param (
        [object]$Asset,
        [string]$PluginDirectory,
        [string[]]$Preserve,
        [switch]$Flatten,
        [string]$Pick
    )

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("reblock-plugin-" + [guid]::NewGuid().ToString())
    $zipPath = Join-Path $tempRoot 'asset.zip'
    $extractPath = Join-Path $tempRoot 'extracted'

    try {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        Invoke-DownloadFile -Uri $Asset.browser_download_url -Destination $zipPath
        Expand-ArchiveToDirectory -ArchivePath $zipPath -Destination $extractPath

        $sourcePath = $extractPath
        if (-not [string]::IsNullOrWhiteSpace($Pick)) {
            $picked = Get-ChildItem -LiteralPath $extractPath -Recurse -File -Filter $Pick -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($null -eq $picked) {
                $picked = Get-ChildItem -LiteralPath $extractPath -Recurse -Directory -Filter $Pick -ErrorAction SilentlyContinue |
                    Select-Object -First 1
            }
            if ($null -eq $picked) {
                throw "Could not find '$Pick' in release asset '$($Asset.name)'."
            }
            $sourcePath = $picked.FullName
        }
        elseif ($Flatten) {
            $children = @(Get-ChildItem -LiteralPath $extractPath)
            if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
                $sourcePath = $children[0].FullName
            }
        }

        if ($sourcePath -eq $extractPath) {
            Copy-DirectoryMerge -Source $sourcePath -Destination $PluginDirectory -PreserveRelativePaths $Preserve
        }
        elseif ((Get-Item -LiteralPath $sourcePath).PSIsContainer) {
            $destination = if ([string]::IsNullOrWhiteSpace($Pick)) {
                $PluginDirectory
            }
            else {
                Join-Path $PluginDirectory (Split-Path -Leaf $sourcePath)
            }
            if (Test-Path -LiteralPath $destination) {
                Remove-Item -LiteralPath $destination -Recurse -Force
            }
            Copy-Item -LiteralPath $sourcePath -Destination $destination -Recurse -Force
        }
        else {
            Copy-Item -LiteralPath $sourcePath -Destination $PluginDirectory -Force
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Sync-OfficialPluginFromRelease {
    param (
        [object]$PluginDefinition,
        [string]$PluginsRoot,
        [string]$Tag = ''
    )

    $release = Get-GitHubRelease -Repo $PluginDefinition.repo -Tag $Tag
    $asset = Select-ReleaseAsset -Release $release -Pattern $PluginDefinition.cliAssetPattern
    if ($null -eq $asset) {
        throw "No CLI asset matching '$($PluginDefinition.cliAssetPattern)' in release '$($release.tag_name)' for $($PluginDefinition.id)."
    }

    $pluginDirectory = Join-Path $PluginsRoot $PluginDefinition.folder
    New-Item -ItemType Directory -Path $pluginDirectory -Force | Out-Null

    $preserve = @($PluginDefinition.preserve)
    Import-ReleaseAssetToPlugin -Asset $asset -PluginDirectory $pluginDirectory -Preserve $preserve -Flatten

    $versionText = ConvertTo-PluginVersionText -TagName $release.tag_name
    Set-PluginVersionFiles -PluginDirectory $pluginDirectory -VersionText $versionText

    return [PSCustomObject]@{
        PluginId = $PluginDefinition.id
        Version = $versionText
        Tag = $release.tag_name
        Asset = $asset.name
    }
}

function Sync-OfficialPluginFromBranch {
    param (
        [object]$PluginDefinition,
        [string]$PluginsRoot
    )

    $branch = if ($PluginDefinition.branch) { $PluginDefinition.branch } else { 'main' }
    $headers = @{ 'User-Agent' = 'ReBlock-Plugin-Sync' }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
    }

    $archiveUri = "https://api.github.com/repos/$($PluginDefinition.repo)/tarball/$branch"
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("reblock-branch-" + [guid]::NewGuid().ToString())
    $archivePath = Join-Path $tempRoot 'repo.tar.gz'
    $extractPath = Join-Path $tempRoot 'extracted'

    try {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        Invoke-DownloadFile -Uri $archiveUri -Destination $archivePath

        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
            throw 'tar is required to extract branch archives.'
        }

        & tar -xzf $archivePath -C $extractPath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to extract branch archive for $($PluginDefinition.id)."
        }

        $repoRoot = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
        if ($null -eq $repoRoot) {
            throw "Branch archive for $($PluginDefinition.id) did not contain a root directory."
        }

        $pluginDirectory = Join-Path $PluginsRoot $PluginDefinition.folder
        New-Item -ItemType Directory -Path $pluginDirectory -Force | Out-Null

        foreach ($relativePath in @($PluginDefinition.syncFiles)) {
            $source = Join-Path $repoRoot.FullName $relativePath
            if (-not (Test-Path -LiteralPath $source)) {
                throw "Expected file '$relativePath' was not found in $($PluginDefinition.repo)@$branch."
            }

            $destination = Join-Path $pluginDirectory $relativePath
            $parent = Split-Path -Parent $destination
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }

        $versionPath = Join-Path $pluginDirectory 'version.txt'
        $versionText = if (Test-Path -LiteralPath $versionPath) {
            (Get-Content -LiteralPath $versionPath -TotalCount 1).Trim()
        }
        else {
            'unknown'
        }

        Set-PluginVersionFiles -PluginDirectory $pluginDirectory -VersionText $versionText

        return [PSCustomObject]@{
            PluginId = $PluginDefinition.id
            Version = $versionText
            Tag = $branch
            Asset = 'branch'
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Import-OfficialPluginGuiAssets {
    param (
        [string]$PluginsRoot,
        [ValidateSet('Windows', 'macOS', 'All')]
        [string]$Platform = 'All',
        [string]$ManifestPath
    )

    $manifest = Get-OfficialPluginManifest -ManifestPath $ManifestPath
    $platforms = if ($Platform -eq 'All') { @('windows', 'macos') } else { @( $Platform.ToLowerInvariant() ) }

    foreach ($plugin in @($manifest.plugins)) {
        if (-not $plugin.gui) {
            continue
        }

        $release = Get-GitHubRelease -Repo $plugin.repo
        $pluginDirectory = Join-Path $PluginsRoot $plugin.folder
        New-Item -ItemType Directory -Path $pluginDirectory -Force | Out-Null

        foreach ($platformKey in $platforms) {
            $gui = $plugin.gui.$platformKey
            if ($null -eq $gui) {
                continue
            }

            $asset = Select-ReleaseAsset -Release $release -Pattern $gui.assetPattern
            if ($null -eq $asset) {
                Write-Warning "No GUI asset matching '$($gui.assetPattern)' for $($plugin.id) on $platformKey."
                continue
            }

            $destination = Join-Path $pluginDirectory $gui.destination
            $flatten = $false
            if ($null -ne $gui.flatten) {
                $flatten = [bool]$gui.flatten
            }

            $pick = if ($gui.pick) { [string]$gui.pick } else { '' }
            Import-ReleaseAssetToPlugin -Asset $asset -PluginDirectory $destination -Preserve @() -Flatten:$flatten -Pick $pick
            Write-Host "Fetched GUI for $($plugin.id) ($platformKey) from $($asset.name)"
        }
    }
}
