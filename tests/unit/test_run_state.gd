extends GutTest
## 当局资源（RunState）：货币/建材/应急储备 + 全局强化通道

var run_state: RunState

func before_each() -> void:
	run_state = RunState.new()

func test_initial_resources_zero() -> void:
	assert_eq(run_state.credits, 0)
	assert_eq(run_state.material, 0)
	assert_eq(run_state.reserve, 0)

func test_credits_add_and_spend() -> void:
	run_state.add_credits(100)
	assert_eq(run_state.credits, 100)
	assert_true(run_state.try_spend_credits(40))
	assert_eq(run_state.credits, 60)
	assert_false(run_state.try_spend_credits(100), "余额不足拒绝")
	assert_eq(run_state.credits, 60, "拒绝消费不扣减")

func test_material_add_and_spend() -> void:
	run_state.add_material(2)
	assert_true(run_state.try_spend_material(1))
	assert_eq(run_state.material, 1)
	assert_false(run_state.try_spend_material(2), "建材不足拒绝")

func test_reserve_spend() -> void:
	run_state.add_reserve(2)
	assert_true(run_state.try_spend_reserve())
	assert_eq(run_state.reserve, 1)
	assert_false(run_state.try_spend_reserve(2), "储备不足拒绝")

func test_bonus_modifier_add_and_mul() -> void:
	var mod := AttributeModifierData.new()
	mod.attribute = &"damage"
	mod.amount = 3.0
	run_state.apply_bonus_modifier(mod)
	assert_almost_eq(run_state.bonus.get_additive(&"damage"), 3.0, 0.001)
	var mod_mul := AttributeModifierData.new()
	mod_mul.attribute = &"damage"
	mod_mul.multiplier = 1.5
	run_state.apply_bonus_modifier(mod_mul)
	assert_almost_eq(run_state.bonus.get_multiplicative(&"damage"), 1.5, 0.001)

func test_changed_event_emitted() -> void:
	var events := [0]
	EventBus.subscribe(&"RunStateChangedEvent",
		func(_e: Event) -> void: events[0] += 1)
	run_state.add_credits(10)
	run_state.add_material(1)
	run_state.add_reserve(1)
	assert_eq(events[0], 3, "每次资源变化广播一次")
