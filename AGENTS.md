# godot_dsh_test — 项目指令（AGENTS.md）

> 本文件由 DeepSeek Harness (DSH) 自动加载到本项目的每个会话，作为项目级工作指令。
> 更具体的指令优先于更宽泛的指令；本文件不覆盖系统、开发者或用户的直接指令。

## 1. 项目概况

- **引擎**: Godot 4.7 stable (mono，支持 C#)。引擎路径 `E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe`（目录名为旧版遗留，二进制实为 4.7.0 stable mono）
- **脚本语言**: 以 GDScript 为主，必要时 C#
- **开发环境**: DSH (DeepSeek Harness) Web — 工具均为小写命名（见 §4 工具映射）
- **交流语言**: 中文

## 2. 插件（addons/，全部已在 project.godot 启用）

| 插件 | 版本 | 用途 |
|------|------|------|
| mc_game_framework | v1.0.0 | 核心框架：EventBus、UIManager、Registry、Codec、I18N |
| guide | v0.13.0 | 输入映射与上下文系统（替代原生 Input Map，GUIDEAction / GUIDEMappingContext / GUIDEMappingContext） |
| sound_manager | v2.6.1 | 音频管理（音乐 / 音效 / 环境音） |
| gut | v9.6.0 | GDScript 单元测试框架 |
| kenney_interface_sounds | — | UI 音效素材包（无插件，纯资源） |

> dialogue_manager 插件已于 M2 前置处理中移除（项目无对话系统需求，且其 class_name 冲突长期干扰导入）。

## 3. 资源与目录约定

- `assets/fonts/` — MiSans-Semibold（中文友好字体，otf/ttf）
- `assets/theme/` — `minimal_vector.tres`（已接线到 project.godot）/ `modern_flat.tres`
- `assets/icons/` — 220 个单色 SVG 图标（按功能分类）
- `tools/generate_guide_context.gd` — GUIDE 上下文生成脚本（headless 运行，依赖 `res://input/actions/*.tres`，创建对应 Action 后使用）
- 新功能按模块放入 `scenes/`、`scripts/`、`resources/`、`input/` 等目录（按需创建），保持模块化

## 4. DSH 工具映射（GodotPrompter 技能以 Claude Code 工具名为规范）

| 技能中出现的工具名 | DSH 等价工具 |
|---|---|
| `TodoWrite` | `todo_write` |
| `Read` / `Write` / `Edit` | `read` / `write` / `edit` |
| `Bash` | `pwsh`（Windows PowerShell） |
| `Skill` | `skill`（按名称加载技能） |
| `Task` / 子代理 | `subagent` / `subagent_fork` |
| `WebSearch` | `web_search` |
| `Glob` / `Grep` | `glob` / `grep` |

## 5. GodotPrompter 技能路由卡

本项目已安装 **57 个项目技能**（`.dsh/skills/`，随仓库走）：55 个 GodotPrompter 技能 + `game-architect` 架构知识库 + `using-godot-skill-duo` 路由技能。

**使用规则：**

1. 涉及 Godot 开发任务时，先用 `skill` 工具加载 `using-godot-prompter`（引导技能，含技能目录与工具映射）。
2. 按任务领域加载对应技能（常用映射）：
   - 新系统/功能设计 → `godot-brainstorming`；大型架构 → `game-architect` + 领域技能
   - 玩家控制 → `player-controller` + `input-handling` + `state-machine`
   - 输入 → `input-handling`（注意本项目用 guide 插件，先读 `using-godot-prompter` 与插件文档）
   - 测试 → `godot-testing`（GUT）
   - 调试 → `godot-debugging`；代码评审 → `godot-code-review`
   - 优化 → `godot-optimization`；导出 → `export-pipeline`
3. 大型功能请按 §6 的策划 → 开发 → 评审流程执行。

## 6. 策划 → 开发 → 评审工作流（即插即用示例）

`docs/dev-example/README.md` 提供可直接使用的完整示例流程：

1. **策划**: 以 `docs/agent-prompts/godot-game-architect.md` 为提示词启动子代理（或直接要求加载 `godot-brainstorming` / `game-architect` 技能）
2. **实现**: `docs/agent-prompts/godot-game-dev.md`
3. **评审**: `docs/agent-prompts/godot-code-reviewer.md`

示例需求单：`docs/dev-example/feature-brief-example.md`（可替换为真实功能需求）

## 7. 测试与运行

```powershell
# 运行 GUT 单元测试
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless -s addons/gut/gut_cmdln.gd --path .

# 运行游戏
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .

# 首次导入/重新导入资源
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --import --path .
```

## 8. 注意事项

- **技能裁剪**：实际开发中如技能过多，可直接删除 `.dsh/skills/` 中不需要的条目（随仓库提交）
- **技能更新**：`tools/update-godotprompter.ps1` 从上游仓库同步技能目录
- **C# 脚本**：DSH 会话内无法编译 C#，新增/修改 C# 后需在 Godot 编辑器内构建
- **不要修改** `addons/` 内第三方插件源码（除非明确要求）；`docs/agent-prompts/` 为上游 GodotPrompter 的 DSH 适配版（MIT）

## 9. i18n / 用户可见文案硬约束（项目级，所有 UI 与提示必须遵守）

1. **禁止硬编码用户可见文本**：GDScript 字符串字面量、`.tscn` 的 `text`/`tooltip`/`placeholder` 不得直接写中文/英文展示文案；一律经 `tr(key)` / `I18NManager.get_text(key, args)` / `UiText.text(key, args)` 取翻译。代码注释、日志、`push_error` 不受此限。
2. **翻译键统一进 `locales/zh.json` 与 `locales/en.json`**：新增键必须双语同键同参；维护脚本为 `tools/update_locales.py`（内容数据键自动从 `resources/` 生成，结构键在脚本中维护）。
3. **内容数据名称/描述**：武器型号、商店商品、技能、配件、设施等 `display_name/description` 是中文回退源；UI 显示必须走 `UiText.content_name(id, fallback)` / `UiText.content_description(id, fallback)`（键规则 `content.<id 斜杠/冒号转下划线>.<name|desc>`），禁止 UI 直接使用资源字段。
4. **语言切换即时生效**：需要常驻/可被设置面板覆盖的面板（主菜单、暂停、结算、HUD、商店、技能三选一等）必须订阅 `EventBus` 的 `LanguageChangedEvent`，在回调里重建全部可见文本；面板关闭/销毁时 `unsubscribe`。
5. **评审与检查**：任何新增/修改 UI 必须人工确认两种语言切换后无残留硬编码；GUT 门禁须包含 i18n 键奇偶校验（见 `tests/unit/test_i18n.gd`）。新增 `.tscn` 文本应保持空串或键名，运行时由脚本填充。
6. **占位符格式**：翻译文本使用 `{0} {1}` 占位符；需要 `%.1f` 等格式时在调用侧先格式化，不要把 printf 格式塞进翻译键。

## Godot Skill Duo 路由（GodotPrompter 主 + GD-Agentic-Skills 辅）

<!-- skill-duo:begin -->
1. **Godot 开发任务先加载 `using-godot-skill-duo`**（已装于 `.dsh/skills/`），它给出双体系路由。
2. **主**：GodotPrompter（`.dsh/skills/`，55 技能）——流程/架构/评审/测试/调试/C#/第三方 addon 优先；加载方式见 §4 工具映射与 §5 路由卡。
3. **辅**：GD-Agentic-Skills（克隆于 `.research/gd-agentic-skills/`，不入库）——生产级 GDScript、27 个类型蓝图、4.7 专属/迁移、数值平衡、Agent Vision；按需读 `skills/<name>/SKILL.md`，**不要整体安装**。
4. **任务索引**：`.dsh/skills/using-godot-skill-duo/duo-skill-index.json`（machine-readable）。
5. **更新**：GD + 路由模板 `pwsh tools/setup-godot-skill-duo.ps1`；GP `pwsh tools/update-godotprompter.ps1`。
6. **冲突去重**：同主题只选一个主（默认 GP）；去重表见 `using-godot-skill-duo` SKILL.md。
<!-- skill-duo:end -->


