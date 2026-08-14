# M1 核心循环开发 · 交接提示词（Handoff Prompt）

> 用法：将本文件全文作为新对话的首条消息（或粘贴给 subagent）。新对话看不到旧对话内容，本提示词已自包含。
> 状态：M0 已于 2026-08 正式验收完成（103/103 GUT 测试通过）。本文件由 M0 收官时生成。

---

你是《前线壁垒》（代号 Bulwark）项目的 Godot 开发者。这是一个受 Clash 'N Slash 启发的 Top-down 生存射击游戏：**士兵防守前线基地，迎战从各方向来袭的异变体**，三槽位武器（主/副/手枪）、波次生存、商店制成长、搜索-战斗循环；单人与多人合作（2~4 人）同时设计；支持 Modding。项目位于 `E:\godot_learning\projects\godot_dsh_test`（Godot 4.7 mono，GDScript 为主）。

你的任务：**完成 M1 核心循环开发**。M0 可玩闭环已交付，M1 在此基础上扩展。

## 一、必读文件（按顺序）

1. `AGENTS.md`（项目根）——项目指令、插件清单、测试运行方式、工作流
2. `docs/design/game-design-doc.md`——策划案 v1.2。重点：§0.1 决策记录（P1~P31）、§16 波次设计、§6 武器、§8 敌人、§9 基地、§17 里程碑表
3. `docs/design/architecture-design.md`——架构 v0.6。重点：§1.3 通信规则（前后端分离硬性）、§4 核心系统、§5 Resource 字段草案、§7 测试策略、§10 Modding
4. `docs/design/gunplay-attachment-notes.md`——**枪械手感与配件系统备忘（开发者意向，M1 实现前必读）**
5. 代码现状：`scripts/`（后端）+ `scenes/`（前端）+ `tests/`（GUT，103 测试基线）

## 二、M0 已交付状态（验收基准）

- **可玩闭环**：WASD 移动（GUIDE 输入）+ 鼠标自由瞄准 + 左键射击（散布/连射热度/枪口后坐/相机震动）+ R 主动换弹 + 1/3 切枪（0.3s CD）+ Esc 暂停（逻辑真暂停）+ 失败/胜利结算 + 再来一局
- **波次**：WaveDirector 固定 3 波，流式刷怪（短间隔 + 随机方位 + 偶发怪群 burst），**圆环随机刷怪点**（方位 ±30°、半径 720±25%），HUD 预告只报方位不报数量；8 方位（含斜角）
- **敌人**：奔跑者 12 HP（步枪一发/手枪两发），撞击玩家 = 玩家掉血 + 敌人自爆；玩家死亡即失败结算
- **测试**：GUT 103/103（单测 90+ 集成 13）；后端 `scripts/core/` 纯逻辑 headless 可测
- **主题**：暗色军事科幻风（`assets/theme/minimal_vector.tres`）
- **关键修复（M1 勿回退）**：EventBus 失效监听器清理（`Callable.is_valid()`）；GUIDE W/S 移动需 swizzle 修饰器；暂停时 Player/Enemies/HUD 必须保持 PAUSABLE（GameSession 是 ALWAYS 会传染）；结果面板重启需先取 tree 引用再 close_panel

## 三、M0 已知问题（开发者人工试玩反馈，M1 优先处理）

1. **手感还不够好**：散布/后坐/震动数值需按体感调参（参数集中在 `scenes/player/player_view.gd` 顶部常量区 + `model_*.tres` 的 spread）
2. **敌人没有"小怪感"**：视觉表现（体积/材质/死亡反馈）不足以传达"杂兵被轻松扫灭"的感觉——M1 需做敌人视觉与死亡特效强化
3. 其余小问题由开发者在新对话中补充

## 四、M1 范围（以里程碑表为准 + 开发者意向补充）

里程碑表（game-design-doc §17）：**武器三槽位+切换 CD、波次系统（方位+构成）、基地/路障、基地商店**；验收：单局 15 分钟可玩。

开发者已表达的 M1 意向（详见 gunplay-attachment-notes.md）：
- **改枪机制**：局外/局内武器配件修改（槽位 + 修正 + 词条），接入点 = WeaponModelData（keywords 词条）+ AttributeSet（add/mul 修正通道）
- **射击手感深化**：学习《逃离鸭科夫》（俯视角搜打撤）：可感知后坐力、散布 bloom；2D 适配方案见备忘文档 §3
- **狙击镜注意**：本游戏交战距离以近距离为主（200–500px），高倍镜是负资产，狙击定位为可选"远距点名"配件
- **波间商店**（M1 范围）：基地商店 = 波间资源消费节点
- **副武器实装**：三槽位完整化（M1 实装霰弹枪，副槽结构已就位）
- **复活系统**：玩家死亡目前直接失败；M1 按 P7 接入"应急储备"复活（结构留位在 PlayerController / RunDefeatEvent.PLAYER_DEAD）

## 五、架构硬性约束（M1 同样不可违反）

1. **Registry + ResourceLocation**：内容一律注册表注册，`bulwark:` 命名空间；禁止散落硬编码 id
2. **前后端分离**：`scripts/core/` 纯逻辑（无 get_node、无渲染/UI 引用）；`scenes/` 表现层只读状态 + 发意图
3. **数据驱动**：武器/敌人/波次 = Resource 配置
4. **不修改 `addons/` 第三方插件源码**（EventBus 的修复是已批准的例外，勿再动）
5. 破坏性更改：项目未发布，允许重构，但需同步更新测试与文档

## 六、运行与测试（注意环境坑）

```powershell
# GUT 测试（必须重定向 APPDATA，否则沙箱下引擎写 user:// 崩溃）
$env:APPDATA = "E:\godot_learning\projects\godot_dsh_test\.appdata"
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless -s addons/gut/gut_cmdln.gd --path .
Remove-Item "...\.appdata" -Recurse -Force  # 测试后清理

# 运行游戏
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .
```

- 新增 class_name 的脚本后需 `--headless --import` 刷新全局类缓存，否则 GUT 报 "Identifier not declared"
- GUT 测试间 EventBus 订阅会累积：测试 before_each 需 `EventBus.clear_all_listeners()`
- 树暂停时 GUT 用 `wait_process_frames`/`wait_physics_frames`（基于帧信号），不要用 `wait_seconds`（SceneTreeTimer 会冻结）
- GUIDE 键盘事件用 `physical_keycode`；注入输入用 `Input.parse_input_event` 走真实链路

## 七、技能加载（写代码前必须用 skill 工具加载）

- 引导：`using-godot-prompter`
- M1 相关：`inventory-system`（商店）、`ability-system`（配件/词条）、`ai-navigation`、`resource-pattern`、`godot-testing`、`state-machine`、`godot-code-review`（完成后自审）

## 八、工作流

1. 加载技能 → 2. 通读必读文件 → 3. 先处理"已知问题"（手感调参 + 小怪感）→ 4. 按 M1 范围排期实现 → 5. GUT 全绿 → 6. `godot-code-review` 自审 → 7. 输出总结与遗留事项

## 九、验收标准

- [ ] GUT 全部通过（103 基线 + 新增）
- [ ] 单局 15 分钟可玩：三槽武器完整（含副武器）+ 波间商店 + 波次方位/构成符合设计
- [ ] `scripts/core/` 仍无 get_node / 渲染引用
- [ ] 内容全经 Registry 注册；不修改 addons 第三方插件
- [ ] 输出总结：实现内容 + 遗留事项（对接 M2 的 TODO）
