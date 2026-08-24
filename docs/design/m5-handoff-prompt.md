# 《前线壁垒》M5 交接提示词（Handoff Prompt）

> 状态：**M5 计划 v0.5 已定稿；M5-0（贴图 Nearest 基线）已执行并验证通过。M5a~M5e 待实施。**
> 上游：`m4-handoff-prompt.md` / `m4-design.md` / `game-design-doc.md` / `architecture-design.md`（硬性约束：前后端分离、Registry + ResourceLocation、host 权威、无 PvP、禁队友伤害）。

---

## 一、M5 范围（v0.5 定稿）

1. **内容包 + 最小支撑系统**：敌人 6 威胁模式 + 精英、武器 5 类 × 3 型号、设施 3 种、波次重排 + 精英波、商店 25 注册项。
2. **技能系统最小版**：6 技能、单槽 Q、开局三选一。
3. **UI/UX 全面专修**：设计令牌 + Theme 2.0 + 六面板/HUD 重设计 + 动效 + HUD 全量 i18n + 焦点/多分辨率。

**明确不做**：搜索-战斗循环、章节制、meta 解锁、第二技能槽与图纸、Boss·巢穴母体、5 类以外武器与额外弹道（PARABOLA/BEAM/FLAME/FUEL/GRENADE 仍留位）、公共房间列表、NodeTunnel 上游缺陷修复、昼夜循环（LightingManager 接口保留）。

---

## 二、M5-0 已完成（交接起点，勿重做）

1. **贴图 Nearest 基线**：
   - `project.godot` → `[rendering] textures/canvas_textures/default_texture_filter=0`（Nearest）。
   - 已验证：`--headless --import` exit 0；脚本读取 `ProjectSettings` 值 = 0；`assets/` 下 51 张位图无 mipmap、项目内无显式 `texture_filter` 覆盖 → 全部素材默认 Nearest 生效。
2. **附带修复 `config.cfg` 两处解析错误**（headless 冒烟发现，原为 M4.2 遗留）：
   - `relay_url` 值含 `:` 必须加引号：`relay_url="us-east.nodetunnel.io:8080"`。
   - Godot ConfigFile 注释行含 `=` 会解析失败（实测确认），"0.7 = 默认"已改"0.7 为默认"。
   - 修复后 `--headless --quit-after 3` 启动零错误。
3. **已知非阻塞告警**：`assets/MiSans-Semibold.otf/ttf` 与 `assets/fonts/` 同名文件 UID 重复（import 扫描告警），后续处理，M5 不阻塞。

---

## 三、阶段与验收

| 阶段 | 内容 | 阶段验收 |
|---|---|---|
| **M5a 敌人内容包** | `RunnerController` 泛化为 `EnemyController`（core）按 `ThreatMode` 分派；`EnemyView` 按模式分派表现；host 逻辑命中 + 事件驱动视觉弹体（喷吐者/狙击手/自爆体 AoE/精英弱点）；EnemyData 扩展行为字段；敌人快照/事件中继扩展；7 内容条目（奔跑者变种×3 + 自爆体/喷吐者/装甲兽/飞行体/狙击手怪/精英·巨兽）；波次重排 6 波，W6 = 精英波（1 精英 + 同方位强化小怪 1.5×） | core 单测（FSM/AoE/方向护甲/弱点/波次构成）+ loopback 双端一致 |
| **M5b 武器/设施/商店** | registry id 全部改名现实编号（`ar_1…er_3`，不留旧别名）；每玩家 `arsenal` + 商店武器箱 + 改枪台换型号；轻机枪走 HITSCAN 数值化、能量步枪实现 CHARGE + PIERCE；弹药池泛化 + ENERGY；设施框架 + 自动炮塔（host 索敌/HitscanResolver 结算/事件表现）+ 弹药补给点（能量换弹）+ 最小修复交互；`RunState` 增加 energy；AttributeSet/WeaponStats 属性键扩展（armor/lifesteal/skill_cd/throw_damage/switch_cd/turret_damage/barricade_hp/repair_speed/build_cost/material_yield/credit_yield）；商店 25 注册项 | 单测（型号结算/arsenal/能量/炮塔/修复/价格）+ loopback 商店 per-player 视角不回归 |
| **M5c 技能最小版** | `SkillData` + `SkillExecutor`（core，per-player，host 裁决）；GUIDEAction `skill`（默认 Q，重新生成 contexts）；开局随机 3 个 → 三选一面板；6 技能：手雷/冲刺/护盾发生器/医疗包/空袭呼叫/标记射击（数值草案见计划 v0.5）；技能事件中继 | 单测（冷却/护盾/标记/AoE 友军过滤/空袭延迟）+ 键位可改键测试 |
| **M5d UI/UX 全面专修** | 见 §五 | 截图对照 + 动效/焦点/i18n/三分辨率验收 |
| **M5e 集成打磨** | 难度曲线一张表闭环；新敌人/炮塔/技能 VFX 与 LightingManager 光池接线；音频映射补齐；结算统计（到达波次/击杀/资源/技能）；GUT 全量 + loopback 40s + 单机完整一局 | 总验收（见下） |

**总验收**：GUT 全量绿（含新测试，无既有回退）；loopback 双进程 PASS；单机 6 波 → 精英波 → 胜利结算完整可玩；三分辨率（1280×720 / 1920×1080 / 21:9）UI 不破版；headless 启动零错误。

---

## 四、决策记录（D-M5，执行前请通读）

| # | 决策 | 结论 |
|---|---|---|
| D-M5-1 | 敌人远程攻击同步 | host 逻辑命中 + 事件驱动视觉弹体，不做弹体逐帧快照 |
| D-M5-2 | 波次 | 维持 6 波单链，W6 = 精英波；不做章节 UI |
| D-M5-3 | 武器获取 | 开局默认型号；商店武器箱 → 个人军械库 → 装备界面换型号 |
| D-M5-4 | 能量 | 每玩家新增第 4 资源 energy；波次奖励产出；补给点消耗 |
| D-M5-5 | 设施交互 | F 循环选中设施，E 放置/交互；含最小修复交互 |
| D-M5-6 | 技能 | 开局 3 选 1、单槽 Q；不卖技能；第二槽随搜索系统 |
| D-M5-7 | 商店条目 | 注册 25 项 = 18 强化（GDD P13）+ 4 配件 + 3 消耗物资 |
| D-M5-8 | UI 视觉 | 硬朗军事 × 扁平配色（令牌见 §五）；文案不承载世界观 |
| D-M5-9 | 能量步枪/轻机枪 | 只实现 CHARGE + PIERCE 最小弹道，其余弹道留扩展 |
| D-M5-10 | 武器命名与 id | 现实派制式编号（AR-1/SG-1/HG-1/LMG-1/ER-1 式）；id 直接重命名，不留旧别名 |
| D-M5-11 | 配件语义 | 轻量枪托改为"快换枪托 · 切换 CD-"；移除换弹加速语义 |
| D-M5-12 | UI 文案 | 功能词保留（商店/装备/暂停/设置/结算）；现有 flavor 文案全部删除 |
| D-M5-13 | 波次预告 | 两级显示：预估数量档（少量/中等/大量）+ 精英/常规；无箭头、无精确数、无类型罗列 |
| D-M5-14 | 商店结构 | 每波 4 随机槽 + 2 轮换固定槽（池 = 3 补给 + 4 防线向，种子轮换，不常驻同一批）；Core 列表无序，排序只在 client 呈现层，玩家可选排序方式（默认序/类别/稀有度/价格） |
| D-M5-15 | UI 细节 | 8pt 间距网格（4/8/12/16/24）、统一边距/对齐、视觉 QA 清单；消除魔法像素 offset |
| D-M5-16 | 贴图 | 全部素材 Nearest（已在 M5-0 落地，新素材沿用） |
| D-M5-17 | M5-0 附带修复 | `config.cfg` 引号与注释 `=` 两处解析修复（§二） |

---

## 五、M5d UI/UX 专修要求（v0.5）

### 5.1 设计令牌（默认）
- 背景 `#0B0F0D` / 面板 `#121A16`；边框橄榄黄 `#AD9A40` / 警示琥珀 `#F2A93B`；交互青绿 `#3FBFAD`；危险 `#E05B4C`；稀有度 白 / `#61A0FF` / `#B86BFF` / `#F2B23B`。
- 字体 MiSans-Semibold；字号 13/15/18/22/28/34/58；间距 4/8/12/16/24；圆角 4/8/12。
- Theme 2.0 重写 `assets/theme/minimal_vector.tres`：Button 五态、OptionButton+PopupMenu、LineEdit、HSlider、TabContainer、ProgressBar、ScrollBar、Tooltip 单源覆盖；场景内 ad hoc StyleBoxFlat 只允许引用语义变体。
- 共享 `BaseModalPanel`：全屏压暗 + 卡片 + Esc/返回 + 进出场 tween + 首焦点抓取。

### 5.2 文案纪律
- 功能标题保留；**必删 flavor**：`menu.subtitle`"死守防线"、`pause.subtitle`"喘口气……"、`result.*_subtitle` 全部、GDScript 散落 flavor 字符串。主菜单副标题只留 `FRONTLINE BULWARK`。结算只显示统计。

### 5.3 波次预告
- Core：`WaveComposition.threat_tier()`（少量/中等/大量）+ `has_elite`；网络负载只广播 `threat_tier + has_elite`。
- HUD：常规波 `第 X 波 · 预计少量/中等/大量来袭`；精英波追加醒目"精英单位出现"警报。删除箭头罗盘与逐方向信息。

### 5.4 商店面板
- 4 随机槽 + 2 轮换固定槽；固定槽池成员用 `is_fixed` 标记轮换池语义。
- 客户端排序可切换（默认类别分组 → 稀有度/价格/默认序）；per-player 价格/可负担计算维持 M3 约定。

### 5.5 动效与细节
- 面板进出 ≤250ms，`TRANS_CUBIC + EASE_OUT`；tween 存引用、重入前 kill、暂停用 `TWEEN_PAUSE_PROCESS`；数值条用 `tween_method`；技能冷却用 `GradientTexture2D` FILL_CONIC。
- 视觉 QA 清单：间距节奏、对齐、留白、autowrap/截断、空状态、图标-文字基线。
- HUD 手写 offset 全部改为容器 + margin 实现。

---

## 六、测试与纪律

1. GUT：`$env:APPDATA` 重定向；新增 class_name 后先 `--headless --import` 刷新全局类缓存；测试间自清理 EventBus/面板/输入状态。
2. 双进程冒烟：`tools/run-dual.ps1`（loopback 必跑；relay 需 token）；GUT 与双进程冒烟不可并发；ps1 纯 ASCII。
3. 架构硬约束：逻辑进 `scripts/core/`；内容一律经 Registry + ResourceLocation；UI 只读状态 + 发意图/事件；client 不本地结算伤害/资源。
4. 每个阶段门禁：GUT 绿 + 单机冒烟可玩 + （涉及多人时）loopback PASS 后才进入下一阶段。

---

## 七、发布前 TODO（长期门禁，勿丢）

**发布前执行全量架构检查**：前后端分离硬约束复核（core 零场景/渲染依赖，评审 + 静态扫描）；Registry + ResourceLocation 全量内容注册复核；host 权威边界表逐系统复核（意图 RPC / 快照 / 事件中继）；Mod 分层与多人一致性路径复核（M6 实现后）；UI 数据绑定规范复核；素材与第三方依赖授权复核（含 D-M4-2 `sounds/` 授权确认）；GUT 全量 + loopback/relay 冒烟 + 性能预算回归。

---

## 八、建议执行顺序与技能

- 顺序：**M5a → M5b → M5c → M5d → M5e**（M5-0 已完成；M5d 必须在 M5a-c 功能冻结后启动）。
- 技能：M5a `ai-navigation / ability-system / state-machine / godot-testing`；M5b `resource-pattern / gdscript-patterns / godot-testing`；M5c `ability-system / event-bus / godot-testing`；M5d `ui-ux-pro-max / godot-ui / tween-animation / responsive-ui / hud-system / localization / input-handling`；M5e `godot-optimization / audio-system / godot-code-review`。
