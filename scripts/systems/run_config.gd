extends Node
## 本局运行配置（autoload；P0-7 随机种子 + P1 章节模式选择）
## - 默认 LEGACY：单章 6 波（沿用 Bulwark.WAVE_IDS），保证既有测试/回退路径不被破坏
## - 主菜单“开始游戏（单机）/进入战场”调用 prepare_arcade() 切到 ARCADE（4 章 3+1 波）
## - run_seed：每局随机种子（波次 + 商店共用）；未设置时保持 0（确定性回退，测试友好）

enum Mode {
	LEGACY = 0,
	ARCADE = 1,
	ENDLESS = 2,
}

const DEFAULT_MODE := Mode.LEGACY

var mode: Mode = DEFAULT_MODE
var run_seed: int = 0
var _seed_prepared := false

func is_arcade() -> bool:
	return mode == Mode.ARCADE

func is_endless() -> bool:
	return mode == Mode.ENDLESS

## 菜单进入本局前调用：生成新种子并设为街机模式（host/单机；client 无需）
func prepare_arcade() -> int:
	mode = Mode.ARCADE
	run_seed = randi()
	_seed_prepared = true
	return run_seed

## P2-17 无尽轮次：4 章循环、难度逐循环上抬（永不胜利）
func prepare_endless() -> int:
	mode = Mode.ENDLESS
	run_seed = randi()
	_seed_prepared = true
	return run_seed

## 菜单/回退到经典模式（M1 兼容；种子保留为已生成值以便复现）
func prepare_legacy() -> void:
	mode = Mode.LEGACY
	if not _seed_prepared:
		run_seed = randi()
		_seed_prepared = true

## 重置为默认（测试/场景重载安全）
func reset() -> void:
	mode = DEFAULT_MODE
	run_seed = 0
	_seed_prepared = false
