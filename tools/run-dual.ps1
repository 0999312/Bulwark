# One-click launch of M2 dual clients (window mode, manual acceptance).
# Both clients share the same keybindings (WASD / mouse / LMB): keyboard & mouse
# input belongs to the focused window; click each window to give it focus.
# Usage: pwsh tools/run-dual.ps1 [-Port 31007] [-Address 127.0.0.1]
#   LAN play: pass the host LAN IP to -Address (open the port in host firewall).
#   Internet play (M3 problem 5): add -Relay [-RelayUrl <relay>] [-AppId <token>];
#   host creates a NodeTunnel room, the script reads the room id from the host log
#   and starts the client with --address=<room id>.
param(
    [int]$Port = 31007,
    [string]$Address = "127.0.0.1",
    [switch]$Relay,
    [string]$RelayUrl = "us-east.nodetunnel.io:8080",
    [string]$AppId = "75wszckt2unslne"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe"
if (-not (Test-Path $godot)) { throw "Godot engine not found: $godot" }

# Separate user:// per process (avoid engine cache/log clashes)
$appdataBase = Join-Path $root ".appdata-dual"
Remove-Item "$appdataBase" -Recurse -Force -ErrorAction SilentlyContinue

if ($Relay) {
    $hostLog = Join-Path $root ".relay-host.log"
    Remove-Item "$hostLog", "$hostLog.err" -Force -ErrorAction SilentlyContinue
    $env:APPDATA = "$appdataBase-host"
    Start-Process -FilePath $godot -ArgumentList "--path", $root, "--", "--net=host", "--relay", "--relay-url=$RelayUrl", "--app-id=$AppId" -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err"
    Write-Host "[host] relay mode starting... (relay $RelayUrl, app=$AppId)"

    # Wait for the host to create the room and print room_id=<id>
    $roomId = ""
    for ($i = 0; $i -lt 120 -and $roomId -eq ""; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Path $hostLog) {
            $m = Select-String -Path $hostLog -Pattern "room_id=(\S+)" | Select-Object -Last 1
            if ($null -ne $m -and $m.Matches.Count -gt 0) {
                $roomId = $m.Matches[0].Groups[1].Value
            }
        }
    }
    if ($roomId -eq "") {
        Write-Host "[host] room id not obtained (relay down or bad token?) - see $hostLog"
        exit 1
    }
    Write-Host "[host] room_id=$roomId"

    Start-Sleep -Seconds 1
    $env:APPDATA = "$appdataBase-client"
    Start-Process -FilePath $godot -ArgumentList "--path", $root, "--", "--net=client", "--relay", "--relay-url=$RelayUrl", "--app-id=$AppId", "--address=$roomId"
    Write-Host "[client] joining room $roomId via relay..."
} else {
    $env:APPDATA = "$appdataBase-host"
    Start-Process -FilePath $godot -ArgumentList "--path", $root, "--", "--net=host", "--port=$Port"
    Write-Host "[host] starting... (port $Port)"

    Start-Sleep -Seconds 2

    $env:APPDATA = "$appdataBase-client"
    Start-Process -FilePath $godot -ArgumentList "--path", $root, "--", "--net=client", "--port=$Port", "--address=$Address"
    Write-Host "[client] starting... (connect $Address`:$Port)"
}

Write-Host ""
Write-Host "Both clients launched (shared keys WASD/mouse/LMB; click each window to focus)."
Write-Host "Close the windows to exit."
