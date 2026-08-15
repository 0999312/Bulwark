class_name ShopPanel
extends UIPanel
## 波间商店面板（M1 完整实现）
## 数据绑定：订阅 ShopRefreshedEvent / ShopPurchasedEvent / ShopPurchaseRejectedEvent / RunStateChangedEvent
## 意图（前端 → 后端）：try_purchase / equip_attachment / unequip_attachment
## 只读状态：shop.offers / weapon_slots 槽位 / run_state 资源 / bag 背包引用
## 注意：bag 是 GameSession.attachment_bag 的引用，append/erase 直接反映回后端装配层。

const FONT := preload("res://assets/fonts/MiSans-Semibold.ttf")

## 稀有度配色（军事风：白/蓝/紫/金）
const RARITY_COLORS := {
	ShopItemData.Rarity.COMMON: Color(0.82, 0.82, 0.78),
	ShopItemData.Rarity.RARE: Color(0.38, 0.62, 1.0),
	ShopItemData.Rarity.EPIC: Color(0.72, 0.42, 1.0),
	ShopItemData.Rarity.LEGENDARY: Color(1.0, 0.72, 0.2),
}

@onready var title_label: Label = %TitleLabel
@onready var currency_label: Label = %CurrencyLabel
@onready var offers_container: VBoxContainer = %OffersContainer
@onready var feedback_label: Label = %FeedbackLabel
@onready var continue_button: Button = %ContinueButton
@onready var weapon_label: Label = %WeaponLabel
@onready var slots_overview: HBoxContainer = %SlotsOverview
@onready var attachment_slots_container: VBoxContainer = %AttachmentSlotsContainer
@onready var bag_container: VBoxContainer = %BagContainer

var _shop: ShopSystem
var _weapon_slots: WeaponSlots
var _run_state: RunState
var _bag: Array[String] = []
## 购买效果回调（GameSession 装配层注入：STAT 玩家/武器强化 + 装备类资源统一裁决）
var _effect_handler: Callable


func _on_open(data: Dictionary = {}) -> void:
	_shop = data.get("shop") as ShopSystem
	_weapon_slots = data.get("weapon_slots") as WeaponSlots
	_run_state = data.get("run_state") as RunState
	var bag := data.get("bag") as Array[String]
	_bag = bag if bag != null else []
	# effect_handler 可能缺省（任务 data 结构不含它）→ 用 is 判断避免 null as Callable 抛 Invalid cast
	var handler: Variant = data.get("effect_handler", Callable())
	_effect_handler = handler if handler is Callable else Callable()
	_subscribe()
	_refresh_all()
	continue_button.grab_focus()


func _on_close() -> void:
	_unsubscribe()


# ─── 事件订阅 ───

func _subscribe() -> void:
	EventBus.subscribe(&"ShopRefreshedEvent", _on_shop_refreshed)
	EventBus.subscribe(&"ShopPurchasedEvent", _on_shop_purchased)
	EventBus.subscribe(&"ShopPurchaseRejectedEvent", _on_shop_rejected)
	EventBus.subscribe(&"RunStateChangedEvent", _on_run_state_changed)


func _unsubscribe() -> void:
	EventBus.unsubscribe(&"ShopRefreshedEvent", _on_shop_refreshed)
	EventBus.unsubscribe(&"ShopPurchasedEvent", _on_shop_purchased)
	EventBus.unsubscribe(&"ShopPurchaseRejectedEvent", _on_shop_rejected)
	EventBus.unsubscribe(&"RunStateChangedEvent", _on_run_state_changed)


func _on_shop_refreshed(_event: ShopRefreshedEvent) -> void:
	_refresh_offers()


func _on_shop_purchased(event: ShopPurchasedEvent) -> void:
	_refresh_offers()
	_refresh_bag()
	_refresh_slots()
	_show_feedback("购入 %s · ¥%d" % [_item_display_name(event.item_location), event.price_paid])


func _on_shop_rejected(event: ShopPurchaseRejectedEvent) -> void:
	match event.reason:
		ShopPurchaseRejectedEvent.Reason.NOT_ENOUGH_CREDITS:
			_show_feedback("货币不足。")
		_:
			_show_feedback("商品已下架。")
	_refresh_offers()


func _on_run_state_changed(_event: RunStateChangedEvent) -> void:
	_refresh_currency()


# ─── 意图：购买 / 装配 / 卸下 / 继续 ───

func _on_buy_pressed(item_location: String) -> void:
	if _shop == null:
		return
	# M2 多人：client 只发购买意图，host 裁决（防作弊：价格/上架/货币校验全在 host）
	if Net.is_client():
		Net.send_intent(&"purchase", [item_location])
		return
	var handler := _effect_handler
	if not handler.is_valid():
		handler = _make_effect_handler()
	_shop.try_purchase(item_location, handler)


func _on_bag_pressed(location: String) -> void:
	var attachment := _get_attachment(location)
	if attachment == null or _weapon_slots == null:
		return
	var current := _weapon_slots.current_index
	# M2 多人：client 只发装配意图（host 校验背包/槽位并裁决旧件回袋）
	if Net.is_client():
		Net.send_intent(&"equip", [current, location])
		return
	# 同槽替换：先记住旧件，装配成功后旧件回背包，避免配件丢失
	var replaced := _weapon_slots.get_attachment(current, attachment.slot)
	if _weapon_slots.equip_attachment(current, attachment):
		_bag.erase(location)
		if replaced != null and replaced.id != attachment.id:
			_bag.append(Bulwark.loc(replaced.id).to_string())
		_refresh_bag()
		_refresh_slots()
		_show_feedback("已装配 %s" % attachment.display_name)
	else:
		_show_feedback("装配失败。")


func _on_unequip_pressed(slot_index: int, attachment_slot: int) -> void:
	if _weapon_slots == null:
		return
	var attachment := _weapon_slots.get_attachment(slot_index, attachment_slot)
	if attachment == null:
		return
	# M2 多人：client 只发卸下意图
	if Net.is_client():
		Net.send_intent(&"unequip", [slot_index, attachment_slot])
		return
	if _weapon_slots.unequip_attachment(slot_index, attachment_slot):
		_bag.append(Bulwark.loc(attachment.id).to_string())
		_refresh_bag()
		_refresh_slots()
		_show_feedback("已卸下 %s" % attachment.display_name)


func _on_continue_pressed() -> void:
	var tree := get_tree()
	var scene := tree.current_scene
	if scene != null and scene.has_method("on_shop_closed"):
		scene.on_shop_closed()
	else:
		UIManager.close_panel(panel_id)


## 购买效果兜底（GameSession 未注入 effect_handler 时）：ATTACHMENT 入背包 / BARRICADE / RESERVE；
## STAT_* 由 ShopSystem 内部写入 RunState.bonus，无需在此处理。
func _make_effect_handler() -> Callable:
	var bag_ref := _bag
	var run_state_ref := _run_state
	return func(item: ShopItemData) -> void:
		match item.category:
			ShopItemData.Category.ATTACHMENT:
				if not item.attachment_location.is_empty():
					bag_ref.append(item.attachment_location)
			ShopItemData.Category.BARRICADE:
				run_state_ref.add_material(item.barricade_count)
			ShopItemData.Category.RESERVE:
				run_state_ref.add_reserve(item.reserve_count)
			_:
				pass


# ─── 渲染 ───

func _refresh_all() -> void:
	_refresh_currency()
	_refresh_offers()
	_refresh_bag()
	_refresh_slots()


func _refresh_currency() -> void:
	if _run_state == null:
		currency_label.text = "货币 -- · 建材 -- · 储备 --"
		return
	currency_label.text = "货币 %d · 建材 %d · 储备 %d" % [
		_run_state.credits, _run_state.material, _run_state.reserve]


func _refresh_offers() -> void:
	_clear_container(offers_container)
	if _shop == null:
		return
	if _shop.offers.is_empty():
		offers_container.add_child(_make_hint_label("暂无货物。"))
		return
	for offer_variant in _shop.offers:
		var offer := offer_variant as ShopRefreshedEvent.Offer
		if offer == null or offer.item == null:
			continue
		offers_container.add_child(_build_offer_row(offer))


func _build_offer_row(offer: ShopRefreshedEvent.Offer) -> Control:
	var item := offer.item
	var location := Bulwark.loc(item.id).to_string()

	# 卡片：稀有度色边 + 深色底
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.105, 0.14, 0.9)
	card_style.border_width_left = 3
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = RARITY_COLORS.get(item.rarity, Color.WHITE)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.content_margin_left = 12.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = "%s%s" % [_rarity_prefix(item.rarity), item.display_name]
	name_label.add_theme_color_override("font_color", RARITY_COLORS.get(item.rarity, Color.WHITE))
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	desc_label.add_theme_font_override("font", FONT)
	desc_label.add_theme_font_size_override("font_size", 13)
	info.add_child(desc_label)

	row.add_child(info)

	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	actions.add_theme_constant_override("separation", 2)

	# 价格徽章
	var price_badge := PanelContainer.new()
	price_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	var price_style := StyleBoxFlat.new()
	price_style.bg_color = Color(0.12, 0.1, 0.05, 0.9)
	price_style.border_width_left = 1
	price_style.border_width_top = 1
	price_style.border_width_right = 1
	price_style.border_width_bottom = 1
	price_style.border_color = Color(0.9, 0.72, 0.3, 0.8)
	price_style.corner_radius_top_left = 6
	price_style.corner_radius_top_right = 6
	price_style.corner_radius_bottom_right = 6
	price_style.corner_radius_bottom_left = 6
	price_style.content_margin_left = 10.0
	price_style.content_margin_top = 2.0
	price_style.content_margin_right = 10.0
	price_style.content_margin_bottom = 2.0
	price_badge.add_theme_stylebox_override("panel", price_style)

	var price_label := Label.new()
	price_label.text = "¥%d" % _current_price(item)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	price_label.add_theme_font_override("font", FONT)
	price_label.add_theme_font_size_override("font_size", 16)
	price_badge.add_child(price_label)
	actions.add_child(price_badge)

	var owned := _purchase_count(item)
	if owned > 0:
		var owned_label := Label.new()
		owned_label.text = "已购 %d" % owned
		owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		owned_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		owned_label.add_theme_font_override("font", FONT)
		owned_label.add_theme_font_size_override("font_size", 12)
		actions.add_child(owned_label)

	var buy_button := Button.new()
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(96, 0)
	buy_button.disabled = not _can_afford(item)
	buy_button.pressed.connect(_on_buy_pressed.bind(location))
	buy_button.add_theme_font_override("font", FONT)
	actions.add_child(buy_button)

	row.add_child(actions)
	return card


func _refresh_slots() -> void:
	_clear_container(slots_overview)
	_clear_container(attachment_slots_container)
	if _weapon_slots == null:
		return
	_refresh_weapon_label()
	_refresh_weapons_overview()
	_refresh_attachment_slots()


func _refresh_weapon_label() -> void:
	var model := _weapon_slots.get_current_slot().model_data
	if model == null:
		weapon_label.text = "改枪台 · 空"
		return
	weapon_label.text = "改枪台 · %s" % model.display_name


## 三武器槽概览（信息展示；装配/卸下始终作用于 current_index 当前武器）
func _refresh_weapons_overview() -> void:
	var slot_names: Array[String] = ["主", "副", "手枪"]
	for i: int in WeaponSlots.SLOT_COUNT:
		var slot := _weapon_slots.get_slot(i)
		var model_name := ""
		if slot != null and slot.model_data != null:
			model_name = slot.model_data.display_name
		var label := Label.new()
		label.text = "%d %s%s" % [i + 1, slot_names[i],
			(" · " + model_name) if not model_name.is_empty() else "（空）"]
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color",
			Color(1, 0.9, 0.5) if i == _weapon_slots.current_index else Color(1, 1, 1, 0.4))
		slots_overview.add_child(label)


func _refresh_attachment_slots() -> void:
	var current := _weapon_slots.current_index
	for slot_value: int in AttachmentData.AttachmentSlot.values():
		attachment_slots_container.add_child(_build_attachment_slot_row(current, slot_value))


func _build_attachment_slot_row(slot_index: int, attachment_slot: int) -> Control:
	var attachment := _weapon_slots.get_attachment(slot_index, attachment_slot)
	var slot_name: String = AttachmentData.SLOT_NAMES.get(attachment_slot, "未知")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(52, 0)
	name_label.text = slot_name
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 14)
	row.add_child(name_label)

	var status_label := Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if attachment == null:
		status_label.text = "空"
		status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.32))
	else:
		status_label.text = attachment.display_name
		status_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	status_label.add_theme_font_override("font", FONT)
	status_label.add_theme_font_size_override("font_size", 14)
	row.add_child(status_label)

	if attachment != null:
		var unequip_button := Button.new()
		unequip_button.text = "卸下"
		unequip_button.pressed.connect(_on_unequip_pressed.bind(slot_index, attachment_slot))
		unequip_button.add_theme_font_override("font", FONT)
		row.add_child(unequip_button)

	return row


func _refresh_bag() -> void:
	_clear_container(bag_container)
	if _bag.is_empty():
		bag_container.add_child(_make_hint_label("背包是空的。"))
		return
	for location in _bag:
		bag_container.add_child(_build_bag_row(location))


func _build_bag_row(location: String) -> Control:
	var attachment := _get_attachment(location)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if attachment == null:
		name_label.text = location
		name_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	else:
		name_label.text = "%s（%s）" % [attachment.display_name, attachment.get_slot_name()]
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 14)
	row.add_child(name_label)

	var equip_button := Button.new()
	equip_button.text = "装配"
	equip_button.disabled = not _can_equip()
	equip_button.pressed.connect(_on_bag_pressed.bind(location))
	equip_button.add_theme_font_override("font", FONT)
	row.add_child(equip_button)

	return row


# ─── 查询辅助 ───

func _get_attachment(location: String) -> AttachmentData:
	var registry := RegistryManager.get_registry(Bulwark.REG_ATTACHMENT)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as AttachmentData


func _get_shop_item(location: String) -> ShopItemData:
	var registry := RegistryManager.get_registry(Bulwark.REG_SHOP_ITEM)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as ShopItemData


func _current_price(item: ShopItemData) -> int:
	if _shop == null:
		return item.price_with_rarity()
	return _shop.get_price(item)


func _purchase_count(item: ShopItemData) -> int:
	if _shop == null:
		return 0
	return _shop.get_purchase_count(item.id)


func _can_afford(item: ShopItemData) -> bool:
	if _run_state == null:
		return false
	return _run_state.credits >= _current_price(item)


func _can_equip() -> bool:
	if _weapon_slots == null:
		return false
	return _weapon_slots.is_slot_ready(_weapon_slots.current_index)


func _item_display_name(location: String) -> String:
	var item := _get_shop_item(location)
	return item.display_name if item != null else location


func _rarity_prefix(rarity: int) -> String:
	match rarity:
		ShopItemData.Rarity.RARE:
			return "[稀有] "
		ShopItemData.Rarity.EPIC:
			return "[史诗] "
		ShopItemData.Rarity.LEGENDARY:
			return "[传说] "
		_:
			return ""


func _show_feedback(text: String) -> void:
	feedback_label.text = text
	feedback_label.visible = true


func _make_hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 13)
	return label


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
