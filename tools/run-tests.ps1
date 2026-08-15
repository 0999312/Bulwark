# GUT 全量测试运行脚本（固化 AGENTS.md §7 的沙箱注意事项）
# 用法：pwsh -File tools/run-tests.ps1
# 注意：必须重定向 APPDATA，否则沙箱下引擎写 user:// 崩溃；测试后清理 .appdata
$ErrorActionPreference = "Stop"
$project = "E:\godot_learning\projects\godot_dsh_test"
$godot = "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe"

$env:APPDATA = Join-Path $project ".appdata"
& $godot --headless -s addons/gut/gut_cmdln.gd --path $project
$exitCode = $LASTEXITCODE
Remove-Item (Join-Path $project ".appdata") -Recurse -Force -ErrorAction SilentlyContinue
exit $exitCode
