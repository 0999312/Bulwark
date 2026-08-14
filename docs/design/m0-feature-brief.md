# M0 垂直切片 · 功能需求单（《前线壁垒》Bulwark）

> 状态：**已完成（2025，GUT 73/73 + headless 全链路冒烟通过）** · 关联文档：`game-design-doc.md`（策划案 v1.2）、`architecture-design.md`（架构 v0.6）
> 验收流程见文末；开发过程遵循 AGENTS.md §6（策划 → 开发 → 评审）。

## M0 完成记录（交接 M1 用）

- 交付：`scenes/world/main.tscn` 主场景 + `scripts/core/`（38 文件后端纯逻辑）+ `resources/`（9 份内容 .tres）+ `input/`（9 动作 + 2 上下文）+ `tests/unit/`（12 文件 73 用例）
- 验收：`godot --headless -s addons/gut/gut_cmdln.gd --path .` → 73/73 通过、退出码 0；headless 冒烟双向验证（3 波击杀 → 胜利结算；基地耐久归零 → 判负结算）零错误
- 架构硬性约束验收：内容全部经 Registry + `bulwark:` ResourceLocation 注册（`Bulwark` 中心标识类）；`scripts/core/` 无 get_node/渲染引用（`test_separation.gd` 静态检查 + 无场景实例化）
- 已知遗留（对接 M1）：副槽位实装（霰弹枪）、手动换弹键位（M0 自动换弹）、斜向刷怪点 D1/D3/D5/D7、切换 CD 手感实机调参、玩家受击来源（M0 无敌方攻击玩家）、复活/失败判定结构（RunDefeatEvent.Reason.PLAYER_DEAD 已留位）

## 背景

《前线壁垒》是一款受 Clash 'N Slash 启发的 Top-down 生存射击游戏：士兵（表面军人、非正经军事人员）防守前线基地，迎战从各方向来袭的异变体。已完成策划（五批决策 P1~P31）与架构设计。M0 为第一个可玩闭环（垂直切片），同时是**架构硬性约束的验收点**。

## M0 目标

> 可玩 5 分钟的闭环：玩家移动 + 自由射击 → 奔跑者从多方位刷出冲向基地 → 玩家击杀 / 基地耐久被啃 → 3 波 → 失败（基地耐久归零）或胜利结算。

**同时完成两项架构验收**（不达标即 M0 未完成）：
1. **Registry + ResourceLocation 硬性约束**：所有内容（武器/敌人/波次）必须经 Registry 注册、`bulwark:` 命名空间标识——官方内容与未来 Mod 同构的第一天落实。
2. **前后端分离硬性约束**：后端（`scripts/core/`）纯逻辑、无场景节点/渲染引用、headless 可测；前端（`scenes/`）只读状态 + 发意图。

## 需求

### 1. 架构骨架（scripts/framework/ + resources/）

- `ResourceLocation` / `RegistryBase` 子类：`WeaponTypeRegistry`、`WeaponModelRegistry`、`EnemyRegistry`、`WaveRegistry`（继承 MSF `RegistryBase`，覆写 `_validate_entry` 做类型校验），经 `RegistryManager`（MSF 插件）注册，命名空间统一 `bulwark`
- `scripts/framework/`：对象池（弹道用）、种子随机 `SeededRNG`（波次生成确定性）
- 目录：`resources/weapons/type/`、`resources/weapons/model/`、`resources/enemies/`、`resources/waves/`
- 数据类 Resource 字段以架构文档 §5 草案为准（WeaponTypeData / WeaponModelData / EnemyData / WaveData）

### 2. 输入（guide 插件）

- GUIDE Action（放 `input/actions/`）：`move`、`aim`、`shoot`、`switch_weapon`、`pause`
- 键鼠映射：WASD 移动、鼠标瞄准、左键射击、数字键 1/2 切换（主/手枪）、Esc 暂停
- 用 `tools/generate_guide_context.gd` 生成上下文（headless 运行）

### 3. 玩家（scenes/player/ + scripts/core/player/）

- **后端** `PlayerController`（纯逻辑）：状态机 `Idle / Move / Shoot / Reload / Dead`（M0 子集，结构为 FSM 扩展预留）；属性（生命/移速/换弹等，AttributeSet 雏形：base + 修正）
- **前端** `player.tscn`：CharacterBody2D + 占位图形（ColorRect/Sprite2D 即可）+ 视图绑定（读后端状态驱动）
- 鼠标**纯自由瞄准**（已定 P9，M0 无手柄）；射击意图 → 后端验证（弹药/冷却）→ 生成弹道
- 死亡：生命归零 → `Dead` 状态（复活系统 M0 不做，死亡即本局结算失败提示，但复活/失败判定结构留位——失败主判定以基地耐久为准，已定 P7）

### 4. 武器（三槽位结构 + 2 把枪）

- **WeaponSlots 三槽位框架**（主/副/手枪）：M0 实装 主（突击步枪类 1 型号）+ 手枪（应急位）
- **切换 CD 已定数值**（P23）：主↔副 1.5s、↔手枪 0.3s；切换状态机（含 CD 计时）
- **手枪**：无限备弹、低伤害（已定 P25）
- 弹道：突击步枪 HITSCAN（简化，后续可换 PROJECTILE）；弹道经对象池 + 命中 → 伤害管道
- 弹药：按类型计数（M0 只需子弹 + 手枪无限）
- 命名：虚构命名（P26），如"风暴-7 突击步枪"

### 5. 敌人（1 种）

- **奔跑者**（冲锋近战）：`EnemyData` 注册（`bulwark:enemy/runner`）；NavigationAgent2D 寻路冲向基地；近战啃基地耐久；行为 FSM 雏形（Chase / Attack / Dead）
- 数据驱动参数：血量/移速/伤害/攻击间隔

### 6. 基地（scenes/base/ + scripts/core/base/）

- **BaseCore**（后端）：耐久、扣减、归零 → 失败事件
- **前端**：基地视觉（占位图形）+ 耐久条（HUD 绑定）

### 7. 波次（WaveDirector）

- 后端 `WaveDirector`：固定 3 波模板（`WaveData` 注册）；每波 = 种子 PCG 生成「方位 + 数量」构成（同种子可复现，GUT 断言）；多方位刷怪点（N/E/S/W 基础 4 向 + 斜向预留）
- 波次流程：预警 → 刷怪 → 清场 → 下一波 → 3 波后胜利结算
- 强度：不缩放（单人多同时设计，人数系数留位，M0 固定 1）

### 8. HUD（UIManager）

- 生命 / 当前武器弹药 / 切换提示 / **基地耐久条** / 波次预告（方位）
- 数据绑定：后端状态 → UIManager 面板（前端不直接读写后端数值）

### 9. 测试（GUT，headless）

- `tests/unit/`：伤害管道（攻击加成/暴击/减免 + **阵营过滤**：玩家→玩家为 0，已定 P30）、波次生成种子确定性、切换 CD 状态机、弹药扣减/无限备弹
- **前后端分离验证**：后端模块在无场景环境实例化通过（不依赖 get_node/渲染）
- 运行：`godot --headless -s addons/gut/gut_cmdln.gd --path .`

## 明确不做（M0 范围外，结构预留即可）

商店/经济、搜索循环、战术技能系统、meta、多人联机、Mod 加载器、第二敌人、防线设施（路障/炮塔）、弱点机制（P31 仅占位）、复活（失败判定结构留位）、手柄输入。

## 验收标准

- [ ] `godot --path .` 可运行：移动/射击/切枪手感正常，3 波打完有结算，基地耐久归零判负
- [ ] GUT 全部通过（headless）
- [ ] 所有内容经 Registry + `ResourceLocation` 注册（抽查：无硬编码 id 字符串散落业务代码）
- [ ] 后端无场景节点/渲染引用（评审通过）；`scripts/core/` 无 `get_node`、无 Sprite/Material 引用
- [ ] 代码遵循 `godot-code-review` 清单（信号优先、类型标注、Godot 4.3+ API、无废弃方法）
- [ ] 场景树与脚本组织符合 `scene-organization` 技能模式
- [ ] 不修改 `addons/` 第三方插件源码；GDScript 实现

## 约束

- GDScript（不引入 C#）；占位图形用 ColorRect / 现有 assets/
- 输出总结：实现内容 + 使用的技能模式 + 遗留事项（对接 M1 的 TODO）
