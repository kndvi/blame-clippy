<#
.SYNOPSIS
    Remove bloated Windows software and apps
.DESCRIPTION
    This script removes common bloatware, pre-installed apps, and unnecessary software from Windows.
    Run as Administrator for best results.
.NOTES
    Author: Khoa Nguyen
    Requires: PowerShell 5.1+ and Administrator privileges
#>

#Requires -RunAsAdministrator

# Set error action preference
$ErrorActionPreference = "Continue"

Write-Host "------------"
Write-Host "Windows bloatware removal script"
Write-Host ""

# Function to remove AppX packages
function Remove-BloatwareAppx {
    param (
        [string]$AppName
    )

    try {
        $packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$AppName*" }

        foreach ($package in $packages) {
            Write-Host "Removing:  $($package.Name)..."
            Remove-AppxPackage -Package $package.PackageFullName -ErrorAction SilentlyContinue
            Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction SilentlyContinue
            Write-Host "  Removed: $($package.Name)"
        }
    }
    catch {
        Write-Host "  Error removing $AppName:  $_"
    }
}

# List of common bloatware AppX packages
$bloatwareApps = @(
    # Microsoft bloatware
    "Microsoft.3DBuilder"
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.BingSports"
    "Microsoft.BingFinance"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MixedReality. Portal"
    "Microsoft.Office.OneNote"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Wallet"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCamera"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    # AI Features
    "Microsoft.Windows.Ai.Copilot. Provider"
    "Microsoft.Windows. AiShell"
    "Microsoft.Copilot"
    "Microsoft.WindowsCopilot"
    "MicrosoftWindows.Client.Copilot"
    "Microsoft.Windows.Recall"
    "Microsoft.Recall"
    # Third-party bloatware
    "CandyCrush"
    "BubbleWitch3Saga"
    "Wunderlist"
    "Flipboard"
    "Twitter"
    "Facebook"
    "Spotify"
    "Minecraft"
    "RoyalRevolt"
    "Sway"
    "SpeedTest"
    "Dolby"
    "Disney"
    "Netflix"
    # OEM bloatware (common)
    "ACGMediaPlayer"
    "ActiproSoftwareLLC"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    "Duolingo"
    "EclipseManager"
    "PandoraMediaInc"
    "SpotifyAB.SpotifyMusic"
)

Write-Host "------------"
Write-Host "Removing AppX packages..."
Write-Host ""

foreach ($app in $bloatwareApps) {
    Remove-BloatwareAppx -AppName $app
}

Write-Host ""
Write-Host "------------"
Write-Host "Removing Windows AI features..."
Write-Host ""

# Disable Windows Copilot
try {
    Write-Host "Disabling Windows Copilot..."

    # Disable Copilot via registry
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Type DWord -Value 1

    # Disable Copilot button on taskbar
    if (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Type DWord -Value 0

    # Disable Copilot via Group Policy style registry
    if (!(Test-Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot")) {
        New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Type DWord -Value 1

    Write-Host "  Windows Copilot disabled"
}
catch {
    Write-Host "  Error disabling Copilot: $_"
}

# Disable Windows Recall (24H2+)
try {
    Write-Host "Disabling Windows Recall..."

    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots" -Type DWord -Value 1

    # Disable Recall feature
    if (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisableRecall" -Type DWord -Value 1

    Write-Host "  Windows Recall disabled"
}
catch {
    Write-Host "  Error disabling Recall: $_"
}

# Disable AI-powered suggestions
try {
    Write-Host "Disabling AI-powered suggestions..."

    # Disable Start menu suggestions
    if (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Type DWord -Value 0

    # Disable Windows Ink Workspace suggestions
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Type DWord -Value 0

    # Disable Settings app suggestions
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Type DWord -Value 0

    Write-Host "  AI-powered suggestions disabled"
}
catch {
    Write-Host "  Error disabling AI suggestions: $_"
}

# Disable Widgets with AI features
try {
    Write-Host "Disabling Widgets and AI news feed..."

    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Type DWord -Value 0

    # Disable Widgets on taskbar
    if (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Type DWord -Value 0

    Write-Host "  Widgets and AI news feed disabled"
}
catch {
    Write-Host "  Error disabling Widgets: $_"
}

# Disable Bing Search in Start Menu
try {
    Write-Host "Disabling Bing Search in Start Menu..."

    if (!(Test-Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer")) {
        New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Type DWord -Value 1

    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Type DWord -Value 1

    Write-Host "  Bing Search in Start Menu disabled"
}
catch {
    Write-Host "  Error disabling Bing Search:  $_"
}

Write-Host ""
Write-Host "------------"
Write-Host "Removing Windows capabilities..."
Write-Host ""

# Optional Windows capabilities to remove
$capabilities = @(
    "App.Support.QuickAssist~~~~0.0.1.0"
    "MathRecognizer~~~~0.0.1.0"
    "Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0"
)

foreach ($capability in $capabilities) {
    try {
        $installed = Get-WindowsCapability -Online | Where-Object { $_.Name -eq $capability -and $_.State -eq "Installed" }
        if ($installed) {
            Write-Host "Removing capability: $capability..."
            Remove-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue
            Write-Host "  Removed:  $capability"
        }
    }
    catch {
        Write-Host "  Error removing $capability: $_"
    }
}

Write-Host ""
Write-Host "------------"
Write-Host "Disabling telemetry and features..."
Write-Host ""

# Disable telemetry
try {
    Write-Host "Disabling telemetry services..."

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0 -ErrorAction SilentlyContinue

    # Disable Windows consumer features
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 1

    Write-Host "  Telemetry disabled"
}
catch {
    Write-Host "  Error disabling telemetry: $_"
}

# Disable Cortana
try {
    Write-Host "Disabling Cortana..."

    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Type DWord -Value 0

    Write-Host "  Cortana disabled"
}
catch {
    Write-Host "  Error disabling Cortana: $_"
}

Write-Host ""
Write-Host "------------"
Write-Host "Uninstalling OneDrive..."
Write-Host ""

try {
    Write-Host "Stopping OneDrive process..."

    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
    if (!(Test-Path $onedrive)) {
        $onedrive = "$env: SYSTEMROOT\System32\OneDriveSetup.exe"
    }

    if (Test-Path $onedrive) {
        Write-Host "Running OneDrive uninstaller..."
        Start-Process $onedrive "/uninstall" -NoNewWindow -Wait
        Write-Host "  OneDrive uninstalled"

        # Remove OneDrive leftovers
        Write-Host "Removing OneDrive leftovers..."
        Remove-Item -Path "$env:USERPROFILE\OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path "$env: LOCALAPPDATA\Microsoft\OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path "$env: PROGRAMDATA\Microsoft OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\OneDriveTemp" -Force -Recurse -ErrorAction SilentlyContinue

        # Remove OneDrive from Explorer sidebar
        Write-Host "Removing OneDrive from Explorer..."
        if (!(Test-Path "HKCR: ")) {
            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
        }
        Remove-Item -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -ErrorAction SilentlyContinue

        Write-Host "  OneDrive removal complete"
    }
    else {
        Write-Host "  OneDrive not found or already uninstalled"
    }
}
catch {
    Write-Host "  Error uninstalling OneDrive: $_"
}

Write-Host ""
Write-Host "------------"
Write-Host "Bloatware removal complete!"
Write-Host ""
Write-Host "NOTE: A system restart is recommended."
Write-Host ""

# Ask for restart
$restart = Read-Host "Would you like to restart now? (Y/N)"
if ($restart -eq 'Y' -or $restart -eq 'y') {
    Write-Host "Restarting in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
