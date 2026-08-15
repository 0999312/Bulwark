# 一键拉起 M2 双客户端（窗口模式，人工验收）
# 双端共用同一套键位（WASD/鼠标/左键）：键盘与鼠标输入属于有焦点的窗口，
# 各自点击对应窗口获得焦点即可独立操作
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

Write-Host "双客户端已拉起（共用键位 WASD/鼠标/左键，各自点击窗口获得焦点后独立操作）。"
Write-Host "关闭窗口即退出。"
