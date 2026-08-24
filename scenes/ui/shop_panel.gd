class_name ShopPanel
extends BaseModalPanel
## 波间商店面板（M1 完整实现，M5d 统一模态基类）
## 数据绑定：订阅 ShopRefreshedEvent / ShopPurchasedEvent / ShopPurchaseRejectedEvent / RunStateChangedEvent
## 意图（前端 → 后端）：try_purchase / equip_attachment / unequip_attachment
## 只读状态：shop.offers / weapon_slots 槽位 / run_state 资源 / bag 背包引用
## 注意：bag 是 GameSession.attachment_bag 的引用，append/erase 直接反映回后端装配层。

const FONT := preload("res://assets/fonts/MiSans-Semibold.ttf")

## 稀有度配色（统一 UiPalette：白/蓝/紫/金）
const RARITY_COLORS := {
	ShopItemData.Rarity.COMMON: UiPalette.RARITY_COMMON,
	ShopItemData.Rarity.RARE: UiPalette.RARITY_RARE,
	ShopItemData.Rarity.EPIC: UiPalette.RARITY_EPIC,
	ShopItemData.Rarity.LEGENDARY: UiPalette.RARITY_LEGENDARY,
}

@onready var title_label: Label = %TitleLabel
@onready var currency_label: Label = %CurrencyLabel
@onready var offers_header: Label = %OffersHeader
@onready var offers_container: VBoxContainer = %OffersContainer
@onready var sort_option: OptionButton = %SortOption
@onready var feedback_label: Label = %FeedbackLabel
@onready var continue_button: Button = %ContinueButton
@onready var weapon_label: Label = %WeaponLabel
@onready var slot_main_button: Button = %SlotMainButton
@onready var slot_sub_button: Button = %SlotSubButton
@onready var slot_pistol_button: Button = %SlotPistolButton
@onready var models_container: VBoxContainer = %ModelsContainer
@onready var slots_overview: HBoxContainer = %SlotsOverview
@onready var attach_header: Label = %AttachHeader
@onready var attachment_slots_container: VBoxContainer = %AttachmentSlotsContainer
@onready var bag_header: Label = %BagHeader
@onready var bag_container: VBoxContainer = %BagContainer

var _shop: ShopSystem
var _weapon_slots: WeaponSlots
var _run_state: RunState
var _bag: Array[String] = []
var _arsenal: Arsenal
## 购买效果回调（GameSession 装配层注入：STAT 玩家/武器强化 + 装备类资源统一裁决）
var _effect_handler: Callable


func _on_open(data: Dictionary = {}) -> void:
	super(data)
	_shop = data.get("shop") as ShopSystem
	_weapon_slots = data.get("weapon_slots") as WeaponSlots
	_run_state = data.get("run_state") as RunState
	var bag := data.get("bag") as Array[String]
	_bag = bag if bag != null else []
	# effect_handler 可能缺省（任务 data 结构不含它）→ 用 is 判断避免 null as Callable 抛 Invalid cast
	var handler: Variant = data.get("effect_handler", Callable())
	_effect_handler = handler if handler is Callable else Callable()
	var arsenal_variant: Variant = data.get("arsenal", null)
	_arsenal = arsenal_variant as Arsenal if arsenal_variant is Arsenal else null
	if sort_option != null and not sort_option.item_selected.is_connected(_on_sort_changed):
		sort_option.item_selected.connect(_on_sort_changed)
	if slot_main_button != null and not slot_main_button.pressed.is_connected(_on_slot_selected):
		slot_main_button.pressed.connect(_on_slot_selected.bind(WeaponSlots.SLOT_MAIN))
		slot_sub_button.pressed.connect(_on_slot_selected.bind(WeaponSlots.SLOT_SUB))
		slot_pistol_button.pressed.connect(_on_slot_selected.bind(WeaponSlots.SLOT_PISTOL))
	_subscribe()
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)
	_refresh_all()
	continue_button.grab_focus()


func _on_close() -> void:
	super()
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)
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
	_show_feedback(UiText.text("shop.feedback_bought",
		[_item_display_name(event.item_location), event.price_paid]))


func _on_shop_rejected(event: ShopPurchaseRejectedEvent) -> void:
	match event.reason:
		ShopPurchaseRejectedEvent.Reason.NOT_ENOUGH_CREDITS:
			_show_feedback(UiText.text("shop.feedback_not_enough"))
		_:
			_show_feedback(UiText.text("shop.feedback_not_found"))
	_refresh_offers()


func _on_run_state_changed(event: RunStateChangedEvent) -> void:
	# M3 问题 4：面板绑定本地玩家的 RunState，只响应其资源事件
	if _run_state == null or event.player_id != _run_state.player_id:
		return
	_refresh_currency()

func _on_language_changed(_event: LanguageChangedEvent) -> void:
	_refresh_all()


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
		_show_feedback(UiText.text("shop.feedback_equipped", [_attachment_name(attachment)]))
	else:
		_show_feedback(UiText.text("shop.feedback_equip_failed"))


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
		_show_feedback(UiText.text("shop.feedback_unequipped", [_attachment_name(attachment)]))


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
	_apply_static_texts()
	_refresh_currency()
	_refresh_offers()
	_refresh_bag()
	_refresh_slots()
	_refresh_models()

func _apply_static_texts() -> void:
	title_label.text = UiText.text("shop.title")
	offers_header.text = UiText.text("shop.offers_title")
	sort_option.set_item_text(0, UiText.text("shop.sort_default"))
	sort_option.set_item_text(1, UiText.text("shop.sort_category"))
	sort_option.set_item_text(2, UiText.text("shop.sort_rarity"))
	sort_option.set_item_text(3, UiText.text("shop.sort_price"))
	slot_main_button.text = UiText.text("shop.slot_main")
	slot_sub_button.text = UiText.text("shop.slot_sub")
	slot_pistol_button.text = UiText.text("shop.slot_pistol")
	attach_header.text = UiText.text("shop.attachment_slots")
	bag_header.text = UiText.text("shop.bag")
	continue_button.text = UiText.text("shop.continue")

func _refresh_currency() -> void:
	if _run_state == null:
		currency_label.text = UiText.text("hud.resources_placeholder")
		return
	currency_label.text = UiText.text("hud.resources",
		[_run_state.credits, _run_state.material, _run_state.reserve])


func _refresh_offers() -> void:
	_clear_container(offers_container)
	if _shop == null:
		return
	if _shop.offers.is_empty():
		offers_container.add_child(_make_hint_label(UiText.text("shop.no_offers")))
		return
	var sorted: Array = _shop.offers.duplicate()
	_sort_offers(sorted)
	for offer_variant in sorted:
		var offer := offer_variant as ShopRefreshedEvent.Offer
		if offer == null or offer.item == null:
			continue
		offers_container.add_child(_build_offer_row(offer))

func _on_sort_changed(_index: int) -> void:
	_refresh_offers()

func _on_slot_selected(slot_index: int) -> void:
	if _weapon_slots == null:
		return
	_weapon_slots.current_index = slot_index
	_refresh_slots()
	_refresh_models()

func _on_equip_model_pressed(model_location: String) -> void:
	if _weapon_slots == null:
		return
	var slot_index := _weapon_slots.current_index
	if Net.is_client():
		Net.send_intent(&"equip_model", [slot_index, model_location])
		return
	var model := _get_model(model_location)
	if model == null:
		return
	var type_data := _get_weapon_type(model.type_id)
	if type_data == null:
		return
	if _weapon_slots.set_model(slot_index, model, type_data):
		_refresh_slots()
		_refresh_models()
		_show_feedback(UiText.text("shop.feedback_model_changed", [_model_name(model)]))

func _refresh_models() -> void:
	_clear_container(models_container)
	if _weapon_slots == null:
		return
	var slot := _weapon_slots.get_current_slot()
	if slot == null or slot.type_data == null:
		return
	if _arsenal == null:
		models_container.add_child(_make_hint_label(UiText.text("shop.arsenal_empty")))
		return
	for model_location in _arsenal.get_owned_models():
		var model := _get_model(model_location)
		if model == null:
			continue
		var type_data := _get_weapon_type(model.type_id)
		if type_data == null or type_data.slot != slot.type_data.slot:
			continue
		var button := Button.new()
		var current := slot.model_data != null and slot.model_data.id == model.id
		button.text = (UiText.text("shop.current_prefix") if current else "") + _model_name(model)
		button.pressed.connect(_on_equip_model_pressed.bind(model_location))
		button.add_theme_font_override("font", FONT)
		models_container.add_child(button)
	if models_container.get_child_count() == 0:
		models_container.add_child(_make_hint_label(UiText.text("shop.no_models_for_slot")))

func _sort_offers(offers: Array) -> void:
	var mode := sort_option.selected if sort_option != null else 0
	match mode:
		1:
			offers.sort_custom(func(a, b):
				var ia: ShopItemData = a.item
				var ib: ShopItemData = b.item
				return ia.category < ib.category)
		2:
			offers.sort_custom(func(a, b):
				var ia: ShopItemData = a.item
				var ib: ShopItemData = b.item
				return ia.rarity < ib.rarity)
		3:
			offers.sort_custom(func(a, b):
				var ia: ShopItemData = a.item
				var ib: ShopItemData = b.item
				return _current_price(ia) < _current_price(ib))


func _build_offer_row(offer: ShopRefreshedEvent.Offer) -> Control:
	var item := offer.item
	var location := Bulwark.loc(item.id).to_string()

	# 卡片：稀有度色边 + 深色底
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UiPalette.BG_RAISED
	card_style.border_width_left = 3
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = RARITY_COLORS.get(item.rarity, UiPalette.BORDER)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.content_margin_left = 12.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_bottom = 8.0
	card_style.shadow_color = Color(0, 0, 0, 0.25)
	card_style.shadow_size = 4
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = "%s%s" % [_rarity_prefix(item.rarity), _item_name(item)]
	name_label.add_theme_color_override("font_color", RARITY_COLORS.get(item.rarity, Color.WHITE))
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = _item_description(item)
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
	price_style.bg_color = UiPalette.BG_INSET
	price_style.border_width_left = 1
	price_style.border_width_top = 1
	price_style.border_width_right = 1
	price_style.border_width_bottom = 1
	price_style.border_color = UiPalette.ACCENT_DIM
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
	price_label.add_theme_color_override("font_color", UiPalette.ACCENT_BRIGHT)
	price_label.add_theme_font_override("font", FONT)
	price_label.add_theme_font_size_override("font_size", 16)
	price_badge.add_child(price_label)
	actions.add_child(price_badge)

	var owned := _purchase_count(item)
	if owned > 0:
		var owned_label := Label.new()
		owned_label.text = UiText.text("shop.owned_count", [owned])
		owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		owned_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		owned_label.add_theme_font_override("font", FONT)
		owned_label.add_theme_font_size_override("font_size", 12)
		actions.add_child(owned_label)

	var buy_button := Button.new()
	buy_button.text = UiText.text("shop.buy")
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
		weapon_label.text = UiText.text("shop.workbench_empty")
		return
	weapon_label.text = UiText.text("shop.workbench_model", [_model_name(model)])


## 三武器槽概览（信息展示；装配/卸下始终作用于 current_index 当前武器）
func _refresh_weapons_overview() -> void:
	var slot_names: Array[String] = [
		UiText.text("common.slot_main"),
		UiText.text("common.slot_sub"),
		UiText.text("common.slot_pistol"),
	]
	for i: int in WeaponSlots.SLOT_COUNT:
		var slot := _weapon_slots.get_slot(i)
		var model_name := ""
		if slot != null and slot.model_data != null:
			model_name = _model_name(slot.model_data)
		var label := Label.new()
		label.text = "%d %s%s" % [i + 1, slot_names[i],
			(" · " + model_name) if not model_name.is_empty() else UiText.text("common.empty_paren")]
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color",
			UiPalette.ACCENT_BRIGHT if i == _weapon_slots.current_index else Color(1, 1, 1, 0.4))
		slots_overview.add_child(label)


func _refresh_attachment_slots() -> void:
	var current := _weapon_slots.current_index
	for slot_value: int in AttachmentData.AttachmentSlot.values():
		attachment_slots_container.add_child(_build_attachment_slot_row(current, slot_value))


func _build_attachment_slot_row(slot_index: int, attachment_slot: int) -> Control:
	var attachment := _weapon_slots.get_attachment(slot_index, attachment_slot)
	var slot_name := _attachment_slot_name(attachment_slot)

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
		status_label.text = UiText.text("common.empty")
		status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.32))
	else:
		status_label.text = _attachment_name(attachment)
		status_label.add_theme_color_override("font_color", UiPalette.INFO)
	status_label.add_theme_font_override("font", FONT)
	status_label.add_theme_font_size_override("font_size", 14)
	row.add_child(status_label)

	if attachment != null:
		var unequip_button := Button.new()
		unequip_button.text = UiText.text("shop.unequip")
		unequip_button.pressed.connect(_on_unequip_pressed.bind(slot_index, attachment_slot))
		unequip_button.add_theme_font_override("font", FONT)
		row.add_child(unequip_button)

	return row


func _refresh_bag() -> void:
	_clear_container(bag_container)
	if _bag.is_empty():
		bag_container.add_child(_make_hint_label(UiText.text("shop.bag_empty")))
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
		name_label.add_theme_color_override("font_color", UiPalette.DANGER_SOFT)
	else:
		name_label.text = "%s（%s）" % [_attachment_name(attachment),
			_attachment_slot_name(attachment.slot)]
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 14)
	row.add_child(name_label)

	var equip_button := Button.new()
	equip_button.text = UiText.text("shop.equip")
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

func _get_model(location: String) -> WeaponModelData:
	var registry := RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as WeaponModelData

func _get_weapon_type(location: String) -> WeaponTypeData:
	var registry := RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as WeaponTypeData


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
	return _item_name(item) if item != null else location

func _item_name(item: ShopItemData) -> String:
	return UiText.content_name(item.id, item.display_name)

func _item_description(item: ShopItemData) -> String:
	return UiText.content_description(item.id, item.description)

func _model_name(model: WeaponModelData) -> String:
	return UiText.content_name(model.id, model.display_name)

func _attachment_name(attachment: AttachmentData) -> String:
	return UiText.content_name(attachment.id, attachment.display_name)

static func _attachment_slot_name(attachment_slot: int) -> String:
	match attachment_slot:
		AttachmentData.AttachmentSlot.MUZZLE:
			return UiText.localized("content.attachment_slot_muzzle.name", "枪口")
		AttachmentData.AttachmentSlot.SIGHT:
			return UiText.localized("content.attachment_slot_sight.name", "瞄具")
		AttachmentData.AttachmentSlot.MAG:
			return UiText.localized("content.attachment_slot_mag.name", "弹匣")
		AttachmentData.AttachmentSlot.STOCK:
			return UiText.localized("content.attachment_slot_stock.name", "枪托")
		_:
			return UiText.text("common.unknown")


func _rarity_prefix(rarity: int) -> String:
	match rarity:
		ShopItemData.Rarity.RARE:
			return UiText.text("shop.rarity_rare")
		ShopItemData.Rarity.EPIC:
			return UiText.text("shop.rarity_epic")
		ShopItemData.Rarity.LEGENDARY:
			return UiText.text("shop.rarity_legendary")
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
