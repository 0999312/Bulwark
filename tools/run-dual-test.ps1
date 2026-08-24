# M2 headless dual-process smoke acceptance (automated regression for
# "2 clients in one session stay stable"). M3: optional NodeTunnel relay mode.
# host & client each run with --smoke: track snapshot/intent/enemy-mirror stats,
# write user://smoke-result.txt when done, then exit.
# Acceptance: both result files equal "ok" (Godot writes the file, avoiding
# stdout buffering / exit-timing issues in the harness).
# Usage: pwsh tools/run-dual-test.ps1 [-Duration 40] [-Port 31008]
#   Relay mode (M3 problem 5): pwsh tools/run-dual-test.ps1 -Relay -AppId <token>
#   [-RelayUrl us-east.nodetunnel.io:8080]
param(
    [int]$Duration = 40,
    [int]$Port = 31008,
    [switch]$Relay,
    [string]$RelayUrl = "us-east.nodetunnel.io:8080",
    [string]$AppId = "75wszckt2unslne"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe"
if (-not (Test-Path $godot)) { throw "Godot engine not found: $godot" }

$appdataBase = Join-Path $root ".appdata-smoke"
Remove-Item "$appdataBase" -Recurse -Force -ErrorAction SilentlyContinue
$hostOut = Join-Path $root ".smoke-host.log"
$clientOut = Join-Path $root ".smoke-client.log"
Remove-Item "$hostOut", "$clientOut", "$hostOut.err", "$clientOut.err" -Force -ErrorAction SilentlyContinue

if ($Relay) {
    $hostArgs = "--headless", "--path", $root, "--", "--net=host", "--relay", "--relay-url=$RelayUrl", "--app-id=$AppId", "--smoke", "--smoke-duration=$Duration"
    $clientArgs = $null
} else {
    $hostArgs = "--headless", "--path", $root, "--", "--net=host", "--port=$Port", "--smoke", "--smoke-duration=$Duration"
    $clientArgs = "--headless", "--path", $root, "--", "--net=client", "--port=$Port", "--address=127.0.0.1", "--smoke", "--smoke-duration=$Duration"
}

Write-Host "[smoke] starting host (headless, $(if ($Relay) { "relay $RelayUrl" } else { "port $Port" }), ${Duration}s)..."
$env:APPDATA = "$appdataBase-host"
$hostProc = Start-Process -FilePath $godot -ArgumentList $hostArgs -RedirectStandardOutput $hostOut -RedirectStandardError "$hostOut.err" -PassThru -NoNewWindow

$roomId = ""
if ($Relay) {
    # Wait for the host to create the room and print room_id=<id>
    for ($i = 0; $i -lt 120 -and $roomId -eq ""; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Path $hostOut) {
            $m = Select-String -Path $hostOut -Pattern "room_id=(\S+)" | Select-Object -Last 1
            if ($null -ne $m -and $m.Matches.Count -gt 0) {
                $roomId = $m.Matches[0].Groups[1].Value
            }
        }
    }
    if ($roomId -eq "") {
        Write-Host "[smoke] room id not obtained (relay/auth failed?) - see $hostOut"
        $hostProc.Kill()
        exit 1
    }
    Write-Host "[smoke] room_id=$roomId"
    $clientArgs = "--headless", "--path", $root, "--", "--net=client", "--relay", "--relay-url=$RelayUrl", "--app-id=$AppId", "--address=$roomId", "--smoke", "--smoke-duration=$Duration"
}

Start-Sleep -Seconds 3

Write-Host "[smoke] starting client (headless, $(if ($Relay) { "room $roomId" } else { "loopback" }))..."
$env:APPDATA = "$appdataBase-client"
$clientProc = Start-Process -FilePath $godot -ArgumentList $clientArgs -RedirectStandardOutput $clientOut -RedirectStandardError "$clientOut.err" -PassThru -NoNewWindow

$timeoutMs = $Duration * 1000 + 60000
$hostExited = $hostProc.WaitForExit($timeoutMs)
$clientExited = $clientProc.WaitForExit($timeoutMs)
if (-not $hostExited) { $hostProc.Kill() }
if (-not $clientExited) { $clientProc.Kill() }

Write-Host "`n===== host output (tail) ====="
Get-Content $hostOut -Tail 12 -ErrorAction SilentlyContinue
Write-Host "`n===== client output (tail) ====="
Get-Content $clientOut -Tail 12 -ErrorAction SilentlyContinue

# Judge by the result file written by the Godot side (user://smoke-result.txt)
function Get-SmokeResult([string]$appdataDir) {
    $file = Get-ChildItem -Path $appdataDir -Recurse -Filter "smoke-result.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $file) { return "missing" }
    return (Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue).Trim()
}
$hostResult = Get-SmokeResult "$appdataBase-host"
$clientResult = Get-SmokeResult "$appdataBase-client"

Remove-Item "$appdataBase" -Recurse -Force -ErrorAction SilentlyContinue

if ($hostResult -eq "ok" -and $clientResult -eq "ok") {
    Write-Host "`n[smoke] PASS: host=$hostResult client=$clientResult - dual-process sync OK."
    exit 0
}
Write-Host "`n[smoke] FAIL: host=$hostResult client=$clientResult (see .smoke-host.log / .smoke-client.log)"
exit 1
