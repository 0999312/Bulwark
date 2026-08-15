# 一键拉起 M2 双客户端（窗口模式，人工验收）
# host 窗口（WASD/鼠标/左键）+ client 窗口（方向键/IJKL/空格，备选键位）
# 用法: pwsh tools/run-dual.ps1 [-Port 31007] [-Address 127.0.0.1]
#   局域网联机：client 端 Address 传 host 的局域网 IP（host 防火墙需放行 Port）
param(
    [int]$Port = 31007,
    [string]$Address = "127.0.0.1"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe"
if (-not (Test-Path $godot)) { throw "Godot 引擎未找到: $godot" }

# 双进程独立 user://（避免引擎缓存/日志互踩）
$appdataBase = Join-Path $root ".appdata-dual"
Remove-Item "$appdataBase" -Recurse -Force -ErrorAction SilentlyContinue

$env:APPDATA = "$appdataBase-host"
Start-Process -FilePath $godot -ArgumentList "--path", $root, "--", "--net=host", "--port=$Port"
Write-Host "[host] 启动中… (端口 $Port)"

Start-Sleep -Seconds 2

$env:APPDATA = "$appdataBase-client"
Start-Process -FilePath $godot -ArgumentList "--path", $root, "--", "--net=client", "--port=$Port", "--address=$Address"
Write-Host "[client] 启动中… (连接 $Address`:$Port)"

Write-Host ""
Write-Host "双客户端已拉起：host = WASD/鼠标/左键；client = 方向键/IJKL/空格（P 暂停 / L 换弹 / U-O-I 切枪 / Enter 放路障）"
Write-Host "关闭窗口即退出。"
