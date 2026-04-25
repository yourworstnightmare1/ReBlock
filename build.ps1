param(
    [switch]$SkipPowerShell,
    [switch]$SkipBash
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $repoRoot

try {
    if (-not $SkipPowerShell) {
        Write-Host "Validating PowerShell scripts..."
        $ps1Files = Get-ChildItem -Path . -Recurse -Filter *.ps1 -File
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
            Write-Warning "Install Git Bash/WSL or run: .\build.ps1 -SkipBash"
        }
        else {
            Write-Host "Validating Bash scripts..."
            $shFiles = Get-ChildItem -Path . -Recurse -Filter *.sh -File
            foreach ($file in $shFiles) {
                & bash -n $file.FullName
                if ($LASTEXITCODE -ne 0) {
                    throw "Bash syntax check failed for $($file.FullName)"
                }

                Write-Host "OK (sh): $($file.FullName)"
            }
        }
    }

    Write-Host "Build validation complete."
}
finally {
    Pop-Location
}
