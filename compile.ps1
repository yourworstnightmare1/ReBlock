param(
    [string]$OutputDir,
    [switch]$Clean,
    [switch]$BuildExe,
    [switch]$Zip,
    [switch]$Archive,
    [switch]$SkipPowerShellValidation,
    [switch]$SkipBashValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Copy-IfExists {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path $Source) {
        Copy-Item -Path $Source -Destination $Destination -Recurse -Force
    }
}

function Test-CanReplaceFile {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $true
    }

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $stream.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-Validation {
    param(
        [string]$RepoRoot,
        [bool]$SkipPowerShell,
        [bool]$SkipBash
    )

    if (-not $SkipPowerShell) {
        Write-Host "Validating PowerShell scripts..."
        $ps1Files = Get-ChildItem -Path $RepoRoot -Recurse -Filter *.ps1 -File
        foreach ($file in $ps1Files) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)

            if ($errors -and $errors.Count -gt 0) {
                $errors | ForEach-Object { Write-Host $_.ToString() }
                throw "PowerShell parse errors in $($file.FullName)"
            }

            Write-Host "OK (ps1): $($file.FullName)"
        }
    }

    if (-not $SkipBash) {
        $bash = Get-Command bash -ErrorAction SilentlyContinue
        if (-not $bash) {
            Write-Warning "bash was not found in PATH. Skipping shell script validation."
            Write-Warning "Install Git Bash/WSL or run: .\compile.ps1 -SkipBashValidation"
        }
        else {
            $null = & bash --version 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "bash is present but not usable in this environment. Skipping shell script validation."
                Write-Warning "If you use WSL, install a distro or run: .\compile.ps1 -SkipBashValidation"
                $global:LASTEXITCODE = 0
            }
            else {
                Write-Host "Validating Bash scripts..."
                $shFiles = Get-ChildItem -Path $RepoRoot -Recurse -Filter *.sh -File
                foreach ($file in $shFiles) {
                    & bash -n $file.FullName
                    if ($LASTEXITCODE -ne 0) {
                        throw "Bash syntax check failed for $($file.FullName)"
                    }

                    Write-Host "OK (sh): $($file.FullName)"
                }
            }
        }
    }

    Write-Host "Build validation complete."
    $global:LASTEXITCODE = 0
}

function Invoke-WindowsPackaging {
    param(
        [string]$RepoRoot,
        [string]$ReleaseRoot,
        [bool]$DoClean,
        [bool]$DoBuildExe,
        [bool]$DoZip
    )

    $appRoot = Join-Path $ReleaseRoot "data"

    if ($DoClean -and (Test-Path $ReleaseRoot)) {
        Remove-Item -Path $ReleaseRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $appRoot -Force | Out-Null
    Copy-IfExists -Source (Join-Path $RepoRoot "reblock.ps1") -Destination $appRoot
    Copy-IfExists -Source (Join-Path $RepoRoot "version.txt") -Destination $appRoot
    Copy-IfExists -Source (Join-Path $RepoRoot "plugins") -Destination $appRoot
    Copy-IfExists -Source (Join-Path $RepoRoot "README.md") -Destination $appRoot
    Copy-IfExists -Source (Join-Path $RepoRoot "LICENSE") -Destination $appRoot

    $launcherPath = Join-Path $ReleaseRoot "Start-ReBlock.bat"
    @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0data\reblock.ps1"
"@ | Set-Content -Path $launcherPath -Encoding ASCII

    if ($DoBuildExe) {
        $exePath = Join-Path $ReleaseRoot "ReBlock.exe"
        $invokePs2Exe = Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue

        if (-not $invokePs2Exe) {
            Write-Warning "Invoke-ps2exe was not found. Install the PS2EXE module to enable -BuildExe:"
            Write-Warning "Install-Module ps2exe -Scope CurrentUser"
        }
        else {
            if (-not (Test-CanReplaceFile -Path $exePath)) {
                throw "Cannot write to '$exePath'. Close ReBlock.exe (or any process using it) and run the build again."
            }

            try {
                Invoke-ps2exe `
                    -inputFile (Join-Path $appRoot "reblock.ps1") `
                    -outputFile $exePath `
                    -noConsole:$false `
                    -ErrorAction Stop
            }
            catch {
                throw "PS2EXE compilation failed. $($_.Exception.Message)"
            }

            if (Test-Path $exePath) {
                Write-Host "Built executable: $exePath"
            }
            else {
                throw "PS2EXE returned without errors but '$exePath' was not created."
            }
        }
    }

    if ($DoZip) {
        $zipPath = Join-Path $ReleaseRoot "ReBlock-windows.zip"
        if (Test-Path $zipPath) {
            Remove-Item -Path $zipPath -Force
        }

        Compress-Archive -Path (Join-Path $ReleaseRoot "*") -DestinationPath $zipPath -Force
        Write-Host "Created archive: $zipPath"
    }

    Write-Host "Windows build output: $ReleaseRoot"
}

function Invoke-MacOSPackaging {
    param(
        [string]$RepoRoot,
        [string]$ReleaseRoot,
        [bool]$DoClean,
        [bool]$DoArchive
    )

    $payloadRoot = Join-Path $ReleaseRoot "ReBlock"
    $appRoot = Join-Path $ReleaseRoot "ReBlock.app"

    if ($DoClean -and (Test-Path $ReleaseRoot)) {
        Remove-Item -Path $ReleaseRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $payloadRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $appRoot "Contents/MacOS") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $appRoot "Contents/Resources") -Force | Out-Null

    Copy-IfExists -Source (Join-Path $RepoRoot "reblock.ps1") -Destination $payloadRoot
    Copy-IfExists -Source (Join-Path $RepoRoot "version.txt") -Destination $payloadRoot
    Copy-IfExists -Source (Join-Path $RepoRoot "plugins") -Destination $payloadRoot
    Copy-IfExists -Source (Join-Path $RepoRoot "README.md") -Destination $payloadRoot
    Copy-IfExists -Source (Join-Path $RepoRoot "LICENSE") -Destination $payloadRoot

    $launcherPath = Join-Path $appRoot "Contents/MacOS/ReBlock"
    @'
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_PATH="$APP_DIR/../ReBlock/reblock.ps1"

if command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoProfile -File "$SCRIPT_PATH" "$@"
fi

if command -v powershell >/dev/null 2>&1; then
  exec powershell -NoProfile -File "$SCRIPT_PATH" "$@"
fi

echo "PowerShell is required to run ReBlock on macOS." >&2
echo "Install PowerShell from https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-macos" >&2
exit 1
'@ | Set-Content -Path $launcherPath -Encoding UTF8

    if (Get-Command chmod -ErrorAction SilentlyContinue) {
        & chmod +x $launcherPath | Out-Null
    }

    $plistPath = Join-Path $appRoot "Contents/Info.plist"
    @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>ReBlock</string>
  <key>CFBundleDisplayName</key>
  <string>ReBlock</string>
  <key>CFBundleIdentifier</key>
  <string>com.reblock.app</string>
  <key>CFBundleVersion</key>
  <string>1.0.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleExecutable</key>
  <string>ReBlock</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
</dict>
</plist>
'@ | Set-Content -Path $plistPath -Encoding UTF8

    if ($DoArchive) {
        $archivePath = Join-Path $ReleaseRoot "ReBlock-macos.tar.gz"
        if (Test-Path $archivePath) {
            Remove-Item -Path $archivePath -Force
        }

        if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
            throw "tar is required for -Archive on macOS."
        }

        & tar -czf $archivePath -C $ReleaseRoot ReBlock ReBlock.app
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create archive '$archivePath'."
        }

        Write-Host "Created archive: $archivePath"
    }

    Write-Host "macOS build output: $ReleaseRoot"
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $repoRoot
try {
    Invoke-Validation -RepoRoot $repoRoot -SkipPowerShell:$SkipPowerShellValidation.IsPresent -SkipBash:$SkipBashValidation.IsPresent

    $runtime = [System.Runtime.InteropServices.RuntimeInformation]
    $isWindows = $runtime::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    $isMacOS = $runtime::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)

    if ($isWindows) {
        $effectiveOutputDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) { ".dist/windows" } else { $OutputDir }
        $releaseRoot = Join-Path $repoRoot $effectiveOutputDir
        Invoke-WindowsPackaging -RepoRoot $repoRoot -ReleaseRoot $releaseRoot -DoClean:$Clean.IsPresent -DoBuildExe:$BuildExe.IsPresent -DoZip:$Zip.IsPresent
    }
    elseif ($isMacOS) {
        $effectiveOutputDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) { ".dist/macos" } else { $OutputDir }
        $releaseRoot = Join-Path $repoRoot $effectiveOutputDir
        Invoke-MacOSPackaging -RepoRoot $repoRoot -ReleaseRoot $releaseRoot -DoClean:$Clean.IsPresent -DoArchive:$Archive.IsPresent
    }
    else {
        throw "Unsupported platform for compile.ps1. Supported: Windows and macOS."
    }
}
finally {
    Pop-Location
}
