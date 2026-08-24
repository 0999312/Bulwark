<#
.SYNOPSIS
  Godot Skill Duo 一键初始化/更新（GodotPrompter 主 + GD-Agentic-Skills 辅）
.DESCRIPTION
  - 克隆/更新 GD-Agentic-Skills 到 .research\gd-agentic-skills（不入库）
  - 克隆/更新 GodotPrompter 到 .research\godotprompter（若已有 update-godotprompter.ps1 则调用之）
  - 安装路由技能 using-godot-skill-duo 到 .dsh\skills\（含 duo-skill-index.json）
  - 可选：向 AGENTS.md 幂等追加路由卡（-ApplyAgentSection）
.PARAMETER ProjectRoot
  项目根目录（默认脚本上级目录）
.PARAMETER SkillDir
  技能安装目录（默认 .dsh\skills）
.PARAMETER RepoRoot
  上游克隆目录（默认 .research）
.PARAMETER SkipGodotPrompter
  只初始化 GD + 路由，不碰 GodotPrompter
.PARAMETER ApplyAgentSection
  在 AGENTS.md 追加/更新 Godot Skill Duo 路由卡
.EXAMPLE
  pwsh tools/setup-godot-skill-duo.ps1
.EXAMPLE
  pwsh tools/setup-godot-skill-duo.ps1 -ApplyAgentSection
#>
param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$SkillDir = (Join-Path $ProjectRoot ".dsh\skills"),
  [string]$RepoRoot = (Join-Path $ProjectRoot ".research"),
  [switch]$SkipGodotPrompter,
  [switch]$ApplyAgentSection
)

$ErrorActionPreference = "Stop"
$gdRepo = "https://github.com/thedivergentai/GD-Agentic-Skills.git"
$gpRepo = "https://github.com/jame581/GodotPrompter.git"
$gdDir = Join-Path $RepoRoot "gd-agentic-skills"
$gpDir = Join-Path $RepoRoot "godotprompter"
$templateDir = Join-Path $ProjectRoot "docs\skill-duo\using-godot-skill-duo"

function Update-GitRepo {
  param([string]$Url, [string]$Dir)
  if (-not (Test-Path (Join-Path $Dir ".git"))) {
    Write-Host "==> 克隆 $Url -> $Dir" -ForegroundColor Cyan
    git clone --depth 1 $Url $Dir
    if ($LASTEXITCODE -ne 0) { throw "git clone 失败: $Url" }
  } else {
    Write-Host "==> 更新 $Dir" -ForegroundColor Cyan
    git -C $Dir pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull 失败: $Dir" }
  }
}

function Test-MarkerInFile {
  param([string]$Path, [string]$Marker)
  if (-not (Test-Path $Path)) { return $false }
  ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)) -match $Marker
}

Write-Host "==> Godot Skill Duo 初始化开始" -ForegroundColor Green
Write-Host "    ProjectRoot = $ProjectRoot"
Write-Host "    SkillDir    = $SkillDir"
Write-Host "    RepoRoot    = $RepoRoot"

# 1. 上游仓库
New-Item -ItemType Directory -Force -Path $RepoRoot | Out-Null
Update-GitRepo -Url $gdRepo -Dir $gdDir
if (-not $SkipGodotPrompter) {
  $gpUpdater = Join-Path $ProjectRoot "tools\update-godotprompter.ps1"
  if (Test-Path $gpUpdater) {
    Write-Host "==> 复用项目自带 GP 更新脚本..." -ForegroundColor Cyan
    & $gpUpdater
  } else {
    Update-GitRepo -Url $gpRepo -Dir $gpDir
    $gpSkillSrc = Join-Path $gpDir "skills"
    New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
    robocopy $gpSkillSrc $SkillDir /E /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -gt 7) { throw "robocopy 失败 (exit $LASTEXITCODE)" }
  }
}

# 2. 路由技能 + 任务索引
if (-not (Test-Path $templateDir)) {
  throw "未找到模板目录: $templateDir（请确保 docs/skill-duo/ 已复制到项目）"
}
Write-Host "==> 安装路由技能 using-godot-skill-duo" -ForegroundColor Cyan
$skillTarget = Join-Path $SkillDir "using-godot-skill-duo"
New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
robocopy $templateDir $skillTarget /E /NFL /NDL /NJH /NJS
if ($LASTEXITCODE -gt 7) { throw "robocopy 模板失败 (exit $LASTEXITCODE)" }

# 3. 可选：AGENTS.md 路由卡
if ($ApplyAgentSection) {
  $snippetPath = Join-Path $ProjectRoot "docs\skill-duo\AGENTS.md.snippet"
  if (-not (Test-Path $snippetPath)) { throw "缺少 AGENTS.md.snippet" }
  $agenPath = Join-Path $ProjectRoot "AGENTS.md"
  if (Test-MarkerInFile -Path $agenPath -Marker "skill-duo:begin") {
    Write-Host "==> AGENTS.md 已含 Skill Duo 路由卡，跳过" -ForegroundColor Yellow
  } else {
    $snippet = [System.IO.File]::ReadAllText($snippetPath, [System.Text.Encoding]::UTF8)
    if (Test-Path $agenPath) {
      Add-Content -Path $agenPath -Value ("`r`n" + $snippet) -Encoding UTF8
    } else {
      Set-Content -Path $agenPath -Value $snippet -Encoding UTF8
    }
    Write-Host "==> 已向 AGENTS.md 追加路由卡" -ForegroundColor Green
  }
}

# 4. 汇总
$gdCount = (Get-ChildItem (Join-Path $gdDir "skills") -Directory | Measure-Object).Count
$gpCount = (Get-ChildItem $SkillDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") } | Measure-Object).Count
$routerOk = Test-Path (Join-Path $skillTarget "SKILL.md")
Write-Host ""
Write-Host "==> 完成" -ForegroundColor Green
Write-Host "    GD-Agentic-Skills 技能数 : $gdCount （参考仓库，未整装）"
Write-Host "    技能目录 SKILL.md 总数    : $gpCount （含项目自有）"
Write-Host "    路由技能已安装           : $routerOk"
Write-Host ""
Write-Host "下一步：" -ForegroundColor Yellow
Write-Host "  - Godot 任务先加载 using-godot-skill-duo，查 duo-skill-index.json 路由"
Write-Host "  - 更新 GD/模板 : pwsh tools/setup-godot-skill-duo.ps1"
Write-Host "  - 更新 GP      : pwsh tools/update-godotprompter.ps1"

