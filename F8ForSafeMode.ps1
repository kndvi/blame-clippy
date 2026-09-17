<#
.SYNOPSIS
    Removes bloatware and OneDrive, and applies privacy/telemetry registry and scheduled-task tweaks.
.NOTES
    Run via RunAnw.bat (Run as Administrator). Safe to re-run. Derived from https://github.com/Raphire/Win11Debloat
    For a personal laptop only - refuses to run on a device that looks corporate-managed.
    Pass -ThisPCIsGenuinelyMine to override that check, or -VibeCheck to check applied state without changing anything.
#>

#Requires -RunAsAdministrator

param(
    [switch]$ThisPCIsGenuinelyMine,
    [switch]$VibeCheck
)

# --- Vibe check: report drift against RegFiles\*.reg and exit, no changes made. ---

function Get-RegFiles {
    Get-ChildItem -Path "$PSScriptRoot\RegFiles\*.reg" -ErrorAction SilentlyContinue | Sort-Object Name
}

function Get-RegFileEntries {
    param([string]$Path)

    $entries = @()
    $currentKey = $null

    Get-Content -LiteralPath $Path -Encoding Unicode | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\[-?(.+)\]$') {
            $currentKey = $Matches[1]
        }
        elseif ($currentKey -and $line -match '^"([^"]+)"=(.+)$') {
            $entries += [PSCustomObject]@{ Key = $currentKey; Name = $Matches[1]; Value = $Matches[2] }
        }
    }

    return $entries
}

function ConvertTo-RegPath {
    param([string]$Key)
    switch -Regex ($Key) {
        '^HKEY_LOCAL_MACHINE\\(.*)$' { return "HKLM:\$($Matches[1])" }
        '^HKEY_CURRENT_USER\\(.*)$' { return "HKCU:\$($Matches[1])" }
        '^HKEY_USERS\\(.*)$' { return "Registry::HKEY_USERS\$($Matches[1])" }
        default { return $null }
    }
}

function Invoke-VibeCheck {
    foreach ($file in Get-RegFiles) {
        foreach ($entry in Get-RegFileEntries -Path $file.FullName) {
            $path = ConvertTo-RegPath -Key $entry.Key
            if (-not $path) { continue }
            $label = "$($file.Name): $($entry.Key)\$($entry.Name)"

            if ($entry.Value -eq '-') {
                $current = if (Test-Path $path) { Get-ItemProperty -Path $path -Name $entry.Name -ErrorAction SilentlyContinue } else { $null }
                if ($null -eq $current) { Write-Host "OK       $label" } else { Write-Host "DRIFTED  $label (expected absent, still present)" }
                continue
            }

            if (-not (Test-Path $path)) { Write-Host "MISSING  $label (key does not exist)"; continue }
            $current = Get-ItemProperty -Path $path -Name $entry.Name -ErrorAction SilentlyContinue
            if ($null -eq $current) { Write-Host "MISSING  $label"; continue }

            $currentValue = $current.$($entry.Name)
            if ($entry.Value -match '^dword:([0-9a-fA-F]+)$') {
                $expected = [Convert]::ToInt64($Matches[1], 16)
                # Registry DWORDs read back as signed Int32 (e.g. 0xFFFFFFFF -> -1);
                # compare via a common unsigned 32-bit view so sign doesn't cause a false DRIFTED.
                $currentUnsigned = [int64]$currentValue -band 0xFFFFFFFFL
                if ($currentUnsigned -eq $expected) { Write-Host "OK       $label" }
                else { Write-Host "DRIFTED  $label (expected $expected, found $currentValue)" }
            }
            elseif ($entry.Value -match '^"(.*)"$') {
                $expected = $Matches[1]
                if ($currentValue -eq $expected) { Write-Host "OK       $label" }
                else { Write-Host "DRIFTED  $label (expected '$expected', found '$currentValue')" }
            }
            else {
                Write-Host "SKIPPED  $label (unsupported value format for verify)"
            }
        }
    }
}

if ($VibeCheck) {
    Invoke-VibeCheck
    return
}

# --- Refuse to run on a device that looks corporate-managed. ---

if (-not $ThisPCIsGenuinelyMine) {
    $reasons = @()

    $dsregText = ""
    try { $dsregText = (dsregcmd /status 2>$null) -join "`n" } catch { }
    if ($dsregText -match 'AzureAdJoined\s*:\s*YES' -or $dsregText -match 'DomainJoined\s*:\s*YES' -or $dsregText -match 'EnterpriseJoined\s*:\s*YES') {
        $reasons += "dsregcmd reports this device is joined (Azure AD / Domain / Enterprise)"
    }

    if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) {
        $reasons += "this device is domain-joined (Win32_ComputerSystem.PartOfDomain)"
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Enrollments') {
        $enrolled = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue |
            Get-ItemProperty -ErrorAction SilentlyContinue |
            Where-Object { $_.EnrollmentState -eq 1 -or $_.ProviderID }
        if ($enrolled) { $reasons += "an active MDM enrollment was found under HKLM\SOFTWARE\Microsoft\Enrollments" }
    }

    if ($reasons.Count -gt 0) {
        Write-Host "This device looks corporate-managed:"
        $reasons | ForEach-Object { Write-Host " - $_" }
        Write-Host ""
        Write-Host "This script is meant for a personal, unmanaged laptop only - it disables"
        Write-Host "dmwappushservice, which breaks MDM/Intune enrollment."
        Write-Host ""
        # RunAnw.bat launches this with no arguments, so -ThisPCIsGenuinelyMine can't be passed
        # through - ask interactively rather than only exiting, in case this is a false
        # positive (e.g. leftover MDM enrollment remnants from a past unenrollment).
        $confirm = Read-Host ">> Is this really your personal machine? Continue anyway? (Y/N)"
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host "Refusing to run. Pass -ThisPCIsGenuinelyMine to skip this check next time."
            exit 1
        }
    }
}

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
    "Microsoft.Windows.Recall" # Not a real Appx as of 25H2 (Recall ships as an optional
    "Microsoft.Recall"         # feature, removed below) - kept as a free hedge in case that changes
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
    "Microsoft.Windows.AIHub" # Copilot+ AI Hub app
    "Microsoft.PCManager" # Microsoft's own PC-cleanup/optimizer app
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

    if (-not $installed -and -not $provisioned) {
        Write-Host "SKIPPED $app - not installed"
        continue
    }

    # $pattern is a wildcard, not an exact name - log what it actually matched.
    $matchedNames = @($installed | ForEach-Object { $_.PackageFullName }) + @($provisioned | ForEach-Object { $_.PackageName }) |
        Sort-Object -Unique

    $failed = $false

    if ($installed) {
        try {
            $installed | Remove-AppxPackage -AllUsers -ErrorAction Stop
        }
        catch {
            $failed = $true
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
            $failed = $true
            Write-Host "FAILED to remove provisioned $app - $($_.Exception.Message)"
        }
    }

    if (-not $failed) { Write-Host "REMOVED $app (matched: $($matchedNames -join ', '))" }
}
Write-Host ""

# Recall ships as a Windows optional feature (Copilot+ PCs only), not an Appx package -
# the applist above can't remove it. Absent entirely on non-Copilot+ hardware.
Write-Host "------------------------"
Write-Host "-- Removing Recall    --"
Write-Host "------------------------"
Write-Host ""

$recallFeature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue

if (-not $recallFeature) {
    Write-Host "SKIPPED Recall - optional feature not present on this device"
}
elseif ($recallFeature.State -eq 'Disabled') {
    Write-Host "SKIPPED Recall - already disabled"
}
else {
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction Stop | Out-Null
        Write-Host "REMOVED Recall (restart required to finish)"
    }
    catch {
        Write-Host "FAILED to remove Recall - $($_.Exception.Message)"
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

if (-not $oneDrivePresent) {
    Write-Host "SKIPPED OneDrive - not installed"
}
else {
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

    if ($removed) { Write-Host "REMOVED OneDrive" }
    else { Write-Host "FAILED to remove OneDrive - no removal method succeeded" }
}
Write-Host ""

# Apply every .reg file in RegFiles\; delete a file there to opt out of that setting.
Write-Host "------------------------"
Write-Host "-- Disabling features --"
Write-Host "------------------------"
Write-Host ""

$regFiles = Get-ChildItem -Path "$PSScriptRoot\RegFiles\*.reg" -ErrorAction SilentlyContinue | Sort-Object Name

foreach ($file in $regFiles) {
    $output = reg import "$($file.FullName)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "APPLIED $($file.Name)"
    }
    else {
        Write-Host "FAILED to import $($file.Name) (reg exit $LASTEXITCODE)"
        $output | ForEach-Object { Write-Host "  $_" }
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
    @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "KernelCeipTask" }
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
        Write-Host "SKIPPED $taskId - not found"
        continue
    }

    if ($taskObj.State -eq 'Disabled') {
        Write-Host "SKIPPED $taskId - already disabled"
        continue
    }

    try {
        Disable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null
        Write-Host "DISABLED $taskId"
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
