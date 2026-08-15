# M2 多人架构验证 · 交接提示词（Handoff Prompt 草稿）

> 状态：**M1 已于 2026-08 完成并验收（GUT 160/160）**。本文件为 M2 交接草稿，由 M1 收官时生成。
> M2 正式开发时：将本文件全文作为新对话首条消息，并补充开发者新增意向。
> **M2 实施中**：设计见 `m2-design.md`（权威边界/快照协议/意图清单/决策记录）；实施期间更新以 `m2-design.md` 为准。
> **M2 已验收（2026-08：GUT 185/185 + 双进程冒烟 PASS + 局域网实测）**。实测暴露的多人设计问题已转入**插队 M3**，交接见 `m3-handoff-prompt.md`（5 项：相机归属/暂停协议/client 性能/独立资源/P2P 接入）。

---

## 一、M1 已交付状态（验收基准）

- **可玩闭环扩展**：6 波（wave_1~6，多敌人组：奔跑者 + 疾行者 + 硬壳者变种）、三槽武器完整（主风暴-7 步枪 / 副裂齿霰弹枪 / 哨兵-1 手枪）、波间基地商店（4 随机 + 固定区：路障组件/应急储备）、路障防线（E 键放置）、复活系统（应急储备自动复活 + 4s CD）、改枪配件（4 槽位 4 配件 + 局内装配 UI）、鸭科夫式 2D 手感
- **经济**：击杀奖励货币（EnemyData.kill_reward）+ 概率建材；商店价格 `base×rarity×1.3^n` 递增
- **测试**：GUT 160/160（M0 基线 103 无回归 + M1 新增 57）
- **架构**：3 个新注册表（attachment/shop_item/facility）、8 个新事件、5 个新后端模块（RunState/ShopSystem/ReviveSystem/BarricadeController/WeaponStats）、全部 Registry + ResourceLocation 注册

## 二、M1 关键设计（M2 必须延续）

1. **前后端分离**：scripts/core/ 纯逻辑（无 get_node/渲染）；表现层只读状态 + 发意图（购买/装配/放置均为后端 API 调用）
2. **WeaponStats 结算管道**：武器数值 = 模型 × 配件 × 全局强化（RunState.bonus），开火/命中/换弹全部走结算值；新增武器/配件/强化只改数据
3. **商店效果路由**：ShopSystem.try_purchase(location, effect_handler) —— 效果落点由装配层（GameSession._shop_effect_handler）统一裁决（STAT_PLAYER→玩家 AttributeSet、STAT_WEAPON→RunState.bonus、ATTACHMENT→背包、BARRICADE/RESERVE→资源）
4. **波间商店流程**：WaveDirector.intermission_waits_for_shop → WaveClearedEvent → 暂停树 + ShopPanel → on_shop_closed() → resume_from_intermission()
5. **复活流程**：PlayerDiedEvent → ReviveSystem（储备判定 + CD）→ RevivedEvent → PlayerController.revive() + 位置重置
6. **路障路由**：EnemyAttackEvent.target（"" = 基地，否则路障唯一标识 location#id）→ GameSession 路由结算
7. **GUIDE 输入**：combat_context 由 tools/generate_guide_context.gd 生成（含 interact E 键）；**Y 轴键需 swizzle、X 轴键只 scale**（M0 关键修复，勿回退）

## 三、M2 范围（以里程碑表为准：多人架构验证）

- **目标**：MultiplayerAPI 权威模型验证——本机双客户端共同防守同一基地
- 单机 = 本机 host + 本机客户端同构（架构 §13.2：host 权威、意图 RPC、状态快照）
- 验收：2 客户端同局稳定（验证"单多人同时设计"路线）

## 四、M1 已知问题与调参空间（M2/M3 处理）

1. **单局时长**：粗估 10~12 分钟（目标 15）——调参空间：wave spawn_interval/数量、波间商店决策时间、复活循环
2. **手感参数**：RECOIL_PER_SHOT 0.6°/HEAT 上限 4°/移动散布 ×1.5 等为草案起点，需实机试玩微调（player_view.gd 顶部常量区）
3. **路障寻路**：敌人被路障物理阻挡后原地攻击（预期行为）；但 NavigationAgent 不会绕行路障——若做多路障布防阵型，需导航多边形动态烘焙（M3+ 防线系统）
4. **EnemyView 每帧 barricade_query**：路障数量少可接受；M3 设施增多时加查询节流
5. **配件词条**：keywords 仅数据承载（合并查询），穿甲/燃烧等词条效果结算为 M2+ 伤害管道扩展
6. **商店商品池**：12 项（武器向 6/生存向 2/配件 4/固定 2），未达 P13 的 18 项——M4 补齐随机池权重与稀有度曲线
7. **复活期间**：玩家倒地位置可能被敌人"守尸"（复活后瞬间再被撞）——**M2 已修复：复活附加 2s 无敌帧**（PlayerController.INVINCIBLE_DURATION，测试 test_revive_invincibility）
8. **deps**：~~dialogue_manager 插件的 class_name 冲突报错~~——该插件已于 M2 前置处理中**整体移除**（项目无对话需求；其两套残留副本曾长期干扰导入），相关报错不再存在
9. **路障设计 backlog（M2 仅记录，不实现）**：弧形路障（R=玩家距离/弧长 60°/自动朝向基地）已在 M2 前置落地；**仍存在设计问题待 M3+**——敌人 NavigationAgent 不绕行（原地啃，M3 导航动态烘焙）、单段弧长 ≤60° 覆盖局限、耐久/成本上限与"路障耐久+"成长线未定，以及开发者补充的其他具体问题。登记处：`m2-design.md` §12 + `design-review-m2-pre.md` §4

## 五、架构硬性约束（M2 同样不可违反）

1. Registry + ResourceLocation（bulwark: 命名空间）；禁止散落硬编码 id
2. 前后端分离：scripts/core/ 无 get_node/渲染引用；表现层只读状态 + 发意图
3. 数据驱动：武器/敌人/波次/配件/商品/设施 = Resource
4. 不修改 addons/ 第三方插件源码
5. 破坏性更改：项目未发布，允许重构，但需同步更新测试与文档

## 六、运行与测试（环境坑）

```powershell
# GUT 测试（必须重定向 APPDATA，否则沙箱下引擎写 user:// 崩溃）
$env:APPDATA = "E:\godot_learning\projects\godot_dsh_test\.appdata"
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless -s addons/gut/gut_cmdln.gd --path .
Remove-Item "...\.appdata" -Recurse -Force

# 新增 class_name 后需 --headless --import 刷新全局类缓存
# GUT 测试间 EventBus 订阅累积：before_each 需 EventBus.clear_all_listeners()
# GUIDE 键盘事件用 physical_keycode；注入输入用 Input.parse_input_event
```
