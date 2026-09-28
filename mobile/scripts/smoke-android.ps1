param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [string]$Apk = "$PSScriptRoot\..\build\app\outputs\flutter-apk\app-release.apk",
    [string]$Serial = 'emulator-5554'
)
$ErrorActionPreference = 'Stop'
function Invoke-Adb {
    $result = & $Adb -s $Serial @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
    return $result
}

# Run against a dedicated test device: this clears its logcat buffers.
Invoke-Adb install -r $Apk
Invoke-Adb shell am force-stop com.matchiq.matchiq
Invoke-Adb logcat -c
Invoke-Adb shell am start -W -n com.matchiq.matchiq/.MainActivity
Start-Sleep -Seconds 15
$crashes = Invoke-Adb logcat -d -b crash
if (($crashes -join "`n") -match 'com\.matchiq\.matchiq') {
    throw ($crashes -join "`n")
}
$appProcess = Invoke-Adb shell pidof com.matchiq.matchiq
if (-not $appProcess) { throw 'MatchIQ did not remain running.' }
$activity = Invoke-Adb shell dumpsys activity activities
if (($activity -join "`n") -notmatch 'mResumedActivity:.*com\.matchiq\.matchiq') {
    throw 'MatchIQ is not the foreground activity.'
}
Write-Output "PASS: release APK is running in the foreground (PID $appProcess)."
