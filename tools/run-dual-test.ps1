# M2 headless 双进程冒烟验收（自动化验证"2 客户端同局稳定"的最小回归）
# host 与 client 各自跑 --smoke：统计快照/意图/敌人镜像峰值，到点写 user://smoke-result.txt 并退出
# 验收标准：双端结果文件均为 ok（Godot 端写文件判定，规避 stdout 缓冲/退出时序问题）
# 用法: pwsh tools/run-dual-test.ps1 [-Duration 40] [-Port 31008]
param(
    [int]$Duration = 40,
    [int]$Port = 31008
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe"
if (-not (Test-Path $godot)) { throw "Godot 引擎未找到: $godot" }

$appdataBase = Join-Path $root ".appdata-smoke"
Remove-Item "$appdataBase" -Recurse -Force -ErrorAction SilentlyContinue
$hostOut = Join-Path $root ".smoke-host.log"
$clientOut = Join-Path $root ".smoke-client.log"
Remove-Item "$hostOut", "$clientOut", "$hostOut.err", "$clientOut.err" -Force -ErrorAction SilentlyContinue

Write-Host "[smoke] 启动 host（headless，端口 $Port，时长 ${Duration}s）…"
$env:APPDATA = "$appdataBase-host"
$hostProc = Start-Process -FilePath $godot -ArgumentList "--headless", "--path", $root, "--", "--net=host", "--port=$Port", "--smoke", "--smoke-duration=$Duration" -RedirectStandardOutput $hostOut -RedirectStandardError "$hostOut.err" -PassThru -NoNewWindow

Start-Sleep -Seconds 3

Write-Host "[smoke] 启动 client（headless，loopback）…"
$env:APPDATA = "$appdataBase-client"
$clientProc = Start-Process -FilePath $godot -ArgumentList "--headless", "--path", $root, "--", "--net=client", "--port=$Port", "--address=127.0.0.1", "--smoke", "--smoke-duration=$Duration" -RedirectStandardOutput $clientOut -RedirectStandardError "$clientOut.err" -PassThru -NoNewWindow

$timeoutMs = $Duration * 1000 + 60000
$hostExited = $hostProc.WaitForExit($timeoutMs)
$clientExited = $clientProc.WaitForExit($timeoutMs)
if (-not $hostExited) { $hostProc.Kill() }
if (-not $clientExited) { $clientProc.Kill() }

Write-Host "`n===== host 输出（尾部）====="
Get-Content $hostOut -Tail 12 -ErrorAction SilentlyContinue
Write-Host "`n===== client 输出（尾部）====="
Get-Content $clientOut -Tail 12 -ErrorAction SilentlyContinue

# 判定以 Godot 端写出的结果文件为准（user://smoke-result.txt）
function Get-SmokeResult([string]$appdataDir) {
    $file = Get-ChildItem -Path $appdataDir -Recurse -Filter "smoke-result.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $file) { return "missing" }
    return (Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue).Trim()
}
$hostResult = Get-SmokeResult "$appdataBase-host"
$clientResult = Get-SmokeResult "$appdataBase-client"

Remove-Item "$appdataBase" -Recurse -Force -ErrorAction SilentlyContinue

if ($hostResult -eq "ok" -and $clientResult -eq "ok") {
    Write-Host "`n[smoke] PASS：host=$hostResult client=$clientResult —— 双进程同步链路全部通过。"
    exit 0
}
Write-Host "`n[smoke] FAIL：host=$hostResult client=$clientResult（详见 .smoke-host.log / .smoke-client.log）"
exit 1
