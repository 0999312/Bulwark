extends GutTest
## M2 网络协议编解码（NetCodec）：快照/事件负载 pack→unpack 往返一致
## 覆盖：嵌套字典/数组/浮点/Vector2 显式数组转换/非法输入回退

func test_snapshot_roundtrip_preserves_all_types() -> void:
	var snapshot := {
		NetCodec.SNAP_TICK: 42,
		NetCodec.SNAP_RUN: {
			NetCodec.RUN_PAUSED: true,
			NetCodec.RUN_CREDITS: 120,
			NetCodec.RUN_BAG: ["bulwark:attachment/red_dot", "bulwark:attachment/ext_mag"],
		},
		NetCodec.SNAP_BASE: {
			NetCodec.BASE_DURABILITY: 399.5,
			NetCodec.BASE_MAX: 400.0,
		},
		NetCodec.SNAP_PLAYERS: {
			"0": {
				NetCodec.PLAYER_POS: NetCodec.vec_to_arr(Vector2(12.25, -3.5)),
				NetCodec.PLAYER_AIM: 0.785398,
				NetCodec.PLAYER_HP: 87.0,
				NetCodec.PLAYER_MAX_HP: 100.0,
				NetCodec.PLAYER_STATE: 2,
			},
		},
		NetCodec.SNAP_ENEMIES: {
			"7": {
				NetCodec.ENEMY_POS: NetCodec.vec_to_arr(Vector2(-520.0, 340.0)),
				NetCodec.ENEMY_STATE: NetCodec.ENEMY_STATE_ALIVE,
				NetCodec.ENEMY_LOCATION: "bulwark:enemy/runner_fast",
			},
		},
	}
	var decoded := NetCodec.unpack_snapshot(NetCodec.pack_snapshot(snapshot))
	assert_eq(decoded, snapshot, "快照往返后字典完全一致")

func test_snapshot_roundtrip_float_precision() -> void:
	# 浮点位差：Vector2 分量为 float32，往返后与源 float64 允许 ~1e-4 容差；其余 float 无损
	var payload := {
		"pos": NetCodec.vec_to_arr(Vector2(0.1, 1234.5678)),
		"aim": -2.9999999,
	}
	var decoded := NetCodec.unpack_snapshot(NetCodec.pack_snapshot(payload))
	var pos: Array = decoded["pos"]
	assert_almost_eq(pos[0], 0.1, 0.001, "x（float32 容差）")
	assert_almost_eq(pos[1], 1234.5678, 0.001, "y（float32 容差）")
	assert_almost_eq(decoded["aim"], -2.9999999, 0.0000001, "角度（float64 无损）")

func test_event_roundtrip() -> void:
	var payload := {
		NetCodec.KEY_PLAYER_ID: 1,
		NetCodec.KEY_WAVE_INDEX: 3,
		NetCodec.KEY_TIERS: {"heavy": [0, 2, 4], "light": [6]},
		NetCodec.KEY_AIM_DIRECTION: NetCodec.vec_to_arr(Vector2(0.7071067, -0.7071067)),
	}
	var decoded := NetCodec.unpack_event(NetCodec.pack_event(payload))
	assert_eq(decoded, payload, "事件负载往返一致")
	assert_eq(decoded[NetCodec.KEY_PLAYER_ID], 1)

func test_unpack_garbage_returns_empty() -> void:
	# 非字典负载（数组/字符串）→ 防御回退空字典（bytes_to_var 短输入会 push 引擎错误，不测该路径）
	var arr_bytes := var_to_bytes([1, 2, 3])
	assert_eq(NetCodec.unpack_snapshot(arr_bytes), {}, "数组负载回退空字典")
	var str_bytes := var_to_bytes("not-a-dict")
	assert_eq(NetCodec.unpack_event(str_bytes), {}, "字符串负载回退空字典")

func test_vec_conversions() -> void:
	assert_eq(NetCodec.vec_to_arr(Vector2(3.0, -4.0)), [3.0, -4.0])
	assert_eq(NetCodec.arr_to_vec([3.0, -4.0]), Vector2(3.0, -4.0))
	assert_eq(NetCodec.arr_to_vec([]), Vector2.ZERO, "空数组回退零向量")
	assert_eq(NetCodec.arr_to_vec([1.0]), Vector2.ZERO, "不足 2 元素回退零向量")
