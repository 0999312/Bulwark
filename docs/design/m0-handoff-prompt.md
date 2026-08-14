# M0 垂直切片开发 · 交接提示词（Handoff Prompt）

> 用法：将本文件全文作为新对话的首条消息（或粘贴给 subagent）。新对话看不到旧对话内容，本提示词已自包含。

---

你是《前线壁垒》（代号 Bulwark）项目的 Godot 开发者。这是一个受 Clash 'N Slash 启发的 Top-down 生存射击游戏：**士兵（表面军人、非正经军事人员）防守前线基地，迎战从各方向来袭的异变体**，包含武器切换（三槽位：主/副/手枪）、波次生存、商店制成长、搜索-战斗循环；单人与多人合作（2~4 人）同时设计；支持 Modding。项目位于 `E:\godot_learning\projects\godot_dsh_test`（Godot 4.7 mono，GDScript 为主）。

你的任务：**完成 M0 垂直切片开发**。这是第一个可玩闭环，同时是**两条架构硬性约束的验收点**（不达标即未完成）。

## 一、必读文件（按顺序）

1. `AGENTS.md`（项目根）——项目指令、插件清单、测试运行方式、工作流
2. `docs/design/game-design-doc.md`——策划案 v1.2。重点：§0.1 决策记录（P1~P31）、§16.3 技能集最终裁剪表、§6 武器、§8 敌人、§9 基地
3. `docs/design/architecture-design.md`——架构 v0.6。重点：§1.3 通信规则（前后端分离硬性）、§4 核心系统设计、§5 Resource 字段草案、§7 测试策略、§10 Modding（理解 Registry 意义）
4. `docs/design/m0-feature-brief.md`——**本任务的功能需求单（以它为准）**

## 二、技能加载（写代码前必须用 skill 工具加载）

- 引导：`using-godot-prompter`（含工具映射）
- 按需：`player-controller`、`input-handling`、`state-machine`、`ai-navigation`、`resource-pattern`、`event-bus`、`godot-testing`、`scene-organization`、`hud-system`、`gdscript-patterns`、`physics-system`、`godot-code-review`（完成后自审）

## 三、架构硬性约束（不可违反）

1. **Registry + ResourceLocation 从 M0 起生效**：所有内容（武器/敌人/波次）必须经 MSF 注册表注册（`RegistryBase` 子类 + `RegistryManager`），标识用 `ResourceLocation(namespace:id)`，官方命名空间 `bulwark`（如 `bulwark:weapon/type/assault_rifle`）。禁止业务代码散落硬编码 id 字符串。
2. **前后端分离**：后端（`scripts/core/`）纯逻辑——**禁止 `get_node` 场景节点、引用 Sprite/Material/动画、读写 UI**；前端（`scenes/`）只读后端状态 + 发意图命令。后端必须能 headless 实例化并被 GUT 测试。
3. **数据驱动**：武器/敌人/波次 = Resource 配置（字段以架构文档 §5 草案为准）。

## 四、已定决策速查（影响 M0 的）

- P2 单多人同时设计：M0 走单机路径，但代码结构按 host 权威模型预留（M0 不实现联机）
- P7 失败条件：基地耐久归零即失败；玩家阵亡消耗"应急储备"复活（M0 只做结构留位，死亡即结算失败）
- P9 鼠标纯自由瞄准（M0 无手柄）
- P11 三槽位武器（主/副/手枪）；P23 切换 CD：主↔副 1.5s、↔手枪 0.3s；P25 手枪无限备弹、低伤害、快速拔枪
- P26 武器虚构命名（如"风暴-7 突击步枪"）
- P30 无 PvP、**禁止队友伤害**：伤害管道第一道闸 = 阵营过滤（玩家→玩家恒 0），M0 即实现
- P31 弱点机制：M0 仅占位（伤害管道留 `weak_point` 标记位），不实现
- P5 敌人 = 异变体；P28/P29 世界观：非严肃荒诞、军人黑色幽默（仅影响文案语气，M0 可不用文案）

## 五、M0 范围（详见 m0-feature-brief.md）

- 玩家移动 + 鼠标自由瞄准射击（突击步枪 1 型号 + 手枪应急位，三槽位框架 + 切换 CD）
- 敌人：奔跑者 1 种（NavigationAgent2D 寻路冲基地、近战啃基地）
- 基地：BaseCore 耐久 + 归零判负
- 波次：WaveDirector 固定 3 波，种子 PCG 生成「方位 + 数量」构成（同种子可复现，GUT 断言），多方位刷怪（N/E/S/W + 斜向预留）
- HUD：生命 / 弹药 / 基地耐久条 / 波次预告（UIManager 数据绑定）
- GUT 测试：伤害管道（含阵营过滤）、波次生成确定性、切换 CD、前后端分离验证
- **明确不做**：商店、搜索循环、技能系统、meta、多人联机、Mod 加载器、第二敌人、防线设施、弱点机制、复活、手柄

## 六、工作流

1. 加载技能 → 2. 通读必读文件 → 3. 按 brief 实现（建议：先骨架/Registry → 后端逻辑 + GUT → 前端表现接线 → HUD → 整体跑通）→ 4. headless 验证 GUT → 5. `godot --path .` 手动/截图验证 → 6. 用 `godot-code-review` 清单自审 → 7. 输出总结

## 七、验收标准（全部满足才算完成）

- [ ] `godot --path .` 可运行：移动/射击/切枪正常，3 波打完有胜利结算，基地耐久归零判负
- [ ] GUT 全部通过（headless：`& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless -s addons/gut/gut_cmdln.gd --path .`）
- [ ] 所有内容经 Registry + ResourceLocation 注册
- [ ] `scripts/core/` 无 `get_node`、无渲染引用（前后端分离）
- [ ] 遵循 `godot-code-review` 清单；不修改 `addons/` 第三方插件源码；纯 GDScript
- [ ] 输出总结：实现内容 + 使用的技能模式 + 遗留事项（对接 M1 的 TODO）

## 八、完成后

报告实现总结与验收结果；下一步 M1（核心循环：三槽武器完整化、商店 MVP、波次方位构成完整化）将由新任务驱动，不在此任务范围内。
