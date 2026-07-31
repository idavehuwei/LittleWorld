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
	_expect(world.height_map.size() == 62500, "250×250 世界包含62500个地表高度样本")
	_expect(world.get_used_cells().size() > 62500, "自然世界包含分层地形与装饰方块")
	var northwest_height := world.get_surface_height(-125, -125)
	var southeast_height := world.get_surface_height(124, 124)
	_expect(world.get_block(Vector3i(-125, northwest_height, -125)) == VoxelWorld.GRASS, "世界西北边界地表是草方块")
	_expect(world.get_block(Vector3i(124, southeast_height, 124)) == VoxelWorld.GRASS, "世界东南边界地表是草方块")
	_expect(world.get_surface_height(125, 125) < VoxelWorld.MIN_SURFACE_HEIGHT, "世界边界之外没有地表高度")
	_expect(world.get_block(Vector3i(125, 0, 125)) == VoxelWorld.AIR, "世界边界之外是空气")
	var center_surface := world.get_surface_height(0, 0)
	var ground_center: Vector3 = world.to_global(world.map_to_local(Vector3i(0, center_surface, 0)))
	_expect(is_equal_approx(ground_center.y - 0.5, float(center_surface)), "地表方块底面与高度图一致")
	_expect(is_equal_approx(ground_center.y + 0.5, float(center_surface + 1)), "地表方块顶面与高度图一致")

	var test_cell := Vector3i(0, center_surface + 1, 0)
	_expect(world.place_block(test_cell, VoxelWorld.STONE), "可在地表上方空单元放置石头")
	_expect(world.get_block(test_cell) == VoxelWorld.STONE, "放置后方块类型正确")
	_expect(world.remove_block(test_cell), "可破坏已存在方块")
	_expect(world.get_block(test_cell) == VoxelWorld.AIR, "破坏后单元为空气")
	_expect(player.selected_block == VoxelWorld.GRASS, "默认选择草方块")
	var spawn_position := world.spawn_world_position()
	_expect(absf(player.position.x - spawn_position.x) < 0.01 and absf(player.position.z - spawn_position.z) < 0.01, "玩家从安全出生点水平坐标进入世界")
	_expect(player.position.y >= float(VoxelWorld.SPAWN_SURFACE_HEIGHT + 1) - 0.05, "玩家不会出生在地形内部")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
