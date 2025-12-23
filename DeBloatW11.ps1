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

# List of common bloatware Appx packages, remove to keep
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
    "Microsoft.Copilot"
    "Microsoft.OutlookForWindows"
    "Microsoft.StartExperiencesApp"
    "Microsoft.Whiteboard"
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

Write-Host "------------------------"
Write-Host "-- Removing Bloatware --"
Write-Host "------------------------"
Write-Host ""
foreach ($app in $applist) {
    Write-Host ">> Attempting to remove $app..."
    # Use Remove-AppxPackage to remove all other apps
    $app = '*' + $app + '*'
    try {
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
        Write-Host "$app has been removed."
    }
    catch {
        Write-Host ">> Failed to remove $app."
        Write-Host $psitem.Exception.StackTrace
    }

    # Remove provisioned app from OS image, so the app won't be installed for any new users
    try {
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
    }
    catch {
        Write-Host ">> Failed to remove $app."
        Write-Host $psitem.Exception.StackTrace
    }
}
Write-Host ""

# List of features in .\RegFiles without 'Disable_' prefix and '.reg' suffix
# remove to keep enabled
$features = @(
    "AI_Recall"
    "Copilot"
    "Telemetry"
    "Bing_Cortana_In_Search"
    "Edge_AI_Features"
    "Edge_Ads_And_Suggestions"
    "Lockscreen_Tips"
    "Windows_Suggestions"
    "Desktop_Spotlight"
    "Widgets_Service"
    "Notepad_AI_Features"
    "Paint_AI_Features"
    "Settings_365_Ads"
)

Write-Host "------------------------"
Write-Host "-- Disabling features --"
Write-Host "------------------------"
Write-Host ""
foreach ($feature in $features) {
    try {
        Write-Host ">> Attempting to disable $feature..."
        reg import "$PSScriptRoot\RegFiles\Disable_$($feature).reg"
        Write-Host "$feature has been disabled."
    }
    catch {
        Write-Host ">> Failed to disable $feature."
        Write-Host $psitem.Exception.StackTrace
    }
}
Write-Host ""

Write-Host "-------------------------------------------"
Write-Host "-- Bloatware removal complete!           --"
Write-Host "-- NOTE: A system restart is recommended --"
Write-Host "-------------------------------------------"
Write-Host ""

# Ask for restart
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
