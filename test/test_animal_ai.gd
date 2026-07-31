extends SceneTree

var failures := 0
var physics_frame_count := 0
var main: Node
var world: VoxelWorld
var player: FirstPersonPlayer
var spawner: AnimalSpawner
var test_animal: SimpleAnimal
var initial_turn_count := 0


func _init() -> void:
	var scene := load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	physics_frame.connect(_on_physics_frame)


func _on_physics_frame() -> void:
	physics_frame_count += 1
	if physics_frame_count == 8:
		world = main.get_node("VoxelWorld") as VoxelWorld
		player = main.get_node("Player") as FirstPersonPlayer
		spawner = main.get_node("Animals") as AnimalSpawner
		_test_spawn_population()
		_test_scene_structure_and_models()
		_test_spawn_surfaces()
		_test_gravity_and_floor_collision()
		_prepare_flee_test()
	elif physics_frame_count == 12:
		_test_flee_activation()
		_prepare_flee_recovery()
	elif physics_frame_count == 16:
		_test_flee_recovery()
		_prepare_hazard_turn_test()
	elif physics_frame_count == 20:
		_test_hazard_turn()
		_test_deterministic_population()
		main.queue_free()
	elif physics_frame_count == 30:
		quit(failures)


func _test_spawn_population() -> void:
	_expect(spawner != null, "主场景创建Animals生成管理器")
	_expect(spawner.animals.size() >= AnimalSpawner.MIN_ANIMALS and spawner.animals.size() <= AnimalSpawner.MAX_ANIMALS, "世界生成后总计创建12–20只动物")
	_expect(spawner.pig_count >= AnimalSpawner.MIN_ANIMALS_PER_TYPE and spawner.pig_count <= AnimalSpawner.MAX_ANIMALS_PER_TYPE, "猪单独生成6–10只")
	_expect(spawner.chicken_count >= AnimalSpawner.MIN_ANIMALS_PER_TYPE and spawner.chicken_count <= AnimalSpawner.MAX_ANIMALS_PER_TYPE, "鸡单独生成6–10只")
	_expect(spawner.pig_count == spawner.requested_pig_count and spawner.chicken_count == spawner.requested_chicken_count, "每种动物实际数量与固定种子请求数量一致")
	_expect(spawner.animals.size() == spawner.requested_animal_count, "实际动物总数与猪鸡请求数量之和一致")
	_expect(spawner.pig_count + spawner.chicken_count == spawner.animals.size(), "猪鸡分类计数覆盖全部动物")
	var all_types_valid := true
	for animal: SimpleAnimal in spawner.animals:
		if animal.animal_type != SimpleAnimal.AnimalType.PIG and animal.animal_type != SimpleAnimal.AnimalType.CHICKEN:
			all_types_valid = false
	_expect(all_types_valid, "所有动物类型均为猪或鸡")


func _test_scene_structure_and_models() -> void:
	var all_have_structure := true
	var all_have_models := true
	for animal: SimpleAnimal in spawner.animals:
		if animal.body_collision == null or animal.visual_root == null or animal.obstacle_ray == null or animal.ground_ahead_ray == null:
			all_have_structure = false
		if animal.visual_root.get_child_count() < 7:
			all_have_models = false
	_expect(all_have_structure, "动物场景包含碰撞体、VisualRoot和双射线")
	_expect(all_have_models, "猪鸡均使用多个BoxMesh组合模型")


func _test_spawn_surfaces() -> void:
	var all_on_grass := true
	var all_avoid_spawn := true
	var all_have_clearance := true
	for index: int in range(spawner.animals.size()):
		var cell := spawner.spawn_cells[index]
		if world.get_block(cell + Vector3i.DOWN) != VoxelWorld.GRASS:
			all_on_grass = false
		if world.has_block(cell) or world.has_block(cell + Vector3i.UP):
			all_have_clearance = false
		var distance := Vector2(float(cell.x - VoxelWorld.SPAWN_POINT.x), float(cell.z - VoxelWorld.SPAWN_POINT.y)).length()
		if distance < AnimalSpawner.SPAWN_SAFE_RADIUS:
			all_avoid_spawn = false
	_expect(all_on_grass, "所有动物生成在草方块地表")
	_expect(all_have_clearance, "动物出生位置上方保留足够空间")
	_expect(all_avoid_spawn, "动物避开玩家出生安全区")


func _test_gravity_and_floor_collision() -> void:
	var all_above_surface := true
	var all_world_collision_only := true
	for animal: SimpleAnimal in spawner.animals:
		var surface_y := world.get_surface_height(floori(animal.global_position.x), floori(animal.global_position.z))
		if animal.global_position.y < float(surface_y + 1) - 0.05:
			all_above_surface = false
		if animal.collision_layer != SimpleAnimal.ANIMAL_COLLISION_LAYER or animal.collision_mask != SimpleAnimal.WORLD_COLLISION_LAYER:
			all_world_collision_only = false
	_expect(all_above_surface, "重力作用下动物不会落入地形内部")
	_expect(all_world_collision_only, "动物位于Layer 4并检测Layer 1世界碰撞")


func _prepare_flee_test() -> void:
	test_animal = spawner.animals[0]
	test_animal.global_position = Vector3(40.5, float(world.get_surface_height(40, 40) + 1) + 0.03, 40.5)
	player.global_position = test_animal.global_position + Vector3(1.5, 0.0, 0.0)
	test_animal.state = SimpleAnimal.State.WANDER
	test_animal.state_time_remaining = 4.0


func _test_flee_activation() -> void:
	_expect(test_animal.state == SimpleAnimal.State.FLEE, "玩家进入3米范围时动物切换到FLEE")
	var expected_away := test_animal.horizontal_direction_away_from_player()
	_expect(test_animal.movement_direction.dot(expected_away) > 0.95, "逃跑方向水平远离玩家")
	_expect(Vector2(test_animal.velocity.x, test_animal.velocity.z).length() >= SimpleAnimal.FLEE_SPEED * 0.9, "逃跑速度高于游荡速度")


func _prepare_flee_recovery() -> void:
	player.global_position = test_animal.global_position + Vector3(20.0, 0.0, 0.0)
	test_animal.state = SimpleAnimal.State.FLEE
	test_animal.state_time_remaining = 0.001


func _test_flee_recovery() -> void:
	_expect(test_animal.state == SimpleAnimal.State.WANDER, "逃跑计时结束后恢复WANDER")
	test_animal._enter_state(SimpleAnimal.State.IDLE)
	_expect(test_animal.state == SimpleAnimal.State.IDLE and test_animal.state_time_remaining > 0.0, "状态机支持偶尔进入IDLE停留")


func _prepare_hazard_turn_test() -> void:
	player.global_position = Vector3.ZERO
	var edge_x := VoxelWorld.WORLD_WIDTH / 2 - 1
	var edge_z := 0
	test_animal.global_position = Vector3(float(edge_x) + 0.5, float(world.get_surface_height(edge_x, edge_z) + 1) + 0.03, float(edge_z) + 0.5)
	test_animal.movement_direction = Vector3.RIGHT
	test_animal.state = SimpleAnimal.State.WANDER
	test_animal.state_time_remaining = 4.0
	test_animal.turn_cooldown_remaining = 0.0
	initial_turn_count = test_animal.navigation_turn_count


func _test_hazard_turn() -> void:
	_expect(test_animal.navigation_turn_count > initial_turn_count, "靠近世界边缘时动物自动转向")


func _test_deterministic_population() -> void:
	var isolated := AnimalSpawner.new()
	isolated.world = world
	isolated.player = player
	root.add_child(isolated)
	_expect(isolated.requested_animal_count == spawner.requested_animal_count, "固定种子生成一致动物总数")
	_expect(isolated.requested_pig_count == spawner.requested_pig_count and isolated.requested_chicken_count == spawner.requested_chicken_count, "固定种子生成一致的每种动物目标数量")
	_expect(isolated.spawn_cells == spawner.spawn_cells, "固定种子生成一致动物地表位置")
	_expect(isolated.pig_count == spawner.pig_count and isolated.chicken_count == spawner.chicken_count, "固定种子生成一致猪鸡分配")
	isolated.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
