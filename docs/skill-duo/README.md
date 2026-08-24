# Godot Skill Duo 导入模板（GodotPrompter + GD-Agentic-Skills）

> 一套「主 + 辅」双体系模板：**GodotPrompter 当工作流底盘**，**GD-Agentic-Skills 当深度参考库**。
> 目标：让每个新 Godot 项目在 5 分钟内接入两套技能，同时避免「全部装、上下文爆炸、同主题打架」。

## 组成

| 文件 | 作用 |
|---|---|
| `duo-skill-index.json` | 机器可读任务索引：primary / alternates / rule（gp_first / gp_only / gd_only / either） |
| `using-godot-skill-duo/SKILL.md` | 路由技能：何时走 GP、何时走 GD、DIA 访问协议、冲突去重表、反模式 |
| `AGENTS.md.snippet` | 粘贴到项目 `AGENTS.md` 的路由卡（双注释标记 `<!-- skill-duo:begin/end -->`，脚本可幂等追加） |
| `setup-godot-skill-duo.ps1` | 一键初始化/更新：克隆到 `.research/`、安装路由技能到 `.dsh/skills/`、可选写入 AGENTS.md |

## 一次导入（新项目）

1. 把本 `docs/skill-duo/` 目录复制到新项目，并把 `tools/setup-godot-skill-duo.ps1` 复制到新项目的 `tools/`。
2. 在项目根目录运行：

   ```powershell
   pwsh tools/setup-godot-skill-duo.ps1
   ```

   默认行为：
   - `.research/gd-agentic-skills` ← 克隆/更新 GD-Agentic-Skills（不入库）
   - `.research/godotprompter` ← 克隆/更新 GodotPrompter（若项目里已有 `tools/update-godotprompter.ps1` 则调用它，避免重复逻辑）
   - `.dsh/skills/using-godot-skill-duo/` ← 安装路由技能 + 任务索引

3. 可选，把路由卡写进项目说明：

   ```powershell
   pwsh tools/setup-godot-skill-duo.ps1 -ApplyAgentSection
   ```

4. 如果宿主不是 DSH（Claude Code / Cursor / Copilot / Codex / OpenCode），把路由技能目录复制到对应技能目录即可：
   - Claude Code：`.claude/skills/using-godot-skill-duo/`
   - Cursor：`.cursor/rules/using-godot-skill-duo/`（内容对齐）
   - Codex：`~/.codex/skills/using-godot-skill-duo/`

## 使用约定

- 每项任务先查 `duo-skill-index.json`，按 `rule` 走：
  - `gp_first` → 用 `skill` 工具加载 GodotPrompter 技能（GP 是主）。
  - `gd_only` → 用 `read` 直接读 `.research/gd-agentic-skills/skills/<name>/SKILL.md`（GD 是参考）。
  - `gp_only` → 只用 GodotPrompter。
- GD 不批量安装、不注册进技能库；「克隆 + 读文件」是官方 DIA 路径。
- 同主题冲突以去重表为准：默认 GP。

## 更新

```powershell
pwsh tools/setup-godot-skill-duo.ps1   # GD + 路由模板/索引
pwsh tools/update-godotprompter.ps1    # GP 技能（如果项目已带该脚本）
```

## 自定义

- **许可证**：GodotPrompter 为 MIT；GD-Agentic-Skills 虽为 LGPL-3.0，但官方 README 明确说明——基于该技能库构建/编译的游戏**可闭源、可正常商业发布**，只有对 GDSkills 库本身的修改需保持开源。
- 换仓库：改 `setup-godot-skill-duo.ps1` 顶部 URL。
- 换宿主：改 `-SkillDir` 或直接复制 `using-godot-skill-duo` 到宿主技能目录。
- 裁剪索引：编辑 `duo-skill-index.json`（保留项目相关条目即可，模板为全量参考）。
- 本模板出处：`E:/godot_learning/projects/godot_dsh_clickergame/docs/skill-duo`（Godot 4.7 mono + DSH，已装载 55 个 GP 技能 + game-architect）。

