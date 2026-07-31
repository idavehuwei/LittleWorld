extends SceneTree

var failures := 0
var frame := 0
var main: Node
var world: VoxelWorld
var player: FirstPersonPlayer
var hud: GameHUD
var changed_events: Array[Array] = []


func _init() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	physics_frame.connect(_on_physics_frame)


func _on_physics_frame() -> void:
	frame += 1
	if frame == 5:
		world = main.get_node("VoxelWorld") as VoxelWorld
		player = main.get_node("Player") as FirstPersonPlayer
		hud = main.get_node("HUD") as GameHUD
		world.block_changed.connect(_on_block_changed)
		_test_block_types_and_slots()
		_test_no_target_rejection()
		_test_break_operation()
		_test_six_face_positions()
		_prepare_overlap_test()
	elif frame == 8:
		_test_player_overlap_rejection()
		_test_successful_placement()
		_test_world_change_signal()
		quit(failures)


func _test_block_types_and_slots() -> void:
	_expect(PlayerInventory.HOTBAR_SIZE == 9, "快捷栏包含九个槽位")
	_expect(player.inventory.get_item(4) == VoxelWorld.BRICKS, "第五格初始是砖块")
	_expect(VoxelWorld.BLOCK_NAMES[VoxelWorld.BRICKS] == "砖块", "世界注册了砖块类型")
	_expect(hud.slot_panels.size() == 9, "HUD 显示九个快捷栏槽位")

	player.select_slot(4)
	_expect(player.selected_block == VoxelWorld.BRICKS, "数字键槽位逻辑可选择砖块")
	player.select_slot(8)
	player.cycle_slot(1)
	_expect(player.selected_block == VoxelWorld.GRASS, "滚轮向下可从第九格循环到第一格")
	player.cycle_slot(-1)
	_expect(player.inventory.selected_hotbar_index == 8, "滚轮向上可从第一格循环到第九格")


func _test_no_target_rejection() -> void:
	player.has_target = false
	var before_count := world.get_used_cells().size()
	_expect(not player.try_break_target_block(), "没有高亮时不能破坏")
	_expect(not player.try_place_target_block(), "没有高亮时不能放置")
	_expect(world.get_used_cells().size() == before_count, "无目标操作不会修改世界")


func _test_break_operation() -> void:
	var break_cell := Vector3i(8, 2, 8)
	world.place_block(break_cell, VoxelWorld.STONE)
	player.has_target = true
	player.target_cell = break_cell
	player.target_normal = Vector3i.UP
	_expect(player.try_break_target_block(), "左键逻辑可破坏高亮方块")
	_expect(world.get_block(break_cell) == VoxelWorld.AIR, "破坏后目标坐标变为空气")


func _test_six_face_positions() -> void:
	var target := Vector3i(20, 4, 20)
	var normals: Array[Vector3i] = [
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.LEFT,
		Vector3i.RIGHT,
		Vector3i.FORWARD,
		Vector3i.BACK,
	]
	for normal: Vector3i in normals:
		var expected := target + normal
		_expect(expected - target == normal, "面法线 %s 正确映射相邻格" % normal)


func _prepare_overlap_test() -> void:
	player.position = Vector3(0.5, 1.0, 0.5)
	player.velocity = Vector3.ZERO
	player.has_target = true
	player.target_cell = Vector3i(0, 0, 0)
	player.target_normal = Vector3i.UP


func _test_player_overlap_rejection() -> void:
	# 直接瞄准玩家脚下地面格，上表面相邻单元会占据玩家身体。
	player.has_target = true
	player.target_cell = Vector3i(0, 0, 0)
	player.target_normal = Vector3i.UP
	_expect(player.cell_overlaps_player(Vector3i(0, 1, 0)), "物理形状查询检测到玩家重叠")
	_expect(not player.try_place_target_block(), "与玩家碰撞体重叠时放置失败")
	_expect(world.get_block(Vector3i(0, 1, 0)) == VoxelWorld.AIR, "失败放置不会写入世界")


func _test_successful_placement() -> void:
	player.select_slot(4)
	player.has_target = true
	player.target_cell = Vector3i(5, 0, 5)
	player.target_normal = Vector3i.UP
	_expect(player.try_place_target_block(), "右键逻辑可在命中面相邻格放置")
	_expect(world.get_block(Vector3i(5, 1, 5)) == VoxelWorld.BRICKS, "放置类型是玩家当前选择的砖块")
	player.has_target = true
	player.target_cell = Vector3i(5, 0, 5)
	player.target_normal = Vector3i.UP
	_expect(not player.try_place_target_block(), "目标相邻格已占用时拒绝重复放置")


func _test_world_change_signal() -> void:
	var found_break := false
	var found_place := false
	for event: Array in changed_events:
		if event[1] == VoxelWorld.STONE and event[2] == VoxelWorld.AIR:
			found_break = true
		if event[0] == Vector3i(5, 1, 5) and event[2] == VoxelWorld.BRICKS:
			found_place = true
	_expect(found_break, "破坏通过统一世界数据入口发出变化信号")
	_expect(found_place, "放置通过统一世界数据入口发出变化信号")


func _on_block_changed(cell: Vector3i, previous_type: int, new_type: int) -> void:
	changed_events.append([cell, previous_type, new_type])


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
