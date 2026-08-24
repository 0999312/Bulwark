extends GutTest
## UI 布局回归：军需站面板不得因商品/型号增多而超出屏幕；
## 滚动容器必须常显且可交互（SHOW_ALWAYS + 面板自身被约束为填充视口）。

func test_shop_panel_is_viewport_constrained() -> void:
	var scene := load("res://scenes/ui/shop_panel.tscn") as PackedScene
	assert_not_null(scene)
	var panel := scene.instantiate() as Control
	add_child_autofree(panel)
	var margin := panel.get_node("Margin") as Control
	assert_eq(margin.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(margin.size_flags_vertical, Control.SIZE_EXPAND_FILL)
	var card := panel.get_node("Margin/Panel") as Control
	assert_eq(card.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(card.size_flags_vertical, Control.SIZE_EXPAND_FILL,
		"面板必须按视口约束尺寸，不能按内容无限撑大")

func test_shop_scrollbars_always_visible() -> void:
	var scene := load("res://scenes/ui/shop_panel.tscn") as PackedScene
	var panel := scene.instantiate() as Control
	add_child_autofree(panel)
	var offers_scroll := panel.find_child("OffersScroll", true, false) as ScrollContainer
	assert_not_null(offers_scroll)
	assert_eq(offers_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_ALWAYS,
		"商品区滚动条常显")
	var right_scroll := panel.find_child("RightScroll", true, false) as ScrollContainer
	assert_not_null(right_scroll, "右栏（改枪台/背包）必须由滚动容器包裹")
	assert_eq(right_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_ALWAYS,
		"右栏滚动条常显")
	assert_eq(right_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
