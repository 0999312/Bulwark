extends GutTest
## P2-18：最小 meta 测试（战功货币 + 阈值自动解锁 + 持久化）

func before_each() -> void:
	MetaProgress.reset()

func after_each() -> void:
	MetaProgress.reset()

func test_add_credits_and_unlock_thresholds() -> void:
	assert_eq(MetaProgress.get_meta_credits(), 0)
	assert_eq(MetaProgress.get_unlocked_models().size(), 0, "0 战功无解锁")
	MetaProgress.add_meta_credits(2)
	assert_eq(MetaProgress.get_meta_credits(), 2)
	var unlocked := MetaProgress.get_unlocked_models()
	assert_true(unlocked.has("bulwark:weapon/model/ar_2"), "1 解锁 AR-2")
	assert_true(unlocked.has("bulwark:weapon/model/sg_2"), "2 解锁 SG-2")
	assert_false(unlocked.has("bulwark:weapon/model/lmg_1"), "4 未到，LMG-1 未解锁")

func test_next_unlock_and_all_unlocked() -> void:
	MetaProgress.add_meta_credits(99)
	assert_eq(MetaProgress.get_meta_credits(), 99)
	assert_eq(MetaProgress.get_unlocked_models().size(), MetaProgress.UNLOCK_MODELS.size())
	assert_eq(MetaProgress.get_next_unlock(), {}, "全部解锁后无下一个")

func test_persistence_roundtrip() -> void:
	MetaProgress.add_meta_credits(5)
	# 模拟重新加载（清内存缓存）
	MetaProgress._cache.clear()
	assert_eq(MetaProgress.get_meta_credits(), 5, "从磁盘读回战功")
	MetaProgress._cache.clear()
	assert_true(MetaProgress.get_unlocked_models().has("bulwark:weapon/model/lmg_1"),
		"重新加载后解锁状态保持")
