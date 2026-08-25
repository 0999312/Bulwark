extends GutTest
## P1-12：PowerUpSystem buff 计时/到期/刷新测试

var _applied: Array[String] = []
var _expired: Array[String] = []

func before_each() -> void:
	_applied.clear()
	_expired.clear()
	EventBus.clear_all_listeners()

func _make_system() -> PowerUpSystem:
	var sys := PowerUpSystem.new()
	sys.setup(
		func(data: PowerUpData, _pid: int) -> void: _applied.append(data.id),
		func(data: PowerUpData, _pid: int) -> void: _expired.append(data.id))
	return sys

func _make_data(id: String, duration: float, effect := PowerUpData.EffectKind.FIRE_RATE) -> PowerUpData:
	var d := PowerUpData.new()
	d.id = id
	d.duration = duration
	d.effect = effect
	d.amount = 1.5
	return d

func test_timed_buff_applies_once_and_expires() -> void:
	var sys := _make_system()
	var data := _make_data("power/fire_rate", 2.0)
	sys.activate(data, 0)
	assert_true(sys.is_active("power/fire_rate", 0), "激活后 is_active")
	assert_eq(_applied.size(), 1)
	assert_almost_eq(sys.get_remaining("power/fire_rate", 0), 2.0, 0.01)
	sys.tick(1.0)
	assert_almost_eq(sys.get_remaining("power/fire_rate", 0), 1.0, 0.01)
	sys.tick(1.1)
	assert_false(sys.is_active("power/fire_rate", 0), "到期移除")
	assert_eq(_expired, ["power/fire_rate"])

func test_refresh_does_not_reapply() -> void:
	var sys := _make_system()
	var data := _make_data("power/fire_rate", 2.0)
	sys.activate(data, 0)
	sys.activate(data, 0)
	assert_eq(_applied.size(), 1, "刷新时长不重复应用修正")
	assert_almost_eq(sys.get_remaining("power/fire_rate", 0), 2.0, 0.01)

func test_instant_effect_applies_immediately() -> void:
	var sys := _make_system()
	var data := _make_data("power/ammo", 0.0, PowerUpData.EffectKind.AMMO)
	sys.activate(data, 0)
	assert_eq(_applied, ["power/ammo"])
	assert_false(sys.is_active("power/ammo", 0))

func test_score_multiplier_only_affects_owner() -> void:
	var sys := _make_system()
	var data := _make_data("power/score", 10.0, PowerUpData.EffectKind.SCORE_MULT)
	data.amount = 2.0
	sys.activate(data, 1)
	assert_almost_eq(sys.score_multiplier(1), 2.0, 0.01)
	assert_almost_eq(sys.score_multiplier(0), 1.0, 0.01, "其他玩家不受影响")

func test_active_summary_per_player() -> void:
	var sys := _make_system()
	sys.activate(_make_data("power/score", 5.0, PowerUpData.EffectKind.SCORE_MULT), 0)
	sys.activate(_make_data("power/score", 5.0, PowerUpData.EffectKind.SCORE_MULT), 1)
	assert_eq(sys.get_active_summary(0).size(), 1)
	assert_eq(sys.get_active_summary(1).size(), 1)
