extends SceneTree

var failures := 0
var frame := 0
var main: Node


func _init() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	frame += 1
	if frame == 5:
		_run_assertions()
		quit(failures)


func _run_assertions() -> void:
	var world := main.get_node("VoxelWorld") as VoxelWorld
	var player := main.get_node("Player") as FirstPersonPlayer
	_expect(world != null, "世界节点已创建")
	_expect(player != null, "玩家节点已创建")
	_expect(world.get_used_cells().size() == 62500, "250×250 平地包含 62500 个方块")
	_expect(world.get_block(Vector3i(-125, 0, -125)) == VoxelWorld.GRASS, "世界西北边界是草方块")
	_expect(world.get_block(Vector3i(124, 0, 124)) == VoxelWorld.GRASS, "世界东南边界是草方块")
	_expect(world.get_block(Vector3i(125, 0, 125)) == VoxelWorld.AIR, "世界边界之外是空气")
	var ground_center: Vector3 = world.to_global(world.map_to_local(Vector3i.ZERO))
	_expect(is_equal_approx(ground_center.y - 0.5, 0.0), "草方块底面位于 y=0")
	_expect(is_equal_approx(ground_center.y + 0.5, 1.0), "草方块顶面位于 y=1")

	var test_cell := Vector3i(0, 1, 0)
	_expect(world.place_block(test_cell, VoxelWorld.STONE), "可在空单元放置石头")
	_expect(world.get_block(test_cell) == VoxelWorld.STONE, "放置后方块类型正确")
	_expect(world.remove_block(test_cell), "可破坏已存在方块")
	_expect(world.get_block(test_cell) == VoxelWorld.AIR, "破坏后单元为空气")
	_expect(player.selected_block == VoxelWorld.GRASS, "默认选择草方块")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
