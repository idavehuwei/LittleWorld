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
	_expect(world.get_used_cells().size() == 2500, "50×50 平地包含 2500 个方块")

	var test_cell := Vector3i(0, 1, 0)
	_expect(world.place_block(test_cell, VoxelWorld.STONE), "可在空单元放置石头")
	_expect(world.get_cell_item(test_cell) == VoxelWorld.STONE, "放置后方块类型正确")
	_expect(world.remove_block(test_cell), "可破坏已存在方块")
	_expect(world.get_cell_item(test_cell) == VoxelWorld.AIR, "破坏后单元为空气")
	_expect(player.selected_block == VoxelWorld.GRASS, "默认选择草方块")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
