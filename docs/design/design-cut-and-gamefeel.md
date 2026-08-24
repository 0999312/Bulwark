# 删减轮 + 游戏感改造 设计记录

> 日期：本记录随“系统删减与游戏感优化”一轮提交。
> 原则：**不增加操作复杂度**；保留项必须双端可用、数值可控；特效与低分辨率像素画风一致。

## 1. 删减决策

| 系统 | 决策 | 理由 |
|------|------|------|
| 技能系统 | **整体移除**（SkillData/SkillRegistry/SkillExecutor/SkillActivatedEvent/三选一面板/Q 键/HUD 冷却环/技能与投掷伤害商店商品） | 未带来手感提升；多人下仅 host 完整实现，client 无法正常使用 |
| 弹药补给台 | **移除**（场景/数据/放置与交互逻辑） | 与击杀掉弹 + 商店弹药箱重复；能量换弹无实际意义 |
| 能量资源 | **随补给台一并移除**（RunState.energy/事件参数/快照协议/结算显示） | 能量唯一用途即弹药补给台，删后为死资源 |
| 建筑 | **只保留路障 + 自动炮塔** | 路障 = 拖延，炮塔 = 辅助火力，职责清晰 |
| 商店技能向商品 | 技能 CD、投掷伤害商品移除 | 对应系统已不存在 |
| 炮塔伤害强化商品 | **保留，降为 +1，并接通效果** | 原有 +2 实际未接入炮塔结算（空效果）；现改为放置时按放置者 RunState.bonus 快照，基础 6 → 强化后 7 |

## 2. 炮塔温和削弱（已落地数值）

| 字段 | 旧 | 新 | 说明 |
|------|----|----|------|
| turret_damage | 10 | **6** | 单发伤害 -40% |
| turret_fire_rate | 2.0 | **1.5** | 射速 -25% |
| turret_range | 500 | **360** | 更贴近防线而非全图自动输出 |
| 理论 DPS | 20 | **9** | 保留补刀/拖延价值，不再替代玩家火力 |

## 3. 多人双端渲染一致性修复

**问题**：炮塔/弹药补给台只在 host 本地生成，没有任何放置事件发给 client；client 只能看到路障与凭空出现的炮塔射线。

**修复**：

1. 新增 `NetCodec.EVT_TURRET_PLACED`（location + pos）。
2. host `_try_place_turret` 放置成功后发送事件。
3. client `_apply_turret_placed` 用 host 分配的 `location#instance_id` 创建镜像炮塔。
4. 炮塔受损/修复/销毁复用既有 `EVT_BARRICADE_DAMAGED/EVT_BARRICADE_DESTROYED` 通道，
   `TurretView` 按 location 过滤，与 host 同表现。
5. 新增回归测试：镜像炮塔放置/闪白/销毁（`test_m3_mirror_feedback.gd`）。

## 4. 游戏感改造（调用 Skills 设计）

**加载的技能**：GP `particles-vfx`、`tween-animation`；GD-Agentic `godot-particles`、`godot-combat-system`、`godot-genre-shooter`。

**设计结论**：不继续使用 512px 高清软粒子贴图（与 Kenney 像素角色冲突）。改为：

| 问题 | 旧表现 | 新方案 |
|------|--------|--------|
| 敌人弹体 | 高清 circle_03 缩成小圆点，单调 | 运行时 8px 像素方块弹体 + 双层像素短尾；出膛 0.5→1.0 BACK 脉冲；飞行 QUAD/EASE_IN 加速入弯 |
| 弹体抵达 | 直接消失 | 像素爆点 + 像素冲击环 + 短促动态光（host/client 同事件驱动，双端一致） |
| 敌人受击 | 仅闪白 | 闪白 + 1.15 倍缩放重击回弹 + 命中方向 3px 视觉击退（物理位置不动） |
| 敌人死亡 | 高清 spark 粒子 + flare 贴图 | 1.35 倍爆点 → 身体淡出 + 8px 像素方块粒子（颜色随敌人 body_color）+ 像素冲击环 + 动态光 |
| 玩家受击 | 仅闪红 | 闪红 + 方向随机受击震屏 |
| 命中火花/爆炸闪光 | 高清 spark/flare 贴图 | FxBurst 池统一改为运行时 8px 像素纹理；新增通用 `spawn_pixel_burst` 与 `spawn_impact_ring` |

**游戏感时序**（anticipation → impact → aftermath）：

- **anticipation**：弹体出膛缩放脉冲、发光短尾。
- **impact**：命中缩放重击、视觉击退、闪白、受击震屏。
- **aftermath**：像素粒子散落、冲击环扩散、动态光衰减。

**一致性纪律**：所有新增弹体/抵达反馈都由 host 权威事件驱动，host/client 执行同一表现路径；`FxBurst` 像素纹理运行时生成，不新增高清贴图依赖。

## 5. 验证

- GUT 全量：**283/283 通过**（含删减后注册表 35 项、炮塔 +1 接通、镜像炮塔、VFX 游戏感回归）。
- i18n：zh/en **264/264** 键奇偶一致，已同步 `tools/update_locales.py`。
- 输入上下文：移除 Q 技能键后重新生成，combat 动作 12 项。
- headless 场景冒烟：`res://scenes/world/main.tscn` 运行无脚本错误。

## 6. 影响文件摘要

- 删除：`scripts/core/skill/*`、`resources/skills/*`、`skill_select_panel.*`、`ammo_depot.tscn`、`facility_ammo_depot.tres`、`shop_skill_cd_down.tres`、`shop_throw_damage_up.tres`、`test_skill_executor.gd`、`test_m5b_energy_shop.gd`、`input/actions/skill.tres`。
- 修改：`game_session.gd`、`net_codec.gd`、`turret_controller.gd`、`facility_turret.tres`、`shop_turret_damage_up.tres`、`run_state.gd`、`run_state_changed_event.gd`、`attribute_set.gd`、`player_controller.gd`、`enemy_controller.gd`、`hud.gd/tscn`、`result_panel.gd`、`settings_panel.gd`、`generate_guide_context.gd`、`input_settings.gd`、`fx_burst.gd`、`enemy_projectile.gd`、`enemy_view.gd`、`enemy.tscn`、`player_view.gd`、locales 与测试。
- 新增：`scenes/vfx/pixel_ring.gd`、`tests/unit/test_vfx_gamefeel.gd`。

## 7. 弹幕方向修复

**问题**：敌人弹幕视觉恒定向正右移动，与目标点无关。

**根因**：基地位于世界原点 `(0,0)`；`EnemyController._fire_ranged` 曾把 `Vector2.ZERO` 当作“表现层未提供目标”的哨兵值，把真实指向基地的落点替换为 `origin + RIGHT × attack_range`。

**修复**：`ZERO` 不再是哨兵。表现层未提供目标时，才按 `facing_direction` 与 `distance_to_target` 推导落点；正常攻击路径原样传递 `target_position`。新增回归测试 `test_ranged_target_at_world_origin_falls_back_to_facing_not_right`。

## 8. UI 配色 / 美学改造（godot-ui + godot-ui-theming）

**加载技能**：GP `godot-ui`；GD-Agentic `godot-ui-theming`（Shared-Color-Palette / StyleBoxFlat / Theme 级联原则）。

**设计语言**：深海军蓝底 × 钢蓝描边 × 军事琥珀强调 × 语义色（成功/危险/信息），替代原先偏绿的底色与零散硬编码色。

**落地**：

1. 新增 `scripts/systems/ui_palette.gd`（`UiPalette`）作为配色单一事实源；GDScript 动态 UI 统一取色。
2. 重写激活主题 `assets/theme/minimal_vector.tres`：面板/按钮/输入框/滚动条/进度条统一深海军蓝体系，按钮与卡片增加阴影层级、圆角 8–12、focus 用亮琥珀描边。
3. 主菜单/暂停/结算/设置/商店卡片 StyleBox 对齐新主题；主菜单状态文字、商店稀有度色、价格徽章、结算标题改走 `UiPalette`。
4. `RES_CHECK=PASS`：三分辨率 UI 场景实例化无错误。

**后续可做（不增加操作复杂度）**：按钮 hover 的 `offset_transform` 轻微抬升、面板开关的 scale/fade 出入场、Tab 选中态琥珀下划线。
