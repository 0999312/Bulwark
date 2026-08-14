# 同步 GodotPrompter 技能到本项目的脚本
# 用法: pwsh tools/update-godotprompter.ps1
# 说明: 从上游 https://github.com/jame581/GodotPrompter.git 拉取技能，同步到 .dsh/skills/
#       本地克隆保留在 .research/godotprompter（不入库，见 .gitignore）

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$cloneDir = Join-Path $projectRoot ".research\godotprompter"
$skillRoot = Join-Path $projectRoot ".dsh\skills"
$upstream = "https://github.com/jame581/GodotPrompter.git"

Write-Host "==> 检查本地克隆..." -ForegroundColor Cyan
if (-not (Test-Path (Join-Path $cloneDir ".git"))) {
    Write-Host "==> 克隆上游仓库到 $cloneDir" -ForegroundColor Cyan
    git clone --depth 1 $upstream $cloneDir
    if ($LASTEXITCODE -ne 0) { throw "git clone 失败" }
} else {
    Write-Host "==> 拉取上游更新..." -ForegroundColor Cyan
    git -C $cloneDir pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull 失败" }
}

Write-Host "==> 同步 skills/ -> $skillRoot" -ForegroundColor Cyan
if (-not (Test-Path $skillRoot)) { New-Item -ItemType Directory -Force $skillRoot | Out-Null }
robocopy (Join-Path $cloneDir "skills") $skillRoot /E /NFL /NDL /NJH /NJS
if ($LASTEXITCODE -gt 7) { throw "robocopy 失败 (exit $LASTEXITCODE)" }

$count = (Get-ChildItem $skillRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") }).Count
Write-Host "==> 完成：共 $count 个技能目录（含 game-architect 等项目自有技能）" -ForegroundColor Green

Write-Host ""
Write-Host "提示：DSH 会热监听技能目录变化，新技能无需重启即可被发现。" -ForegroundColor Yellow
