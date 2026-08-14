class_name ObjectPool
extends RefCounted
## 通用对象池（M0 用于弹道/命中特效表现节点复用）
## 纯逻辑管理：不持有场景树引用；acquire 返回空闲实例或新建。
## 注意：池内节点实例由前端（表现层）提供/回收；本类只做簿记。

var _available: Array[Node] = []
var _in_use: Dictionary = {}  # Node -> true（去重簿记）
var _factory: Callable

## factory: Callable() -> Node，新建实例用；不传则用默认 Node.new()
func _init(factory: Callable = Callable()) -> void:
	_factory = factory

func size() -> int:
	return _available.size() + _in_use.size()

func available_count() -> int:
	return _available.size()

func in_use_count() -> int:
	return _in_use.size()

## 取一个实例：优先复用空闲，否则走 factory 新建
func acquire() -> Node:
	if not _available.is_empty():
		var node: Node = _available.pop_back()
		_in_use[node] = true
		return node
	var instance: Node
	if _factory.is_valid():
		instance = _factory.call()
	else:
		instance = Node.new()
	_in_use[instance] = true
	return instance

## 汇总池内全部实例（含空闲与在用；供调用方做整体释放/清理）
func collect_all() -> Array[Node]:
	var result: Array[Node] = []
	result.append_array(_available)
	for node in _in_use:
		result.append(node)
	return result

## 归还实例（重复归还忽略）
func release(node: Node) -> void:
	if node == null:
		return
	if not _in_use.erase(node):
		return
	_available.append(node)

## 清空（调用方需自行释放节点，M0 表现层使用）
func clear() -> void:
	_available.clear()
	_in_use.clear()
