extends SceneTree

var failures := 0
var frame := 0
var main: Node
var world: VoxelWorld
var player: FirstPersonPlayer
var hud: GameHUD


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
		_assert_static_structure()
		_prepare_hit_test()
	elif frame == 8:
		_assert_hit_state()
		_prepare_miss_test()
	elif frame == 11:
		_assert_miss_state()
		quit(failures)


func _assert_static_structure() -> void:
	_expect(is_equal_approx(FirstPersonPlayer.REACH, 8.0), "摄像机射线长度为 8 米")
	_expect(hud.crosshair != null, "HUD 创建了十字准星")
	_expect(hud.crosshair.visible, "十字准星始终可见")
	_expect(hud.crosshair.get_child_count() == 8, "准星由白色线段和黑色描边组成")
	_expect(world.highlight != null, "世界创建了唯一高亮节点")
	_expect(world.highlight.mesh is ArrayMesh, "高亮使用 ArrayMesh 线框")
	var line_mesh := world.highlight.mesh as ArrayMesh
	_expect(line_mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_LINES, "高亮拓扑是线段")
	var arrays: Array = line_mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	_expect(vertices.size() == 24, "线框包含立方体 12 条边")


func _prepare_hit_test() -> void:
	player.position = Vector3(0.5, 1.0, 0.5)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.head.rotation.x = 0.0
	world.place_block(Vector3i(0, 2, -4), VoxelWorld.STONE)
	player.update_target_block()


func _assert_hit_state() -> void:
	player.update_target_block()
	_expect(player.has_target, "射线命中前方 8 米内方块")
	_expect(player.target_cell == Vector3i(0, 2, -4), "射线换算到正确方块坐标")
	_expect(player.target_normal == Vector3i(0, 0, 1), "射线记录正确命中面法线")
	_expect(world.highlight.visible, "命中后显示方块高亮")
	_expect(world.highlight.position.is_equal_approx(world.map_to_local(player.target_cell)), "高亮位于命中方块中心")


func _prepare_miss_test() -> void:
	player.head.rotation.x = deg_to_rad(80.0)
	player.update_target_block()


func _assert_miss_state() -> void:
	player.update_target_block()
	_expect(not player.has_target, "射线未命中时清除目标")
	_expect(not world.highlight.visible, "射线未命中时隐藏高亮")
	_expect(hud.crosshair.visible, "未命中时准星仍然可见")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
