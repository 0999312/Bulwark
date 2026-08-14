extends GutTest
## 对象池测试（弹道表现节点复用）
## 测试专用：after_each 释放池内节点（对象池只做簿记，不负责释放）

var pool: ObjectPool

func before_each() -> void:
	pool = ObjectPool.new(func() -> Node: return Node.new())

func after_each() -> void:
	for node: Node in pool.collect_all():
		if is_instance_valid(node):
			node.free()

func test_acquire_creates_and_release_reuses() -> void:
	var a := pool.acquire()
	var b := pool.acquire()
	assert_ne(a, b, "未回收时应新建实例")
	assert_eq(pool.in_use_count(), 2)
	pool.release(a)
	assert_eq(pool.available_count(), 1)
	var c := pool.acquire()
	assert_eq(c, a, "应复用空闲实例")

func test_double_release_ignored() -> void:
	var a := pool.acquire()
	pool.release(a)
	pool.release(a)
	pool.release(null)
	assert_eq(pool.available_count(), 1)

func test_clear_resets_bookkeeping() -> void:
	var a := pool.acquire()
	var b := pool.acquire()
	pool.clear()
	assert_eq(pool.size(), 0)
	# clear 后池不再记账，测试手动释放节点
	a.free()
	b.free()

func test_default_factory_creates_nodes() -> void:
	var node := pool.acquire()
	assert_not_null(node)
	assert_true(node is Node)

func test_collect_all_returns_every_instance() -> void:
	var a := pool.acquire()
	var b := pool.acquire()
	pool.release(a)
	var all := pool.collect_all()
	assert_eq(all.size(), 2)
	assert_true(all.has(a))
	assert_true(all.has(b))
