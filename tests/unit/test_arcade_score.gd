extends GutTest
## P1-10：ArcadeScore 纯逻辑测试（分数/连击/倍率/奖励/事件）

var _events: Array[ScoreChangedEvent] = []

func before_each() -> void:
	_events.clear()
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"ScoreChangedEvent",
		func(e: ScoreChangedEvent) -> void: _events.append(e))

func test_kill_scores_and_combo_multiplier() -> void:
	var sc := ArcadeScore.new(0)
	var gain1 := sc.register_kill(100)
	var gain2 := sc.register_kill(100)
	assert_eq(gain1, 100, "首杀无连击加成")
	assert_eq(gain2, 125, "第二杀 ×1.25")
	assert_eq(sc.score, 225)
	assert_eq(sc.max_combo, 2)
	assert_eq(sc.combo, 2)
	assert_almost_eq(sc.get_multiplier(), 1.5, 0.01)

func test_combo_multiplier_cap_and_external() -> void:
	var sc := ArcadeScore.new(0)
	for i in 30:
		sc.register_kill(10)
	assert_almost_eq(sc.get_multiplier(), ArcadeScore.COMBO_MULTIPLIER_CAP, 0.01, "连击倍率封顶 6")
	sc.set_external_multiplier(2.0)
	assert_almost_eq(sc.get_multiplier(), 12.0, 0.01, "道具加倍与连击相乘")

func test_combo_resets_after_window() -> void:
	var sc := ArcadeScore.new(0)
	sc.register_kill(100)
	sc.tick(ArcadeScore.COMBO_WINDOW + 0.1)
	assert_eq(sc.combo, 0, "超时连击重置")
	assert_eq(sc.score, 100, "分数保留")

func test_wave_chapter_bonuses() -> void:
	var sc := ArcadeScore.new(0)
	var wave_bonus := sc.on_wave_cleared(true, 1.2)
	assert_eq(wave_bonus, 600, "PERFECT WAVE +500×1.2")
	var chapter_bonus := sc.on_chapter_cleared(1.5)
	assert_eq(chapter_bonus, 3000, "章清 +2000×1.5")
	assert_eq(sc.score, 3600)
	assert_eq(sc.combo, 0, "奖励后连击重置")

func test_non_perfect_wave_no_bonus() -> void:
	var sc := ArcadeScore.new(0)
	assert_eq(sc.on_wave_cleared(false, 1.0), 0)

func test_score_event_emitted_with_player_id() -> void:
	var sc := ArcadeScore.new(3)
	sc.register_kill(50)
	assert_eq(_events.size(), 1)
	assert_eq(_events[0].player_id, 3)
	assert_eq(_events[0].score, 50)
