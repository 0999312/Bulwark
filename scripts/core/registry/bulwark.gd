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

## 武器种类（WeaponTypeData.id）
const WEAPON_TYPE_ASSAULT_RIFLE := "weapon/type/assault_rifle"
const WEAPON_TYPE_PISTOL := "weapon/type/pistol"
const WEAPON_TYPE_SHOTGUN := "weapon/type/shotgun"  # M1 副武器（霰弹）

## 武器型号（WeaponModelData.id；虚构命名 P26）
const WEAPON_MODEL_STORM7 := "weapon/model/storm7"    # "风暴-7 突击步枪"
const WEAPON_MODEL_SENTINEL1 := "weapon/model/sentinel1" # "哨兵-1 手枪"
const WEAPON_MODEL_JAWBREAKER := "weapon/model/jawbreaker" # "裂齿霰弹枪"（M1 副武器）

## 敌人（EnemyData.id）
const ENEMY_RUNNER := "enemy/runner"                  # 奔跑者
const ENEMY_RUNNER_FAST := "enemy/runner_fast"        # 疾行者（奔跑者变种：快而脆）
const ENEMY_RUNNER_TOUGH := "enemy/runner_tough"      # 硬壳者（奔跑者变种：慢而肉）

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

## 防线设施（DefenseFacilityData.id）
const FACILITY_BARRICADE := "facility/barricade"        # 路障

## UI（UIRegistry 面板 id）
const UI_HUD := "ui/hud"
const UI_RESULT := "ui/result"
const UI_PAUSE := "ui/pause"
const UI_SHOP := "ui/shop"

## 构造 bulwark 命名空间下的 ResourceLocation
static func loc(path: String) -> ResourceLocation:
	return ResourceLocation.new(NAMESPACE, path)

## 解析完整位置字符串（如 "bulwark:enemy/runner"）；非法返回 null（调用方应防御）
static func parse(location_str: String) -> ResourceLocation:
	return ResourceLocation.from_string(location_str)
