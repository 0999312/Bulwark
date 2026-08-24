---
name: using-godot-skill-duo
description: "双技能体系引导（GodotPrompter 主 + GD-Agentic-Skills 辅）。加载本技能确定一次 Godot 任务用哪套体系、加载哪个技能、读哪份参考：流程/评审/测试/C#/第三方 addon 走 GodotPrompter；生产脚本/类型蓝图/4.7 特性/迁移/数值平衡/视觉验收走 GD-Agentic-Skills。内含 duo-skill-index.json 任务索引与冲突去重表。"
---

# 使用 Godot Skill Duo（双体系技能路由）

## 什么时候加载

- 任何 **Godot 开发任务**的第一步：先加载本技能（或 `using-godot-prompter`），再决定后续加载哪个技能。
- 任务是「流程/架构/评审/测试/C#/第三方 addon」→ 走 **GodotPrompter**。
- 任务是「具体生产代码/类型玩法蓝图/4.7 专属特性/版本迁移/数值平衡/视觉验收」→ 走 **GD-Agentic-Skills**。
- 同时涉及 → **GP 先架构/流程，GD 补代码/蓝图**。

## 两套来源

| 来源 | 形态 | 位置 | 加载方式 |
|---|---|---|---|
| GodotPrompter (GP) | 已安装技能，55 个 | `.dsh/skills/` | 用 `skill` 工具按名加载（DSH 工具映射见 AGENTS.md §4，Claude Code 工具名为规范） |
| GD-Agentic-Skills (GD) | 只读参考仓库，99 技能 + 2418 个 .gd | `.research/gd-agentic-skills/` | **不注册技能**：用 read 读 `skills/<name>/SKILL.md`，必要时再读 `references/` 与 `scripts/<file>.gd` |

## 快速路由

先查本技能目录的 `duo-skill-index.json`（机器可读，含 primary / alternates / rule）。

常用规则：

- **gp_first**：GP 先行；GD 仅在需要代码密度时补充。
- **gp_only**：只有 GP 覆盖（C#、第三方 addon、教学、assets/math 等）。
- **gd_only**：只有 GD 覆盖（类型蓝图、战斗/经济/任务、迁移、移植、Agent Vision 等）。
- **either**：两套都可用，默认 gp_first。

## GD 访问协议（DIA）

1. 读 `.research/gd-agentic-skills/skills_index.json` 定位技能（关键词索引）。
2. 读 `.research/gd-agentic-skills/skills/<name>/SKILL.md`。
3. 按 SKILL.md 里的 Workflow router / 脚本索引，只读当前分支需要的 `scripts/*.gd`，不要一次性全读。
4. 复杂项目再读 `godot-master/SKILL.md` 拿架构决策矩阵与反模式。
5. 注意 GD 目标是 **Godot 4.7+**；若项目 <4.7 需先看 `godot-version-migration`。

## 冲突去重（同主题只选一个主）

| 主题 | GodotPrompter（主） | GD-Agentic-Skills（参考） |
|---|---|---|
| 状态机 | state-machine | godot-state-machine-advanced |
| 信号/事件 | event-bus | godot-signal-architecture |
| 组件 | component-system | godot-composition / godot-composition-apps |
| 物理 | physics-system | godot-2d-physics / godot-physics-3d |
| 动画 | animation-system | godot-animation-player / godot-animation-tree-mastery / godot-2d-animation |
| 相机 | camera-system | godot-camera-systems |
| 音频 | audio-system | godot-audio-systems |
| 玩家 | player-controller | godot-characterbody-2d |
| 存档 | save-load | godot-save-load-systems |
| 库存/能力 | inventory-system / ability-system | godot-inventory-system / godot-ability-system |
| 项目搭建 | godot-project-setup | godot-project-foundations / godot-project-templates |
| 导出 | export-pipeline | godot-export-builds |
| 优化/调试/测试 | godot-optimization / godot-debugging / godot-testing | godot-performance-optimization / godot-debugging-profiling / godot-testing-patterns |
| Shader/粒子 | shader-basics / particles-vfx | godot-shaders-basics / godot-particles |

**规则**：同主题默认 **GP**；只有需要 GD 独有的生产脚本、类型蓝图或 4.7 细节时才读 GD，且读完后不要把 GD 内容整段搬进 AGENTS.md / 上下文。

## 反模式

- ❌ 同时把两套同主题技能全量塞进上下文（上下文风暴）。
- ❌ 整体安装 GD 全部 99 技能（GD README 明确 Power of One / Install-All-Fails）。
- ℹ️ 许可证：GD 为 LGPL-3.0，但按官方 README 说明——用该技能库构建/编译自己的游戏可闭源、可正常商业发布；只有对 GDSkills 库本身的修改需保持开源。
- ❌ 忘了 GD 无 C#：C# 需求一律回 GP。

## 更新

- GP：`pwsh tools/update-godotprompter.ps1`
- GD + 本路由：`pwsh tools/setup-godot-skill-duo.ps1`

