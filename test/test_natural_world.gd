extends SceneTree

var failures := 0
var frame := 0
var main: Node
var world: VoxelWorld


func _init() -> void:
	var scene := load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	frame += 1
	if frame == 5:
		world = main.get_node("VoxelWorld") as VoxelWorld
		_test_height_map()
		_test_layering()
		_test_spawn_plateau()
		_test_trees()
		_test_flowers()
		_test_determinism()
		main.queue_free()
	elif frame == 15:
		quit(failures)


func _test_height_map() -> void:
	var minimum := 999
	var maximum := -999
	var distinct := {}
	for height: int in world.height_map:
		minimum = mini(minimum, height)
		maximum = maxi(maximum, height)
		distinct[height] = true
	_expect(minimum >= VoxelWorld.MIN_SURFACE_HEIGHT, "地表最低高度不低于-3")
	_expect(maximum <= VoxelWorld.MAX_SURFACE_HEIGHT, "地表最高高度不高于+5")
	_expect(maximum > minimum and distinct.size() >= 4, "FastNoiseLite生成明显起伏的多级高度")
	_expect(world.terrain_noise is FastNoiseLite, "地形高度使用FastNoiseLite")
	_expect(world.terrain_noise.seed == VoxelWorld.TERRAIN_SEED, "地形噪声使用固定种子，可复现世界")


func _test_layering() -> void:
	var sample_points: Array[Vector2i] = [
		Vector2i(-90, -80), Vector2i(-40, 75), Vector2i(0, 5),
		Vector2i(55, -62), Vector2i(102, 98),
	]
	for point: Vector2i in sample_points:
		var surface_y := world.get_surface_height(point.x, point.y)
		_expect(world.get_block(Vector3i(point.x, surface_y, point.y)) == VoxelWorld.GRASS, "采样列地表为草方块: %s" % point)
		var dirt_count := 0
		for depth: int in range(1, 4):
			if world.get_block(Vector3i(point.x, surface_y - depth, point.y)) == VoxelWorld.DIRT:
				dirt_count += 1
		_expect(dirt_count >= 1 and dirt_count <= 3, "地表以下包含1–3层泥土: %s" % point)
		_expect(world.get_block(Vector3i(point.x, surface_y - dirt_count - 1, point.y)) == VoxelWorld.STONE, "泥土以下为石头: %s" % point)


func _test_spawn_plateau() -> void:
	var plateau_is_flat := true
	for z: int in range(VoxelWorld.SPAWN_POINT.y - 8, VoxelWorld.SPAWN_POINT.y + 9):
		for x: int in range(VoxelWorld.SPAWN_POINT.x - 8, VoxelWorld.SPAWN_POINT.x + 9):
			if world.get_surface_height(x, z) != VoxelWorld.SPAWN_SURFACE_HEIGHT:
				plateau_is_flat = false
	_expect(plateau_is_flat, "出生点8格范围保持平坦")
	var spawn_position := world.spawn_world_position()
	_expect(is_equal_approx(spawn_position.y, float(VoxelWorld.SPAWN_SURFACE_HEIGHT + 2)), "玩家出生在平坦地表上方")
	var decorations_avoid_spawn := true
	for origin: Vector3i in world.tree_origins:
		var distance := Vector2(float(origin.x - VoxelWorld.SPAWN_POINT.x), float(origin.z - VoxelWorld.SPAWN_POINT.y)).length()
		if distance <= VoxelWorld.DECORATION_SAFE_RADIUS:
			decorations_avoid_spawn = false
	for flower: Vector3i in world.flower_cells:
		var distance := Vector2(float(flower.x - VoxelWorld.SPAWN_POINT.x), float(flower.z - VoxelWorld.SPAWN_POINT.y)).length()
		if distance <= VoxelWorld.DECORATION_SAFE_RADIUS:
			decorations_avoid_spawn = false
	_expect(decorations_avoid_spawn, "树木和花朵避开出生安全区")


func _test_trees() -> void:
	_expect(world.generated_tree_count > 0, "自然世界至少生成一棵树")
	_expect(world.generated_tree_count == world.tree_origins.size(), "树木计数与记录一致")
	var all_trunks_valid := true
	var all_crowns_valid := true
	for origin: Vector3i in world.tree_origins:
		var trunk_height := 0
		var y := origin.y
		while world.get_block(Vector3i(origin.x, y, origin.z)) == VoxelWorld.LOG:
			trunk_height += 1
			y += 1
		if trunk_height < 3 or trunk_height > 5:
			all_trunks_valid = false
		var leaf_count := 0
		for leaf_y: int in range(origin.y + trunk_height - 1, origin.y + trunk_height + 3):
			for offset_z: int in range(-1, 2):
				for offset_x: int in range(-1, 2):
					if world.get_block(Vector3i(origin.x + offset_x, leaf_y, origin.z + offset_z)) == VoxelWorld.LEAVES:
						leaf_count += 1
		if leaf_count < 12:
			all_crowns_valid = false
	_expect(all_trunks_valid, "所有树干均由3–5个原木竖直组成")
	_expect(all_crowns_valid, "所有树顶均形成3×3或更大的树叶团")


func _test_flowers() -> void:
	_expect(world.generated_flower_count > 0, "自然世界至少生成一朵花")
	_expect(world.generated_flower_count == world.flower_cells.size(), "花朵计数与记录一致")
	var all_flowers_valid := true
	for cell: Vector3i in world.flower_cells:
		if world.get_block(cell) != VoxelWorld.FLOWER or world.get_block(cell + Vector3i.DOWN) != VoxelWorld.GRASS:
			all_flowers_valid = false
	_expect(all_flowers_valid, "所有花朵均位于草地表面")
	var flower_mesh := world.mesh_library.get_item_mesh(VoxelWorld.FLOWER)
	_expect(flower_mesh is ArrayMesh, "花朵使用十字平面ArrayMesh")
	_expect(world.mesh_library.get_item_shapes(VoxelWorld.FLOWER).is_empty(), "花朵无实体碰撞")


func _test_determinism() -> void:
	var isolated := VoxelWorld.new()
	root.add_child(isolated)
	isolated.build_initial_world()
	_expect(isolated.height_map == world.height_map, "相同种子生成完全一致的高度图")
	_expect(isolated.tree_origins == world.tree_origins, "相同种子生成一致的树木位置")
	_expect(isolated.flower_cells == world.flower_cells, "相同种子生成一致的花朵位置")
	isolated.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
