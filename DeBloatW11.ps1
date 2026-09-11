<#
.SYNOPSIS
    Removes bloatware and OneDrive, and applies privacy/telemetry registry and scheduled-task tweaks.
.NOTES
    Run via Run.bat (Run as Administrator). Safe to re-run. Derived from https://github.com/Raphire/Win11Debloat
#>

#Requires -RunAsAdministrator

# Appx packages to remove; delete a line to keep that app installed.
$applist = @(
    "Clipchamp.Clipchamp"
    "Microsoft.3DBuilder"
    "Microsoft.549981C3F5F10" # Cortana
    "Microsoft.BingFinance"
    "Microsoft.BingFoodAndDrink"
    "Microsoft.BingHealthAndFitness"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingTravel"
    "Microsoft.BingWeather"
    "Microsoft.Copilot"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftJournal"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftPowerBIForWindows"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MixedReality.Portal"
    "Microsoft.News"
    "Microsoft.Office.OneNote"
    "Microsoft.Office.Sway"
    "Microsoft.OneConnect"
    "Microsoft.Print3D"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.SkypeApp"
    "Microsoft.Todos"
    "Microsoft.Windows.DevHome"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.XboxApp"
    "Microsoft.ZuneVideo"
    "MicrosoftCorporationII.MicrosoftFamily"
    "MicrosoftCorporationII.QuickAssist"
    "MicrosoftTeams"
    "MSTeams"
    "Microsoft.Windows.Recall"
    "Microsoft.Recall"
    "Microsoft.BingSearch"
    "Microsoft.OutlookForWindows"
    "Microsoft.StartExperiencesApp"
    "Microsoft.Whiteboard"
    "Microsoft.GamingApp"
    "Microsoft.XboxGamingOverlay"
    "MicrosoftWindows.Client.WebExperience" # Widgets host
    "MicrosoftWindows.CrossDevice" # Phone Link successor
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Windows.Ai.Copilot.Provider" # Edge Copilot provider shim
    # Third-party bloatware
    "ACGMediaPlayer"
    "ActiproSoftwareLLC"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    "Amazon.com.Amazon"
    "AmazonVideo.PrimeVideo"
    "Asphalt8Airborne"
    "AutodeskSketchBook"
    "CaesarsSlotsFreeCasino"
    "COOKINGFEVER"
    "CyberLinkMediaSuiteEssentials"
    "DisneyMagicKingdoms"
    "Disney"
    "DrawboardPDF"
    "Duolingo-LearnLanguagesforFree"
    "EclipseManager"
    "Facebook"
    "FarmVille2CountryEscape"
    "fitbit"
    "Flipboard"
    "HiddenCity"
    "HULULLC.HULUPLUS"
    "iHeartRadio"
    "Instagram"
    "king.com.BubbleWitch3Saga"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushSodaSaga"
    "LinkedIn"
    "LinkedInforWindows"
    "MarchofEmpires"
    "Netflix"
    "NYTCrossword"
    "OneCalendar"
    "PandoraMediaInc"
    "PhototasticCollage"
    "PicsArt-PhotoStudio"
    "Plex"
    "PolarrPhotoEditorAcademicEdition"
    "Royal"
    "Shazam"
    "Sidia.LiveWallpaper"
    "SlingTV"
    "Spotify"
    "TikTok"
    "TuneInRadio"
    "Twitter"
    "Viber"
    "Wunderlist" # To-do list app (Acquired by Microsoft)
)

# Remove each package above, plus its provisioned image so new profiles don't get it either.
Write-Host "------------------------"
Write-Host "-- Removing Bloatware --"
Write-Host "------------------------"
Write-Host ""

foreach ($app in $applist) {
    $pattern = '*' + $app + '*'

    $installed = Get-AppxPackage -Name $pattern -AllUsers -ErrorAction SilentlyContinue
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.PackageName -like $pattern }

    if ($installed) {
        try {
            $installed | Remove-AppxPackage -AllUsers -ErrorAction Stop
        }
        catch {
            Write-Host "FAILED to remove $app - $($_.Exception.Message)"
        }
    }

    if ($provisioned) {
        try {
            $provisioned | ForEach-Object {
                Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $_.PackageName -ErrorAction Stop | Out-Null
            }
        }
        catch {
            Write-Host "FAILED to remove provisioned $app - $($_.Exception.Message)"
        }
    }
}
Write-Host ""

# OneDrive is a Win32 app, not Appx, so it needs its own removal path.
Write-Host "------------------------"
Write-Host "-- Removing OneDrive  --"
Write-Host "------------------------"
Write-Host ""

$oneDriveProcess = Get-Process -Name OneDrive -ErrorAction SilentlyContinue
$oneDriveViaWinget = $null
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $oneDriveViaWinget = winget list --id Microsoft.OneDrive --accept-source-agreements 2>$null |
        Select-String -SimpleMatch "Microsoft.OneDrive"
}
$oneDriveSetupPaths = @(
    "$env:SystemRoot\System32\OneDriveSetup.exe"
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    "$env:LocalAppData\Microsoft\OneDrive\OneDriveSetup.exe"
) | Where-Object { Test-Path $_ }

$oneDrivePresent = [bool]($oneDriveProcess -or $oneDriveViaWinget -or $oneDriveSetupPaths)

if ($oneDrivePresent) {
    if ($oneDriveProcess) { $oneDriveProcess | Stop-Process -Force -ErrorAction SilentlyContinue }

    $removed = $false

    if ($oneDriveViaWinget -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        winget uninstall --id Microsoft.OneDrive --silent --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $removed = $true }
    }

    if (-not $removed -and $oneDriveSetupPaths) {
        try {
            Start-Process -FilePath $oneDriveSetupPaths[0] -ArgumentList "/uninstall" -Wait -ErrorAction Stop
            $removed = $true
        }
        catch {
            Write-Host "FAILED to run $($oneDriveSetupPaths[0]) /uninstall - $($_.Exception.Message)"
        }
    }

    if (-not $removed) {
        Write-Host "FAILED to remove OneDrive - no removal method succeeded"
    }
}
Write-Host ""

# Apply every .reg file in RegFiles\; delete a file there to opt out of that setting.
Write-Host "------------------------"
Write-Host "-- Disabling features --"
Write-Host "------------------------"
Write-Host ""

$regFiles = Get-ChildItem -Path "$PSScriptRoot\RegFiles\*.reg" -ErrorAction SilentlyContinue | Sort-Object Name

foreach ($file in $regFiles) {
    reg import "$($file.FullName)" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED to import $($file.Name) (reg exit $LASTEXITCODE)"
    }
}
Write-Host ""

# Telemetry-related scheduled tasks to disable.
$tasks = @(
    @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser" } # App-compat/upgrade-readiness data; can suppress feature-update offers
    @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser Exp" }
    @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "ProgramDataUpdater" } # Same app-compat data as above
    @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "StartupAppTask" } # Removes the "too many startup apps" notification
    @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "Consolidator" }
    @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "UsbCeip" }
    @{ Path = "\Microsoft\Windows\DiskDiagnostic\"; Name = "Microsoft-Windows-DiskDiagnosticDataCollector" } # Upload only - do not touch the Resolver task
    @{ Path = "\Microsoft\Windows\Autochk\"; Name = "Proxy" }
    @{ Path = "\Microsoft\Windows\Feedback\Siuf\"; Name = "DmClient" }
    @{ Path = "\Microsoft\Windows\Feedback\Siuf\"; Name = "DmClientOnScenarioDownload" }
    @{ Path = "\Microsoft\Windows\Windows Error Reporting\"; Name = "QueueReporting" } # Crash dumps no longer reach Microsoft
)

# Disable each task above if it exists and isn't already disabled.
Write-Host "-------------------------------"
Write-Host "-- Disabling scheduled tasks --"
Write-Host "-------------------------------"
Write-Host ""

foreach ($task in $tasks) {
    $taskId = "$($task.Path)$($task.Name)"

    try {
        $taskObj = Get-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop
    }
    catch {
        continue # Task doesn't exist on this build - nothing to do.
    }

    if ($taskObj.State -eq 'Disabled') { continue }

    try {
        Disable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null
    }
    catch {
        # Some tasks are TrustedInstaller-owned and refuse even as Administrator.
        Write-Host "FAILED to disable $taskId - $($_.Exception.Message)"
    }
}
Write-Host ""

Write-Host "-------------------------------------------"
Write-Host "-- Debloat run complete                  --"
Write-Host "-- NOTE: A system restart is recommended --"
Write-Host "-------------------------------------------"
Write-Host ""

$restart = Read-Host ">> Would you like to restart now? (Y/N)"
if ($restart -eq 'Y' -or $restart -eq 'y') {
    Write-Host "Restarting in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
else {
    Write-Host "Bye."
    Start-Sleep -Seconds 3
}
