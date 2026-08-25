extends GutTest
## P1-10：HighScoreStore 本地 Top10（user://json 带版本号，写失败降级）

const TEST_PATH := "user://test_highscore_p1.json"

func before_each() -> void:
	HighScoreStore.reset(TEST_PATH)

func after_each() -> void:
	HighScoreStore.reset(TEST_PATH)

func test_save_entry_returns_rank_and_sorted() -> void:
	HighScoreStore.save_entry({"score": 100, "combo": 5, "kills": 1, "time": 10.0, "name": ""}, TEST_PATH)
	var rank := HighScoreStore.save_entry({"score": 200, "combo": 8, "kills": 2, "time": 20.0, "name": ""}, TEST_PATH)
	assert_eq(rank, 1, "更高分排第一")
	var top := HighScoreStore.load_top(TEST_PATH)
	assert_eq(top.size(), 2)
	assert_eq(int(top[0].get("score", 0)), 200)
	assert_eq(int(top[1].get("score", 0)), 100)

func test_top10_capped() -> void:
	for i in range(12):
		HighScoreStore.save_entry({"score": 100 + i, "combo": 1, "kills": 1, "time": 1.0, "name": ""}, TEST_PATH)
	var top := HighScoreStore.load_top(TEST_PATH)
	assert_eq(top.size(), HighScoreStore.MAX_ENTRIES, "只保留 Top10")

func test_invalid_file_falls_back_empty() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	var top := HighScoreStore.load_top(TEST_PATH)
	assert_eq(top.size(), 0, "坏文件降级为空榜")

func test_zero_score_not_written() -> void:
	var rank := HighScoreStore.save_entry({"score": 0, "combo": 0, "kills": 0, "time": 0.0, "name": ""}, TEST_PATH)
	assert_eq(rank, -1)
	assert_eq(HighScoreStore.load_top(TEST_PATH).size(), 0)
