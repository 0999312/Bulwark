# One-click launch of M2 dual clients (window mode, manual acceptance).
# Both clients share the same keybindings (WASD / mouse / LMB): keyboard & mouse
# input belongs to the focused window; click each window to give it focus.
# Usage: pwsh tools/run-dual.ps1 [-Port 31007] [-Address 127.0.0.1]
#   LAN play: pass the host LAN IP to -Address (open the port in host firewall).
param(
    [int]$Port = 31007,
    [string]$Address = "127.0.0.1"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe"
if (-not (Test-Path $godot)) { throw "Godot engine not found: $godot" }

# Separate user:// per process (avoid engine cache/log clashes)
$appdataBase = Join-Path $root ".appdata-dual"
Remove-Item "$appdataBase" -Recurse -Force -ErrorAction SilentlyContinue

$env:APPDATA = "$appdataBase-host"
Start-Process -FilePath $godot -ArgumentList "--path", $root, "--", "--net=host", "--port=$Port"
Write-Host "[host] starting... (port $Port)"

Start-Sleep -Seconds 2

$env:APPDATA = "$appdataBase-client"
Start-Process -FilePath $godot -ArgumentList "--path", $root, "--", "--net=client", "--port=$Port", "--address=$Address"
Write-Host "[client] starting... (connect $Address`:$Port)"

Write-Host ""
Write-Host "Both clients launched (shared keys WASD/mouse/LMB; click each window to focus)."
Write-Host "Close the windows to exit."
