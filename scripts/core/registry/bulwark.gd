class_name Bulwark
extends RefCounted
## 官方内容标识中心（Mod 前置：官方 = bulwark 命名空间下第一个内容包，架构 §10）
## 业务代码禁止散落硬编码 id 字符串；一律经本类 + ResourceLocation 引用。

const NAMESPACE := "bulwark"

## 注册表名（RegistryManager.register_registry）
const REG_WEAPON_TYPE := "weapon_type"
const REG_WEAPON_MODEL := "weapon_model"
const REG_ENEMY := "enemy"
const REG_WAVE := "wave"
const REG_UI := "ui"
const REG_ATTACHMENT := "attachment"   # M1 配件
const REG_SHOP_ITEM := "shop_item"     # M1 商店商品
const REG_FACILITY := "facility"       # M1 防线设施

## 武器种类（WeaponTypeData.id；D-M5-10 现实派制式编号）
const WEAPON_TYPE_AR := "weapon/type/ar"     # 突击步枪
const WEAPON_TYPE_SG := "weapon/type/sg"     # 霰弹枪（副武器）
const WEAPON_TYPE_HG := "weapon/type/hg"     # 手枪（应急位）
const WEAPON_TYPE_LMG := "weapon/type/lmg"   # 轻机枪
const WEAPON_TYPE_ER := "weapon/type/er"     # 能量步枪

## 武器型号（WeaponModelData.id；D-M5-10 现实派制式编号，无旧别名）
const WEAPON_MODEL_AR_1 := "weapon/model/ar_1"
const WEAPON_MODEL_AR_2 := "weapon/model/ar_2"
const WEAPON_MODEL_AR_3 := "weapon/model/ar_3"
const WEAPON_MODEL_SG_1 := "weapon/model/sg_1"
const WEAPON_MODEL_SG_2 := "weapon/model/sg_2"
const WEAPON_MODEL_SG_3 := "weapon/model/sg_3"
const WEAPON_MODEL_HG_1 := "weapon/model/hg_1"
const WEAPON_MODEL_HG_2 := "weapon/model/hg_2"
const WEAPON_MODEL_HG_3 := "weapon/model/hg_3"
const WEAPON_MODEL_HG_4 := "weapon/model/hg_4"  # 重型手枪（左轮/沙鹰式）功能测试
const WEAPON_MODEL_LMG_1 := "weapon/model/lmg_1"
const WEAPON_MODEL_LMG_2 := "weapon/model/lmg_2"
const WEAPON_MODEL_LMG_3 := "weapon/model/lmg_3"
const WEAPON_MODEL_ER_1 := "weapon/model/er_1"
const WEAPON_MODEL_ER_2 := "weapon/model/er_2"
const WEAPON_MODEL_ER_3 := "weapon/model/er_3"
const WEAPON_TYPE_IDS := [WEAPON_TYPE_AR, WEAPON_TYPE_SG, WEAPON_TYPE_HG, WEAPON_TYPE_LMG, WEAPON_TYPE_ER]
const WEAPON_MODEL_IDS := [
	WEAPON_MODEL_AR_1, WEAPON_MODEL_AR_2, WEAPON_MODEL_AR_3,
	WEAPON_MODEL_SG_1, WEAPON_MODEL_SG_2, WEAPON_MODEL_SG_3,
	WEAPON_MODEL_HG_1, WEAPON_MODEL_HG_2, WEAPON_MODEL_HG_3, WEAPON_MODEL_HG_4,
	WEAPON_MODEL_LMG_1, WEAPON_MODEL_LMG_2, WEAPON_MODEL_LMG_3,
	WEAPON_MODEL_ER_1, WEAPON_MODEL_ER_2, WEAPON_MODEL_ER_3,
]

## 敌人（EnemyData.id）
const ENEMY_RUNNER := "enemy/runner"                  # 奔跑者
const ENEMY_RUNNER_FAST := "enemy/runner_fast"        # 疾行者（奔跑者变种：快而脆）
const ENEMY_RUNNER_TOUGH := "enemy/runner_tough"      # 硬壳者（奔跑者变种：慢而肉）
const ENEMY_SELF_DESTRUCT := "enemy/self_destruct"    # 自爆体
const ENEMY_SPITTER := "enemy/spitter"                # 喷吐者
const ENEMY_ARMORED := "enemy/armored"                # 装甲兽
const ENEMY_FLYING := "enemy/flying"                  # 飞行体
const ENEMY_SNIPER := "enemy/sniper"                  # 狙击手怪
const ENEMY_ELITE_BEHEMOTH := "enemy/elite_behemoth"  # 精英·巨兽

## 波次（WaveData.id）
const WAVE_1 := "wave/1"
const WAVE_2 := "wave/2"
const WAVE_3 := "wave/3"
const WAVE_4 := "wave/4"
const WAVE_5 := "wave/5"
const WAVE_6 := "wave/6"
const WAVE_IDS := [WAVE_1, WAVE_2, WAVE_3, WAVE_4, WAVE_5, WAVE_6]

## 配件（AttachmentData.id）
const ATTACHMENT_RED_DOT := "attachment/red_dot"        # 红点瞄具：散布-（小幅精度，无倍率）
const ATTACHMENT_EXT_MAG := "attachment/ext_mag"        # 扩容弹匣：弹匣+
const ATTACHMENT_COMPENSATOR := "attachment/compensator" # 制退器：后坐-（连射热度减）
const ATTACHMENT_LIGHT_STOCK := "attachment/light_stock" # 轻量枪托：换弹+

## 商店商品（ShopItemData.id）
const SHOP_DAMAGE_UP := "shop/item/damage_up"           # 伤害+（武器向）
const SHOP_FIRE_RATE_UP := "shop/item/fire_rate_up"     # 射速+（武器向）
const SHOP_MAG_UP := "shop/item/mag_up"                 # 弹匣+（武器向）
const SHOP_RELOAD_UP := "shop/item/reload_up"           # 换弹+（武器向）
const SHOP_MAX_HP_UP := "shop/item/max_hp_up"           # 生命上限+（生存向）
const SHOP_MOVE_SPEED_UP := "shop/item/move_speed_up"   # 移速+（生存向）
const SHOP_RED_DOT := "shop/item/red_dot"               # 红点瞄具（配件）
const SHOP_EXT_MAG := "shop/item/ext_mag"               # 扩容弹匣（配件）
const SHOP_COMPENSATOR := "shop/item/compensator"       # 制退器（配件）
const SHOP_LIGHT_STOCK := "shop/item/light_stock"       # 轻量枪托（配件）
const SHOP_BARRICADE := "shop/item/barricade"           # 路障组件（防线向，固定物资）
const SHOP_RESERVE := "shop/item/reserve"               # 应急储备+1（资源向，固定物资）
const SHOP_AMMO_CRATE := "shop/item/ammo_crate"         # 弹药箱（资源向，固定物资；补给经济闭环）
## M5b：补齐 18 强化（GDD P13）到 25 注册项
const SHOP_CRIT_CHANCE_UP := "shop/item/crit_chance_up"     # 暴击率+（武器向）
const SHOP_SWITCH_CD_DOWN := "shop/item/switch_cd_down"     # 切换 CD-（武器向）
const SHOP_ARMOR_UP := "shop/item/armor_up"                 # 护甲+（生存向）
const SHOP_LIFESTEAL_UP := "shop/item/lifesteal_up"         # 吸血+（生存向）
const SHOP_TURRET_DAMAGE_UP := "shop/item/turret_damage_up" # 炮塔伤害+（防线向）
const SHOP_BARRICADE_HP_UP := "shop/item/barricade_hp_up"   # 路障耐久+（防线向）
const SHOP_REPAIR_SPEED_UP := "shop/item/repair_speed_up"   # 修复速度+（防线向）
const SHOP_BUILD_COST_DOWN := "shop/item/build_cost_down"   # 造价-（防线向）
const SHOP_MATERIAL_YIELD_UP := "shop/item/material_yield_up" # 建材产出+（资源向）
const SHOP_CREDIT_YIELD_UP := "shop/item/credit_yield_up"   # 货币利率+（资源向）
## BUG 交接：武器箱商品（购买未拥有型号加入个人军械库；D-M5-3 商店武器箱补完）
const SHOP_WEAPON_CRATE_AR_2 := "shop/item/weapon_crate_ar_2"
const SHOP_WEAPON_CRATE_AR_3 := "shop/item/weapon_crate_ar_3"
const SHOP_WEAPON_CRATE_SG_2 := "shop/item/weapon_crate_sg_2"
const SHOP_WEAPON_CRATE_SG_3 := "shop/item/weapon_crate_sg_3"
const SHOP_WEAPON_CRATE_HG_2 := "shop/item/weapon_crate_hg_2"
const SHOP_WEAPON_CRATE_HG_3 := "shop/item/weapon_crate_hg_3"
const SHOP_WEAPON_CRATE_LMG_1 := "shop/item/weapon_crate_lmg_1"
const SHOP_WEAPON_CRATE_LMG_2 := "shop/item/weapon_crate_lmg_2"
const SHOP_WEAPON_CRATE_LMG_3 := "shop/item/weapon_crate_lmg_3"
const SHOP_WEAPON_CRATE_ER_1 := "shop/item/weapon_crate_er_1"
const SHOP_WEAPON_CRATE_ER_2 := "shop/item/weapon_crate_er_2"
const SHOP_WEAPON_CRATE_ER_3 := "shop/item/weapon_crate_er_3"
const SHOP_WEAPON_CRATE_IDS := [
	SHOP_WEAPON_CRATE_AR_2, SHOP_WEAPON_CRATE_AR_3,
	SHOP_WEAPON_CRATE_SG_2, SHOP_WEAPON_CRATE_SG_3,
	SHOP_WEAPON_CRATE_HG_2, SHOP_WEAPON_CRATE_HG_3,
	SHOP_WEAPON_CRATE_LMG_1, SHOP_WEAPON_CRATE_LMG_2, SHOP_WEAPON_CRATE_LMG_3,
	SHOP_WEAPON_CRATE_ER_1, SHOP_WEAPON_CRATE_ER_2, SHOP_WEAPON_CRATE_ER_3,
]
const SHOP_ITEM_IDS := [
	SHOP_DAMAGE_UP, SHOP_FIRE_RATE_UP, SHOP_MAG_UP, SHOP_RELOAD_UP,
	SHOP_CRIT_CHANCE_UP, SHOP_SWITCH_CD_DOWN,
	SHOP_MAX_HP_UP, SHOP_ARMOR_UP, SHOP_MOVE_SPEED_UP, SHOP_LIFESTEAL_UP,
	SHOP_TURRET_DAMAGE_UP, SHOP_BARRICADE_HP_UP, SHOP_REPAIR_SPEED_UP, SHOP_BUILD_COST_DOWN,
	SHOP_MATERIAL_YIELD_UP, SHOP_CREDIT_YIELD_UP,
	SHOP_RED_DOT, SHOP_EXT_MAG, SHOP_COMPENSATOR, SHOP_LIGHT_STOCK,
	SHOP_BARRICADE, SHOP_RESERVE, SHOP_AMMO_CRATE,
]
const SHOP_ITEM_IDS_INCLUDING_CRATES := [
	SHOP_DAMAGE_UP, SHOP_FIRE_RATE_UP, SHOP_MAG_UP, SHOP_RELOAD_UP,
	SHOP_CRIT_CHANCE_UP, SHOP_SWITCH_CD_DOWN,
	SHOP_MAX_HP_UP, SHOP_ARMOR_UP, SHOP_MOVE_SPEED_UP, SHOP_LIFESTEAL_UP,
	SHOP_TURRET_DAMAGE_UP, SHOP_BARRICADE_HP_UP, SHOP_REPAIR_SPEED_UP, SHOP_BUILD_COST_DOWN,
	SHOP_MATERIAL_YIELD_UP, SHOP_CREDIT_YIELD_UP,
	SHOP_RED_DOT, SHOP_EXT_MAG, SHOP_COMPENSATOR, SHOP_LIGHT_STOCK,
	SHOP_BARRICADE, SHOP_RESERVE, SHOP_AMMO_CRATE,
	SHOP_WEAPON_CRATE_AR_2, SHOP_WEAPON_CRATE_AR_3,
	SHOP_WEAPON_CRATE_SG_2, SHOP_WEAPON_CRATE_SG_3,
	SHOP_WEAPON_CRATE_HG_2, SHOP_WEAPON_CRATE_HG_3,
	SHOP_WEAPON_CRATE_LMG_1, SHOP_WEAPON_CRATE_LMG_2, SHOP_WEAPON_CRATE_LMG_3,
	SHOP_WEAPON_CRATE_ER_1, SHOP_WEAPON_CRATE_ER_2, SHOP_WEAPON_CRATE_ER_3,
]

## 防线设施（DefenseFacilityData.id）
const FACILITY_BARRICADE := "facility/barricade"        # 路障
const FACILITY_TURRET := "facility/turret"              # 自动炮塔

## UI（UIRegistry 面板 id）
const UI_HUD := "ui/hud"
const UI_RESULT := "ui/result"
const UI_PAUSE := "ui/pause"
const UI_SHOP := "ui/shop"
const UI_SETTINGS := "ui/settings"   # M4 战斗内设置面板
const UI_CHAPTER_REWARD := "ui/chapter_reward"  # P2-19 章间三选一

## 构造 bulwark 命名空间下的 ResourceLocation
static func loc(path: String) -> ResourceLocation:
	return ResourceLocation.new(NAMESPACE, path)

## 解析完整位置字符串（如 "bulwark:enemy/runner"）；非法返回 null（调用方应防御）
static func parse(location_str: String) -> ResourceLocation:
	return ResourceLocation.from_string(location_str)
