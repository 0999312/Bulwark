# BUG 交接记录（临时阶段）

> 状态：本轮 BUG 交接已处理待办并验证（GUT 272/272 全绿 + loopback 冒烟 PASS）；供正式修复阶段参考。

## 1. 商店购买界面滚动条 / 商店主动贩卖武器

- **现象**：
  - 商店购买界面仍感觉没有可拖动的滚动条。
  - 商店没有主动贩卖新武器（玩家看不到武器箱/新型号购买入口）。
- **已处理**：
  - 滚动容器改为 `vertical_scroll_mode = 2`（SHOW_ALWAYS 常显可拖动）；军需站面板 `Panel` 限定在视口边距内，右栏（改枪台型号/配件/背包）整体包入 `RightScroll`，商品列表保留 `OffersScroll`——大量武器可选时不再把面板撑出屏幕。
  - 新增 12 项“武器箱”商品（`shop/item/weapon_crate_*`，覆盖 AR/SG/HG/LMG/ER 未拥有型号），经 `Bulwark.SHOP_ITEM_IDS_INCLUDING_CRATES` + `ContentBootstrap` 注册，商店随机区正常上架展示。
  - `ShopSystem` 支持按每玩家军械库过滤：`setup(..., owned_models)` 后，已拥有型号的武器箱不再上架；购买成功后立即下架，后续刷新也不会重复出现。
  - 改枪台换型号打通跨类型：`WeaponSlots.set_model` 在传入 `WeaponTypeData` 时按槽位类别校验（主槽 AR↔LMG↔ER、副槽 SG、手枪槽 HG），商店面板与多人 `equip_model` 意图均已接线。
- **仍待办**：
  - 正式素材阶段可将武器箱占位图标/插画补入 `temp_assets/`。

## 2. 鼠标准星设置

- **现象**：
  - 默认射击准星不是理想样式。
  - 进度准星只显示“完成准星”，没有阶段变化。
- **已处理**：
  - 默认战斗准星改为 `target_a.png`（`target_round_b` 可留给后续狙击枪）。
  - `CursorStateMachine` 修复：进度状态下按**已完成比例**刷新 `empty/25/50/75/full` 帧（0% 空圈 → 100% 满圈），不再出现“从有到无”的倒放观感；新增 GUT 回归测试。
- **仍待办**：
  - 狙击枪实装时再接入 `target_round_b` 或独立狙击准星。

## 3. 炮塔与炮弹素材缺失 / 炮塔射线表现

- **现象**：
  - 炮塔和炮弹目前没有正式素材。
  - 希望炮塔采用类似玩家的射线射击，视觉上使用显眼的粗射线。
- **已处理**：
  - 新素材统一放入 `temp_assets/turret/`：`turret_base.svg`（底座）、`turret_barrel.svg`（可旋转炮管）、`turret_flash.svg`（枪口/命中闪光）；`turret.tscn` 已接入。
  - 炮塔弹道改为 host 射线结算：`TurretController` 用 `HitscanResolver` 计算圆面进入点，`TurretFiredEvent.target_position` 携带命中点（非圆心）。
  - client 粗射线表现：新增 `scenes/vfx/turret_tracer.gd/tscn`，三层 Line2D（宽 18/9/4，青白高亮）+ 两端闪光，0.12s 淡出；host/client 经 `EVT_TURRET_FIRED` 中继表现一致。
  - 新增 `TurretView`：炮管朝命中点转向 + 微后座表现。
- **仍待办**：
  - 正式素材定稿后可替换 `temp_assets/turret/` 占位图（当前为程序内 SVG 占位）。

## 4. 上一局炮塔残留到下一局

- **现象**：
  - 上一轮放置的炮塔会出现在下一局，碰撞未清理。
- **根因**：
  - 设施视图此前添加到 `get_parent()`（场景根），场景重载时不会被 GameSession 自动释放。
- **已处理**：
  - 路障、自动炮塔、弹药补给点视图改为 `add_child(view)`，作为 GameSession 子节点，场景重载时随本局释放。

## 5. 切换语言后残留硬编码文本（项目级约束）

- **现象**：
  - HUD/军需站/技能三选一等面板仍有大量硬编码中文，切换语言后不翻译。
- **已处理**：
  - 新增 `scripts/systems/ui_text.gd`（`UiText`）作为统一文案入口；内容类名称/描述经 `UiText.content_name/content_description` 按 `content.*` 键取翻译，缺失回退资源中文。
  - `locales/zh.json` / `locales/en.json` 补齐 HUD、商店、技能三选一、结算统计、设施/武器/商品/技能/配件、网络错误等 286 键，双语键数一致；维护脚本 `tools/update_locales.py` 自动从资源生成内容键。
  - HUD/主菜单/暂停/结算/商店/技能三选一订阅 `LanguageChangedEvent`，语言切换即时重建可见文本；`scenes/ui/*.tscn` 用户可见文本清空，运行时由脚本填充。
  - `net_failed` 等用户可见错误改为翻译键输出。
  - **约束已写入 `AGENTS.md` §9（i18n 硬约束）**：禁止硬编码用户可见文本、双语同键、内容名走 UiText、语言切换订阅重建、GUT 键奇偶校验。
- **仍待办**：
  - 编辑器/插件侧（GUIDE 编辑器标签、构建日志）的非游戏内文案暂不在本项目 i18n 范围内。

---

## 验证记录（本轮 BUG 交接）

- GUT 全量：**272/272 通过**（商店武器箱/换型号、炮塔命中点、准星进度方向、军需站布局滚动条、i18n 键奇偶与 UI 场景硬编码扫描等回归）。
- loopback 双进程冒烟：`tools/run-dual-test.ps1` **PASS**（host=ok client=ok，40s；zh/en 各 286 键加载正常）。
