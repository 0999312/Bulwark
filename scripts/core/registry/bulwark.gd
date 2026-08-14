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

## 武器种类（WeaponTypeData.id）
const WEAPON_TYPE_ASSAULT_RIFLE := "weapon/type/assault_rifle"
const WEAPON_TYPE_PISTOL := "weapon/type/pistol"

## 武器型号（WeaponModelData.id；虚构命名 P26）
const WEAPON_MODEL_STORM7 := "weapon/model/storm7"    # "风暴-7 突击步枪"
const WEAPON_MODEL_SENTINEL1 := "weapon/model/sentinel1" # "哨兵-1 手枪"

## 敌人（EnemyData.id）
const ENEMY_RUNNER := "enemy/runner"                  # 奔跑者

## 波次（WaveData.id）
const WAVE_1 := "wave/1"
const WAVE_2 := "wave/2"
const WAVE_3 := "wave/3"

## UI（UIRegistry 面板 id）
const UI_HUD := "ui/hud"
const UI_RESULT := "ui/result"
const UI_PAUSE := "ui/pause"

## 构造 bulwark 命名空间下的 ResourceLocation
static func loc(path: String) -> ResourceLocation:
	return ResourceLocation.new(NAMESPACE, path)

## 解析完整位置字符串（如 "bulwark:enemy/runner"）；非法返回 null（调用方应防御）
static func parse(location_str: String) -> ResourceLocation:
	return ResourceLocation.from_string(location_str)
