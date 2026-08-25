extends GutTest
## 修复验证：爆炸 5 帧动画必须“播完即消失”（拦截 SpriteFrames 循环/无隐藏回归）

func test_explosion_hides_after_duration() -> void:
	await wait_process_frames(2)  # 确保 FxBurst._ensure_root 已建池
	var before := FxBurst.get_active_explosion_count()
	FxBurst.spawn_explosion(Vector2(100, 100), 1.0)
	await wait_process_frames(1)
	assert_eq(FxBurst.get_active_explosion_count(), before + 1,
		"spawn 后应有一个可见爆炸")
	await wait_seconds(0.6)
	assert_eq(FxBurst.get_active_explosion_count(), before,
		"0.35s 动画播完后应自动隐藏（信号 + 兜底定时）")
