# 素材来源与授权（assets/CREDITS.md）

## Kenney — Top-down Tanks (Remastered)

- 作者：Kenney（kenney.nl）
- 许可：**CC0（public domain）** —— 可自由商用、修改、再分发，无需署名（本文件为礼貌性致谢与来源记录）
- 来源素材包：Kenney 官网「Top-down Tanks Remastered」本地源包（不入库；运行时零依赖）
- 使用范围：仅复制 `PNG/Default size/`（非 Retina），导入设置 Nearest / 无 mipmap / lossless

### 本仓库 Assets 使用清单

| 目标路径 | 源文件（Default size） | 用途 |
|---|---|---|
| assets/sprites/turret/tankBody_dark.png | tankBody_dark.png | 炮塔底座（深色基础款） |
| assets/sprites/turret/tankBody_green.png | tankBody_green.png | 炮塔底座（绿色变体，预留） |
| assets/sprites/turret/tankBody_sand.png | tankBody_sand.png | 炮塔底座（沙色变体，预留） |
| assets/sprites/turret/tankBody_red.png | tankBody_red.png | 炮塔底座（红色变体，预留） |
| assets/sprites/turret/tankDark_barrel1.png | tankDark_barrel1.png | 炮塔炮管 1 |
| assets/sprites/turret/tankDark_barrel2.png | tankDark_barrel2.png | 炮塔炮管 2（预留） |
| assets/sprites/turret/tankDark_barrel3.png | tankDark_barrel3.png | 炮塔炮管 3（预留） |
| assets/sprites/turret/specialBarrel1.png | specialBarrel1.png | 特种炮管（预留） |
| assets/sprites/turret/tank/tank_dark.png | tank_dark.png | 敌人轮廓/首领载具（预留） |
| assets/sprites/turret/tank/tank_huge.png | tank_huge.png | 精英/Boss 载具（预留） |
| assets/sprites/turret/tank/tank_bigRed.png | tank_bigRed.png | Boss 载具（预留） |
| assets/sprites/turret/tank/tank_blue.png | tank_blue.png | 飞行体轮廓（预留） |
| assets/sprites/turret/tank/tank_green.png | tank_green.png | 装甲/机械轮廓（预留） |
| assets/sprites/turret/tank/tankBody_darkLarge.png | tankBody_darkLarge.png | 大型装甲轮廓（预留） |
| assets/sprites/turret/tank/tankBody_blue.png | tankBody_blue.png | 蓝色装甲轮廓（预留） |
| assets/vfx/kenney/bullets/bulletGreen1.png | bulletGreen1.png | 玩家弹体 |
| assets/vfx/kenney/bullets/bulletGreen2.png | bulletGreen2.png | 玩家弹体变体 |
| assets/vfx/kenney/bullets/bulletRed1.png | bulletRed1.png | 敌方弹体 |
| assets/vfx/kenney/bullets/bulletDark1.png | bulletDark1.png | 敌方重弹体 |
| assets/vfx/kenney/bullets/bulletBlue1.png | bulletBlue1.png | 敌方能量弹体 |
| assets/vfx/kenney/bullets/bulletSand1.png | bulletSand1.png | 沙色弹体变体 |
| assets/vfx/kenney/muzzle/shotLarge.png | shotLarge.png | 炮塔/重武器枪口焰 |
| assets/vfx/kenney/muzzle/shotOrange.png | shotOrange.png | 玩家枪口焰 |
| assets/vfx/kenney/muzzle/shotRed.png | shotRed.png | 敌方/危险枪口焰 |
| assets/vfx/kenney/muzzle/shotThin.png | shotThin.png | 狙击/细弹枪口焰 |
| assets/vfx/kenney/explosion/explosion1.png | explosion1.png | 死亡爆炸帧 1 |
| assets/vfx/kenney/explosion/explosion2.png | explosion2.png | 死亡爆炸帧 2 |
| assets/vfx/kenney/explosion/explosion3.png | explosion3.png | 死亡爆炸帧 3 |
| assets/vfx/kenney/explosion/explosion4.png | explosion4.png | 死亡爆炸帧 4 |
| assets/vfx/kenney/explosion/explosion5.png | explosion5.png | 死亡爆炸帧 5 |
| assets/vfx/kenney/explosion_smoke/explosionSmoke1.png | explosionSmoke1.png | 基地低耐久告警爆烟 |
| assets/vfx/kenney/debris/sandbagBrown.png | sandbagBrown.png | 路障沙袋碎片 |
| assets/vfx/kenney/debris/barricadeWood.png | barricadeWood.png | 路障木片碎片 |
| assets/vfx/kenney/debris/crateWood.png | crateWood.png | 木箱碎片 |
| assets/sprites/props/crateMetal.png | crateMetal.png | 章节装饰/补给箱 |
| assets/sprites/props/sandbagBeige.png | sandbagBeige.png | 章节装饰 |
| assets/sprites/props/oilSpill_small.png | oilSpill_small.png | 章节地面油渍 |
| assets/sprites/props/oilSpill_large.png | oilSpill_large.png | 章节地面油渍 |

> 运行时唯一纹理入口：`scripts/systems/vfx_bank.gd`。外部临时素材引用清零检查：
> 对 `scenes/ scripts/ resources/ assets/` 执行外部临时素材路径 grep，应 0 命中。
