extends GutTest
## M2 波次方位数量级分级（WaveComposition.summarize_tiers / HUD 简化显示）
## 规则：按方向聚合取最大 count；count >= HEAVY_THRESHOLD(6) = 大量，否则少量

func _make_composition() -> WaveComposition:
	var comp := WaveComposition.new()
	comp.add_group(WaveData.Direction.N, 8, "bulwark:enemy/runner")      # 大量
	comp.add_group(WaveData.Direction.NE, 3, "bulwark:enemy/runner_fast") # 少量
	comp.add_group(WaveData.Direction.E, 7, "bulwark:enemy/runner")      # 大量
	comp.add_group(WaveData.Direction.E, 4, "bulwark:enemy/runner_fast") # 同方向聚合取最大 → 仍大量
	comp.add_group(WaveData.Direction.SW, 2, "bulwark:enemy/runner_tough") # 少量
	return comp

func test_tiers_group_by_direction_and_merge() -> void:
	var tiers := _make_composition().summarize_tiers()
	var heavy: Array = tiers["heavy"]
	var light: Array = tiers["light"]
	assert_eq(heavy, [WaveData.Direction.N, WaveData.Direction.E], "大量方向（聚合后 E 仍大量）")
	assert_eq(light, [WaveData.Direction.NE, WaveData.Direction.SW], "少量方向")

func test_tiers_sorted() -> void:
	var comp := WaveComposition.new()
	comp.add_group(WaveData.Direction.SW, 7, "")
	comp.add_group(WaveData.Direction.N, 7, "")
	comp.add_group(WaveData.Direction.E, 7, "")
	var heavy: Array = comp.summarize_tiers()["heavy"]
	assert_eq(heavy, [WaveData.Direction.N, WaveData.Direction.E, WaveData.Direction.SW], "按方向序排序")

func test_threshold_boundary() -> void:
	var comp := WaveComposition.new()
	comp.add_group(WaveData.Direction.N, 6, "")  # == 阈值 → 大量
	comp.add_group(WaveData.Direction.S, 5, "")  # < 阈值 → 少量
	var tiers := comp.summarize_tiers()
	assert_eq(tiers["heavy"], [WaveData.Direction.N], "等于阈值算大量")
	assert_eq(tiers["light"], [WaveData.Direction.S], "低于阈值算少量")

func test_custom_threshold() -> void:
	var comp := WaveComposition.new()
	comp.add_group(WaveData.Direction.N, 5, "")
	comp.add_group(WaveData.Direction.S, 5, "")
	var tiers := comp.summarize_tiers(5)
	assert_eq(tiers["heavy"], [WaveData.Direction.N, WaveData.Direction.S], "自定义阈值生效")

func test_empty_composition() -> void:
	var tiers := WaveComposition.new().summarize_tiers()
	assert_true(tiers["heavy"].is_empty())
	assert_true(tiers["light"].is_empty())

func test_hud_format_tiers_text() -> void:
	# HUD 纯函数：分级摘要文本（含方位箭头）
	var comp := _make_composition()
	var event := WaveWarningEvent.new(2, 6, comp, comp.summarize_tiers())
	var text := Hud._format_direction_tiers(event)
	assert_eq(text, "大量 ↑→ · 少量 ↗↙", "分级摘要文本（箭头按方向序）")

func test_hud_format_fallback_without_tiers() -> void:
	var comp := _make_composition()
	var event := WaveWarningEvent.new(2, 6, comp)  # 无 direction_tiers → 旧逻辑回退（逐方向罗列，空格分隔）
	var text := Hud._format_direction_tiers(event)
	assert_eq(text, "↑ ↗ → → ↙", "回退逐方向罗列（旧行为：空格分隔）")

func test_hud_format_null_composition_safe() -> void:
	# client 镜像事件：composition 为 null + 无 tiers → 空串不崩
	var event := WaveWarningEvent.new(2, 6, null)
	assert_eq(Hud._format_direction_tiers(event), "")
