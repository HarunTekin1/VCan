<#
collect_device_logs.ps1
Usage: Open PowerShell in the project root and run:
  powershell -ExecutionPolicy Bypass -File .\collect_device_logs.ps1

This script requires `adb` in PATH and will collect device info, dumpsys, and logcat
and create a zip in the project folder. Then upload the zip here for analysis.
#>

$ErrorActionPreference = 'Stop'

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$dst = Join-Path -Path (Get-Location) -ChildPath "device_logs_$ts"
New-Item -Path $dst -ItemType Directory -Force | Out-Null

function Run-Adb($name, $cmd) {
    $out = Join-Path $dst ($name + ".txt")
    Write-Output "Running adb: $cmd -> $out"
    try {
        adb shell "$cmd" > $out 2>&1
    } catch {
        Write-Warning "Failed running adb shell $cmd; trying raw adb exec-out"
        adb exec-out "$cmd" > $out 2>&1
    }
}

# Basic device list
Write-Output "Collecting device list..."
adb devices -l > (Join-Path $dst "adb_devices.txt") 2>&1

# Network checks
Write-Output "Collecting network checks..."
Run-Adb "ping_dns" "ping -c 3 8.8.8.8"
Run-Adb "ping_google" "ping -c 3 google.com"
Run-Adb "dns_prop" "getprop net.dns1"
Run-Adb "ip_wlan" "ip -f inet addr show wlan0"

# Play services / package info
Write-Output "Collecting Play Services and package info..."
Run-Adb "gms_dump" "dumpsys package com.google.android.gms"
Run-Adb "packages_all" "pm list packages"
Run-Adb "vcan_packages" "pm list packages | grep vcan || pm list packages | findstr /I vcan"
Run-Adb "vcan_pkg_info" "dumpsys package com.example.vcan"

# Logcat (full) and filtered auth logs
Write-Output "Collecting logcat (this may take a moment)..."
adb logcat -d > (Join-Path $dst "full_logcat.txt") 2>&1

Write-Output "Filtering auth-related log lines..."
$fullLog = Join-Path $dst "full_logcat.txt"
$filtered = Join-Path $dst "auth_filtered.txt"
Select-String -Path $fullLog -Pattern 'FirebaseAuth','GoogleSign','ERROR','Exception','AppCheck','reCAPTCHA','broker','ManagedChannelImpl','auth' -SimpleMatch -CaseSensitive:$false | Out-File -FilePath $filtered -Encoding utf8

# Pull previously created files on device (if present)
Write-Output "Attempting to pull any diagnostic files from /sdcard..."
$files = @('ping1.txt','ping2.txt','dns.txt','ip.txt','gms_dump.txt','packages.txt','vcan_pkg.txt','full_logcat.txt')
foreach ($f in $files) {
    $remote = "/sdcard/$f"
    $local = Join-Path $dst ("pulled_" + $f)
    try {
        adb pull $remote $local | Out-Null
        if (Test-Path $local) { Write-Output "Pulled $remote -> $local" }
    } catch {
        # ignore
    }
}

# Create zip
$zip = Join-Path (Get-Location) ("device_logs_$ts.zip")
Write-Output "Creating ZIP: $zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $dst\* -DestinationPath $zip
Write-Output "Done. Log archive created: $zip"
Write-Output "Please upload $zip here (attach) so I can analyze the logs and give remediation steps." 

# Exit
Exit 0
