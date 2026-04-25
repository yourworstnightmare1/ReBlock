Write-Host "Loading..." -ForegroundColor Yellow
Write-Host "Setting variables..."

$iconHiddenFiles = "
                         *****++++++==
                         #####%%%*****++++
           *********************#%%##****+++
       **************************#%@%%###*#++===
     *****************************%%@@@@%%@%#**+=
    *******************************##%#****#@@@*-
    ************************=:::-****#*********-
    **********************:..-+**************
    *********************:.=*******+.-*******
    ********************=.:*******#* :+******
    ********************=.:*#+++*#** .+******
    ********************=.:#%%###*** .+******
    *******-.            .*%%##%*************
    ******+.            .*%%##%#*************
    ******+.           :*%%##%#**************
    ******+.          :#%%##%#***************
    ******+.        .-#%%##%*****************
    ******+.        -#%%##%+-****************
    ******+.       =%%%##%*.-****************
    *******+::::::+%%%##%#:-*****************
    *************#%%%##%%#*******************
     ***********#%%%##%%#*******************
       ********#%%%##%%*******************
          ****#%%%%#%%#****************
              %%%@@@@%
                  %%
"

function Get-PlatformName {
    $runtime = [System.Runtime.InteropServices.RuntimeInformation]
    if ($runtime::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return "Windows"
    }
    if ($runtime::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        return "macOS"
    }
    return "Unknown"
}

function Get-WindowsHiddenFilesState {
    $advancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $hiddenValue = (Get-ItemProperty -Path $advancedKey -Name "Hidden" -ErrorAction SilentlyContinue).Hidden

    if ($null -eq $hiddenValue) {
        return $false
    }

    return ([int]$hiddenValue -eq 1)
}

function Get-WindowsSuperHiddenState {
    $advancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $superHiddenValue = (Get-ItemProperty -Path $advancedKey -Name "ShowSuperHidden" -ErrorAction SilentlyContinue).ShowSuperHidden

    if ($null -eq $superHiddenValue) {
        return $false
    }

    return ([int]$superHiddenValue -eq 1)
}

function Get-MacHiddenFilesState {
    try {
        $value = (defaults read com.apple.finder AppleShowAllFiles 2>$null).Trim().ToLowerInvariant()
    }
    catch {
        return $false
    }

    return $value -in @("1", "true", "yes")
}

function Restart-WindowsExplorer {
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 400
    Start-Process explorer.exe
    Start-Sleep -Milliseconds 900

    # Close File Explorer windows that can appear after shell restart.
    # This keeps the Explorer shell (desktop/taskbar) running.
    try {
        $shell = New-Object -ComObject Shell.Application
        foreach ($window in @($shell.Windows())) {
            try {
                if ($null -ne $window -and $window.FullName -match "explorer\.exe$" -and -not [string]::IsNullOrWhiteSpace($window.LocationURL)) {
                    $window.Quit()
                }
            }
            catch {
                # Ignore transient COM window errors.
            }
        }
    }
    catch {
        # Ignore if COM is unavailable.
    }
}

function Restart-MacFinder {
    try {
        & killall Finder | Out-Null
    }
    catch {
        # Finder may not be running in some shell contexts.
    }
}

function Set-HiddenFilesVisible {
    param(
        [string]$Platform
    )

    if ($Platform -eq "Windows") {
        $advancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Write-Host "Setting registry value to show hidden files..." -ForegroundColor Yellow
        Set-ItemProperty -Path $advancedKey -Name "Hidden" -Type DWord -Value 1
        Write-Host "Restarting Explorer..." -ForegroundColor Yellow
        Restart-WindowsExplorer
        Write-Host "Hidden files are now visible." -ForegroundColor Green
        return
    }

    if ($Platform -eq "macOS") {
        Write-Host "Running command to show hidden files..." -ForegroundColor Yellow
        & defaults write com.apple.finder AppleShowAllFiles -bool true
        Write-Host "Restarting Finder..." -ForegroundColor Yellow
        Restart-MacFinder
        Write-Host "Hidden files are now visible." -ForegroundColor Green
        return
    }
}

function Set-HiddenFilesHidden {
    param(
        [string]$Platform
    )

    if ($Platform -eq "Windows") {
        $advancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Write-Host "Setting registry value to hide hidden files..." -ForegroundColor Yellow
        Set-ItemProperty -Path $advancedKey -Name "Hidden" -Type DWord -Value 2
        Write-Host "Restarting Explorer..." -ForegroundColor Yellow
        Restart-WindowsExplorer
        Write-Host "Hidden files are now hidden." -ForegroundColor Green
        return
    }

    if ($Platform -eq "macOS") {
        Write-Host "Running command to hide hidden files..." -ForegroundColor Yellow
        & defaults write com.apple.finder AppleShowAllFiles -bool false
        Write-Host "Restarting Finder..." -ForegroundColor Yellow
        Restart-MacFinder
        Write-Host "Hidden files are now hidden." -ForegroundColor Green
        return
    }
}

function Set-SuperHiddenVisible {
    $advancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Write-Host "Setting registry value to show protected system files..." -ForegroundColor Yellow
    Set-ItemProperty -Path $advancedKey -Name "ShowSuperHidden" -Type DWord -Value 1
    Write-Host "Restarting Explorer..." -ForegroundColor Yellow
    Restart-WindowsExplorer
    Write-Host "Protected system files are now visible (not recommended)." -ForegroundColor Yellow
}

function Set-SuperHiddenHidden {
    $advancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Write-Host "Removing registry value to hide protected system files..." -ForegroundColor Yellow
    Remove-ItemProperty -Path $advancedKey -Name "ShowSuperHidden" -ErrorAction SilentlyContinue
    Write-Host "Restarting Explorer..." -ForegroundColor Yellow
    Restart-WindowsExplorer
    Write-Host "Protected system files are now hidden." -ForegroundColor Green
}

function Show-HiddenFilesMenu {
    param(
        [string]$Platform
    )

    $isWindowsPlatform = $Platform -eq "Windows"
    $isMacPlatform = $Platform -eq "macOS"

    if (-not ($isWindowsPlatform -or $isMacPlatform)) {
        Write-Host "Unsupported OS. This plugin supports Windows and macOS only." -ForegroundColor Red
        return
    }

    do {
        Clear-Host

        $hiddenFilesShown = if ($isWindowsPlatform) { Get-WindowsHiddenFilesState } else { Get-MacHiddenFilesState }
        $superHiddenShown = if ($isWindowsPlatform) { Get-WindowsSuperHiddenState } else { $false }

        Write-Host "hiddenFiles" -ForegroundColor Cyan
        Write-Host "Choose an option:"
        Write-Host ""

        if ($hiddenFilesShown) {
            Write-Host "[1] Show hidden files (Active)" -ForegroundColor Green
        }
        else {
            Write-Host "[1] Show hidden files"
        }
        if ($isWindowsPlatform) {
            Write-Host "    Windows: hiddenFiles will add a registry value to reveal hidden files and restart Explorer." -ForegroundColor DarkGray
        }
        else {
            Write-Host "    macOS: hiddenFiles will run a command to show hidden files and restart Finder." -ForegroundColor DarkGray
        }

        if (-not $hiddenFilesShown) {
            Write-Host "[2] Hide hidden files (Active)" -ForegroundColor Green
        }
        else {
            Write-Host "[2] Hide hidden files"
        }
        if ($isWindowsPlatform) {
            Write-Host "    Windows: hiddenFiles will set the registry value to hide hidden files and restart Explorer." -ForegroundColor DarkGray
        }
        else {
            Write-Host "    macOS: hiddenFiles will run the command with false to hide hidden files and restart Finder." -ForegroundColor DarkGray
        }

        if ($isWindowsPlatform) {
            if ($superHiddenShown) {
                Write-Host "[3] Show protected system files (Windows only) (Not recommended) (Active)" -ForegroundColor Green
            }
            else {
                Write-Host "[3] Show protected system files (Windows only) (Not recommended)"
            }
            Write-Host "    Windows: hiddenFiles will set ShowSuperHidden to show protected system files." -ForegroundColor DarkGray

            if (-not $superHiddenShown) {
                Write-Host "[4] Hide protected system files (Windows only) (Active)" -ForegroundColor Green
            }
            else {
                Write-Host "[4] Hide protected system files (Windows only)"
            }
            Write-Host "    Windows: hiddenFiles will remove/reset ShowSuperHidden to hide protected system files." -ForegroundColor DarkGray
        }

        Write-Host "[X] Back"
        Write-Host ""

        $prompt = if ($isWindowsPlatform) { "Enter 1-4 or X" } else { "Enter 1-2 or X" }
        $choice = Read-Host $prompt

        switch ($choice.ToUpperInvariant()) {
            "1" { Set-HiddenFilesVisible -Platform $Platform }
            "2" { Set-HiddenFilesHidden -Platform $Platform }
            "3" {
                if ($isWindowsPlatform) {
                    Set-SuperHiddenVisible
                }
                else {
                    Write-Host "That option is only available on Windows." -ForegroundColor Red
                }
            }
            "4" {
                if ($isWindowsPlatform) {
                    Set-SuperHiddenHidden
                }
                else {
                    Write-Host "That option is only available on Windows." -ForegroundColor Red
                }
            }
            "X" { return }
            default { Write-Host "Invalid choice. Try again." -ForegroundColor Red }
        }

        if ($choice.ToUpperInvariant() -ne "X") {
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
    } while ($true)
}

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
}

$platform = Get-PlatformName

do {
    Clear-Host
    Write-Host "$iconHiddenFiles" -ForegroundColor Red
    Write-Host "Welcome to hiddenFiles!" -ForegroundColor Red
    Write-Host "Version $appVersion" -ForegroundColor Yellow
    Write-Host "Created & Programmed by yourworstnightmare1"
    Write-Host "___________________________________________"
    Write-Host ""
    Write-Host "Choose an option:" -ForegroundColor Cyan
    Write-Host "[1] Continue"
    Write-Host "[2] Go to ReBlock website"
    Write-Host "[3] Go to GitHub"
    Write-Host "[4] Exit"
    Write-Host ""

    $choice = Read-Host "Enter 1-4"
    switch ($choice) {
        "1" {
            Show-HiddenFilesMenu -Platform $platform
        }
        "2" {
            Start-Process "https://sites.google.com/view/reblock"
            Write-Host "Opened website in your browser." -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        "3" {
            Start-Process "https://github.com/yourworstnightmare1/hiddenfiles"
            Write-Host "Opened GitHub in your browser." -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        "4" {
            Write-Host "Goodbye!" -ForegroundColor Yellow
            exit
        }
        default {
            Write-Host "Invalid choice. Please enter 1, 2, 3, or 4." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($true)

