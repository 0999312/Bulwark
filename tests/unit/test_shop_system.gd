extends GutTest
## 波间商店（ShopSystem）：随机 4 商品 + 固定物资、价格递增 1.3^n、购买效果应用

var run_state: RunState
var shop: ShopSystem
var _purchased: Array[String] = []
var _rejected: Array[String] = []

func before_each() -> void:
	run_state = RunState.new()
	shop = ShopSystem.new(run_state)
	_purchased.clear()
	_rejected.clear()
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"ShopPurchasedEvent",
		func(e: ShopPurchasedEvent) -> void: _purchased.append(e.item_location))
	EventBus.subscribe(&"ShopPurchaseRejectedEvent",
		func(e: ShopPurchaseRejectedEvent) -> void: _rejected.append(e.item_location))

func _make_item(id: String, category: int = ShopItemData.Category.STAT_PLAYER,
		base_price: int = 50, rarity: int = ShopItemData.Rarity.COMMON,
		is_fixed: bool = false) -> ShopItemData:
	var item := ShopItemData.new()
	item.id = id
	item.category = category
	item.base_price = base_price
	item.rarity = rarity
	item.is_fixed = is_fixed
	return item

func test_refresh_picks_four_random_plus_fixed() -> void:
	var pool: Array[ShopItemData] = []
	for i in 8:
		pool.append(_make_item("shop/item/pool_%d" % i))
	var fixed: Array[ShopItemData] = [_make_item("shop/item/fixed_1", ShopItemData.Category.BARRICADE, 60, 0, true)]
	shop.setup(pool, fixed)
	shop.refresh(42)
	assert_eq(shop.offers.size(), 5, "4 随机 + 1 固定")
	assert_true(shop.is_offered("bulwark:shop/item/fixed_1"), "固定物资恒上架")

func test_refresh_deterministic_with_seed() -> void:
	var pool: Array[ShopItemData] = []
	for i in 6:
		pool.append(_make_item("shop/item/pool_%d" % i))
	shop.setup(pool, [])
	shop.refresh(7)
	var first_ids: Array[String] = []
	for offer in shop.offers:
		first_ids.append(offer.item.id)
	shop.refresh(7)
	var second_ids: Array[String] = []
	for offer in shop.offers:
		second_ids.append(offer.item.id)
	assert_eq(first_ids, second_ids, "同种子同商品集（顺序一致）")

func test_price_escalates_30_percent_per_purchase() -> void:
	var item := _make_item("shop/item/esc", ShopItemData.Category.STAT_PLAYER, 100)
	shop.setup([item], [])
	shop.refresh(1)
	run_state.add_credits(10000)
	assert_eq(shop.get_price(item), 100)
	assert_true(shop.try_purchase("bulwark:shop/item/esc", Callable()))
	assert_eq(shop.get_price(item), 130, "首次购买后 100 × 1.3 = 130")
	shop.refresh(2)
	assert_eq(shop.get_price(item), 130)
	assert_true(shop.try_purchase("bulwark:shop/item/esc", Callable()))
	assert_eq(shop.get_price(item), 169, "第二次后 130 × 1.3 = 169")

func test_purchase_rejected_without_credits() -> void:
	var item := _make_item("shop/item/expensive", ShopItemData.Category.STAT_PLAYER, 200)
	shop.setup([item], [])
	shop.refresh(1)
	assert_false(shop.try_purchase("bulwark:shop/item/expensive", Callable()))
	assert_eq(_rejected, ["bulwark:shop/item/expensive"])
	assert_eq(run_state.credits, 0, "拒绝购买不扣货币")

func test_purchase_rejected_when_not_offered() -> void:
	shop.setup([], [])
	shop.refresh(1)
	assert_false(shop.try_purchase("bulwark:shop/item/ghost", Callable()))
	assert_eq(_rejected, ["bulwark:shop/item/ghost"])

func test_stat_purchase_forwards_to_effect_handler() -> void:
	# STAT 商品效果经 effect_handler 回调（装配层决定落点：玩家/武器修正）
	var item := _make_item("shop/item/dmg", ShopItemData.Category.STAT_WEAPON, 60)
	var mod := AttributeModifierData.new()
	mod.attribute = &"damage"
	mod.amount = 2.0
	item.modifier = mod
	shop.setup([item], [])
	shop.refresh(1)
	run_state.add_credits(1000)
	var handled: Array[ShopItemData] = []
	assert_true(shop.try_purchase("bulwark:shop/item/dmg",
		func(it: ShopItemData) -> void: handled.append(it)))
	assert_eq(handled.size(), 1, "effect_handler 收到商品")
	assert_eq(handled[0].modifier.attribute, &"damage")
	assert_eq(_purchased, ["bulwark:shop/item/dmg"])

func test_effect_handler_called_for_non_stat() -> void:
	# 非 STAT 商品（配件/路障/储备）效果经 effect_handler 回调（装配层注入）
	var item := _make_item("shop/item/barricade", ShopItemData.Category.BARRICADE, 60)
	item.barricade_count = 1
	shop.setup([item], [])
	shop.refresh(1)
	run_state.add_credits(1000)
	var handled: Array[int] = [0]
	assert_true(shop.try_purchase("bulwark:shop/item/barricade",
		func(_it: ShopItemData) -> void: handled[0] += 1))
	assert_eq(handled[0], 1, "effect_handler 被调用")

func test_rarity_price_coefficient() -> void:
	var common := _make_item("shop/item/c", ShopItemData.Category.STAT_PLAYER, 100, ShopItemData.Rarity.COMMON)
	var epic := _make_item("shop/item/e", ShopItemData.Category.STAT_PLAYER, 100, ShopItemData.Rarity.EPIC)
	assert_eq(common.price_with_rarity(), 100)
	assert_eq(epic.price_with_rarity(), 320, "史诗 3.2× 基础价")
