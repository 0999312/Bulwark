extends GutTest
## 复活系统（ReviveSystem，P7/P20）：消耗应急储备 → 复活 CD → 复活完成；储备耗尽判负

var run_state: RunState
var revive: ReviveSystem
var _started := 0
var _revived := 0

func before_each() -> void:
	run_state = RunState.new()
	revive = ReviveSystem.new(run_state)
	_started = 0
	_revived = 0
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"ReviveStartedEvent", func(_e: Event) -> void: _started += 1)
	EventBus.subscribe(&"RevivedEvent", func(_e: Event) -> void: _revived += 1)

func test_revive_consumes_reserve_and_starts_cd() -> void:
	run_state.add_reserve(2)
	assert_true(revive.on_player_died())
	assert_eq(run_state.reserve, 1, "复活消耗 1 储备")
	assert_true(revive.is_reviving())
	assert_eq(_started, 1)

func test_revive_completes_after_cd() -> void:
	run_state.add_reserve(1)
	assert_true(revive.on_player_died())
	revive.tick(1.0)
	assert_true(revive.is_reviving(), "CD 未到仍复活中")
	revive.tick(2.0)  # 剩余 3.0 → 1.0
	assert_true(revive.is_reviving())
	revive.tick(1.5)  # 1.0 → -0.5 ≤ 0 → 完成
	assert_false(revive.is_reviving(), "CD 结束复活完成")
	assert_eq(_revived, 1)

func test_no_reserve_means_no_revive() -> void:
	assert_false(revive.on_player_died(), "无储备拒绝复活")
	assert_false(revive.is_reviving())
	assert_eq(_started, 0, "不广播复活开始")
	assert_eq(_revived, 0)

func test_second_death_during_revive_rejected() -> void:
	run_state.add_reserve(1)
	assert_true(revive.on_player_died())
	assert_false(revive.on_player_died(), "复活 CD 中再次阵亡拒绝")
	assert_eq(run_state.reserve, 0, "仅消耗一次")

func test_reserve_added_by_shop_before_death() -> void:
	run_state.add_reserve(2)
	assert_true(revive.on_player_died())
	# 复活 CD 结束 → 复活完成（state 回 IDLE）后才能再次阵亡
	revive.tick(ReviveSystem.REVIVE_CD + 1.0)
	assert_true(revive.on_player_died(), "储备充足可多次复活")
	assert_eq(run_state.reserve, 0, "两次复活消耗 2 储备")
	assert_eq(_started, 2)
	# 储备耗尽：即使 CD 完成也拒绝复活
	revive.tick(ReviveSystem.REVIVE_CD + 1.0)
	assert_false(revive.on_player_died(), "储备耗尽拒绝复活")
	assert_eq(_started, 2)

func test_revive_progress() -> void:
	run_state.add_reserve(1)
	revive.on_player_died()
	assert_almost_eq(revive.get_revive_progress(), 0.0, 0.01)
	revive.tick(ReviveSystem.REVIVE_CD / 2.0)
	assert_almost_eq(revive.get_revive_progress(), 0.5, 0.05, "CD 过半进度 50%")
