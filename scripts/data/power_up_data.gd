class_name PowerUpData
extends Resource
## 波中道具数据（P1-6）：掉落权重 + 效果 + 时长 + 表现键
## - duration > 0 = 计时 buff（PowerUpSystem 维护，到期回调移除修正）
## - duration == 0 = 即时效果（拾取即结算）
## - 权重用于 WaveDirector/GameSession 掉落 roll（总权重归一化）

enum EffectKind {
	AMMO = 0,        # 弹药箱 +30 子弹
	MATERIAL = 1,    # 建材包 +1 建材
	HEAL = 2,        # 医疗包 +25 HP
	FIRE_RATE = 3,   # 急速射击 fire_rate ×1.5（6s）
	PELLETS = 4,     # 三连弹 pellets +2（6s）
	SHIELD = 5,      # 护盾 armor +0.4（5s，近似吸收）
	SCORE_MULT = 6,  # 分数加速 得分 ×2（10s）
	RESERVE = 7,     # 备用命 reserve +1
}

@export_group("标识")
@export var id: String = ""
## 中文回退显示名（UI 经 UiText.content_name 取键）
@export var display_name: String = ""

@export_group("效果")
@export var effect: EffectKind = EffectKind.AMMO
## 强度值（弹药数/建材数/HP/倍率倍数/护甲加值/备命数；语义随 Kind）
@export var amount: float = 0.0
## buff 时长（秒；0 = 即时）
@export var duration: float = 0.0

@export_group("掉落")
## 掉落权重（相对值；同章掉落表归一化）
@export var weight: float = 1.0

@export_group("表现")
## VfxBank 表现键：props 名（crateMetal/sandbagBeige/oilSpill_*）或炮塔/弹体名；空 = 像素块兜底
@export var vfx_key: String = ""
## 像素兜底/图标主色
@export var icon_color: Color = Color(1.0, 0.86, 0.4, 1.0)
