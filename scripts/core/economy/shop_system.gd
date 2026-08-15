class_name ShopSystem
extends RefCounted
## 波间商店（后端，纯逻辑；架构 §4.8 / P22）
## - 随机区：每波结算从商品池抽 4 个（种子确定性）
## - 固定区：is_fixed 商品恒上架（路障组件 / 应急储备等）
## - 价格：base × rarity_coef × 1.3^(同商品购买次数)
## - 购买：验证货币 → 扣减 → 应用效果（属性强化 / 配件入背包 / 路障额度 / 储备）→ 广播
## 效果应用回调：购买时通过 effect_handler（装配层注入，避免后端引用 Registry/表现）

const PRICE_ESCALATION := 1.3    # 同商品重复购买价格递增（P22：+30% 级）
const RANDOM_OFFER_COUNT := 4    # 随机区商品数（P22）

## 商品池（全部可上架商品；is_fixed 只进固定区）
var pool: Array[ShopItemData] = []
## 固定物资（每波恒上架）
var fixed_items: Array[ShopItemData] = []
## 已购次数：item_location -> int（价格递增）
var purchase_counts: Dictionary = {}

## 当前上架商品（随机 4 + 固定区；ShopRefreshedEvent 广播同构）
var offers: Array = []  # Array[ShopRefreshedEvent.Offer]

var _rng: SeededRNG
var _run_state: RunState

func _init(p_run_state: RunState, p_rng: SeededRNG = null) -> void:
	_run_state = p_run_state
	_rng = p_rng if p_rng != null else SeededRNG.new()

## 装配商品池（ContentBootstrap 注入：随机池 + 固定物资）
func setup(pool_items: Array[ShopItemData], fixed: Array[ShopItemData]) -> void:
	pool = pool_items
	fixed_items = fixed

## 刷新上架（波间结算调用；种子确定性便于测试）
func refresh(seed: int) -> void:
	_rng.set_seed(seed)
	offers.clear()
	var candidates := pool.duplicate()
	_rng.shuffle(candidates)
	for i in mini(RANDOM_OFFER_COUNT, candidates.size()):
		var item: ShopItemData = candidates[i]
		offers.append(_make_offer(item))
	for item: ShopItemData in fixed_items:
		offers.append(_make_offer(item))
	EventBus.publish(ShopRefreshedEvent.new(offers))

## 当前价格（P22：base × rarity × 1.3^n）
func get_price(item: ShopItemData) -> int:
	if item == null:
		return 0
	var base := item.price_with_rarity()
	var n: int = purchase_counts.get(item.id, 0)
	return maxi(1, roundi(base * pow(PRICE_ESCALATION, n)))

## 购买意图；返回是否受理（货币不足 / 未上架 → 拒绝广播）
func try_purchase(item_location: String, effect_handler: Callable) -> bool:
	var item := _find_offer_item(item_location)
	if item == null:
		EventBus.publish(ShopPurchaseRejectedEvent.new(
			item_location, ShopPurchaseRejectedEvent.Reason.NOT_FOUND))
		return false
	var price := get_price(item)
	if not _run_state.try_spend_credits(price):
		EventBus.publish(ShopPurchaseRejectedEvent.new(
			item_location, ShopPurchaseRejectedEvent.Reason.NOT_ENOUGH_CREDITS))
		return false
	purchase_counts[item.id] = purchase_counts.get(item.id, 0) + 1
	_apply_effect(item, effect_handler)
	EventBus.publish(ShopPurchasedEvent.new(item_location, price))
	return true

## 查询：某商品是否当前上架
func is_offered(item_location: String) -> bool:
	return _find_offer_item(item_location) != null

## 已购次数（UI 展示 / 测试断言）
func get_purchase_count(item_id: String) -> int:
	return purchase_counts.get(item_id, 0)

func _make_offer(item: ShopItemData) -> ShopRefreshedEvent.Offer:
	return ShopRefreshedEvent.Offer.new(
		item, get_price(item), purchase_counts.get(item.id, 0), _run_state.credits >= get_price(item))

func _find_offer_item(item_location: String) -> ShopItemData:
	for offer in offers:
		var item: ShopItemData = offer.item
		if Bulwark.loc(item.id).to_string() == item_location:
			return item
	return null

## 应用商品效果：全部类别经 effect_handler 回调（装配层注入）
## 装配层职责：STAT_PLAYER → 玩家 AttributeSet；STAT_WEAPON → RunState.bonus；
##              ATTACHMENT → 配件背包；BARRICADE/RESERVE → 资源
func _apply_effect(item: ShopItemData, effect_handler: Callable) -> void:
	if effect_handler.is_valid():
		effect_handler.call(item)
