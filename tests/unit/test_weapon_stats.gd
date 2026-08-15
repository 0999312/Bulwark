extends GutTest
## 武器数值结算（WeaponStats）：模型 × 配件 × 全局强化

var model: WeaponModelData

func before_each() -> void:
	model = WeaponModelData.new()
	model.id = "weapon/model/test"
	model.damage = 10.0
	model.fire_rate = 8.0
	model.mag_size = 30
	model.reload_time = 1.2
	model.spread = 2.0
	model.crit_chance = 0.1
	model.range = 900.0
	model.pellets = 1

func _make_modifier(attr: StringName, amount: float, multiplier: float = 1.0) -> AttributeModifierData:
	var mod := AttributeModifierData.new()
	mod.attribute = attr
	mod.amount = amount
	mod.multiplier = multiplier
	return mod

func _make_attachment(slot: int, modifiers: Array) -> AttachmentData:
	var att := AttachmentData.new()
	att.id = "attachment/test"
	att.slot = slot
	att.modifiers.assign(modifiers)
	return att

func test_base_stats_equal_model() -> void:
	var stats := WeaponStats.compute(model, [], null)
	assert_almost_eq(stats.damage, 10.0, 0.001)
	assert_almost_eq(stats.fire_rate, 8.0, 0.001)
	assert_eq(stats.mag_size, 30)
	assert_almost_eq(stats.reload_time, 1.2, 0.001)
	assert_almost_eq(stats.spread, 2.0, 0.001)
	assert_eq(stats.pellets, 1)
	assert_eq(stats.keywords, [])

func test_attachment_additive_modifier() -> void:
	var att := _make_attachment(AttachmentData.AttachmentSlot.MUZZLE,
		[_make_modifier(&"damage", 3.0)])
	var stats := WeaponStats.compute(model, [att], null)
	assert_almost_eq(stats.damage, 13.0, 0.001, "加法通道累加")

func test_attachment_multiplicative_modifier() -> void:
	var att := _make_attachment(AttachmentData.AttachmentSlot.MAG,
		[_make_modifier(&"mag_size", 0.0, 1.5)])
	var stats := WeaponStats.compute(model, [att], null)
	assert_eq(stats.mag_size, 45, "乘法通道累乘（30 × 1.5）")

func test_multiple_attachments_stack() -> void:
	var att1 := _make_attachment(AttachmentData.AttachmentSlot.MUZZLE,
		[_make_modifier(&"damage", 2.0)])
	var att2 := _make_attachment(AttachmentData.AttachmentSlot.SIGHT,
		[_make_modifier(&"damage", 1.0)])
	var stats := WeaponStats.compute(model, [att1, att2], null)
	assert_almost_eq(stats.damage, 13.0, 0.001, "多配件加法叠加")

func test_global_bonus_applies() -> void:
	var run_state := RunState.new()
	var mod := _make_modifier(&"damage", 2.0)
	run_state.apply_bonus_modifier(mod)
	var mod_mul := _make_modifier(&"fire_rate", 0.0, 1.08)
	run_state.apply_bonus_modifier(mod_mul)
	var stats := WeaponStats.compute(model, [], run_state.bonus)
	assert_almost_eq(stats.damage, 12.0, 0.001, "全局强化加法通道")
	assert_almost_eq(stats.fire_rate, 8.64, 0.001, "全局强化乘法通道")

func test_keywords_merged_from_attachments() -> void:
	model.keywords = ["PIERCE"]
	var att := _make_attachment(AttachmentData.AttachmentSlot.MUZZLE, [])
	att.keywords = ["BURN", "PIERCE"]
	var stats := WeaponStats.compute(model, [att], null)
	assert_eq(stats.keywords, ["PIERCE", "BURN"], "模型词条 + 配件词条去重合并")

func test_pellets_from_model() -> void:
	model.pellets = 6
	var stats := WeaponStats.compute(model, [], null)
	assert_eq(stats.pellets, 6)

func test_null_model_returns_safe_defaults() -> void:
	var stats := WeaponStats.compute(null, [], null)
	assert_almost_eq(stats.damage, 0.0, 0.001)
	assert_eq(stats.mag_size, 1)
