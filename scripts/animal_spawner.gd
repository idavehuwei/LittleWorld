class_name AnimalSpawner
extends Node3D

const MIN_ANIMALS_PER_TYPE := 6
const MAX_ANIMALS_PER_TYPE := 10
const MIN_ANIMALS := MIN_ANIMALS_PER_TYPE * 2
const MAX_ANIMALS := MAX_ANIMALS_PER_TYPE * 2
const SPAWN_SEED := 20260817
const SPAWN_SAFE_RADIUS := 14.0
const WORLD_MARGIN := 8
const MAX_PLACEMENT_ATTEMPTS := 500

var world: VoxelWorld
var player: FirstPersonPlayer
var animals: Array[SimpleAnimal] = []
var requested_animal_count := 0
var requested_pig_count := 0
var requested_chicken_count := 0
var pig_count := 0
var chicken_count := 0
var spawn_cells: Array[Vector3i] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	assert(world != null, "AnimalSpawner 需要在进入场景树前设置 world")
	assert(player != null, "AnimalSpawner 需要在进入场景树前设置 player")
	rng.seed = SPAWN_SEED
	spawn_animals()


func spawn_animals() -> void:
	clear_animals()
	rng.seed = SPAWN_SEED
	requested_pig_count = rng.randi_range(MIN_ANIMALS_PER_TYPE, MAX_ANIMALS_PER_TYPE)
	requested_chicken_count = rng.randi_range(MIN_ANIMALS_PER_TYPE, MAX_ANIMALS_PER_TYPE)
	requested_animal_count = requested_pig_count + requested_chicken_count
	_spawn_type(SimpleAnimal.AnimalType.PIG, requested_pig_count, SPAWN_SEED + 1103)
	_spawn_type(SimpleAnimal.AnimalType.CHICKEN, requested_chicken_count, SPAWN_SEED + 2207)
	if pig_count < MIN_ANIMALS_PER_TYPE or chicken_count < MIN_ANIMALS_PER_TYPE:
		push_error("动物安全生成点不足，当前猪%d只、鸡%d只" % [pig_count, chicken_count])


func _spawn_type(type: SimpleAnimal.AnimalType, target_count: int, seed_offset: int) -> void:
	var spawned_before := animals.size()
	var attempts := 0
	while animals.size() - spawned_before < target_count and attempts < MAX_PLACEMENT_ATTEMPTS:
		attempts += 1
		var x := rng.randi_range(-VoxelWorld.WORLD_WIDTH / 2 + WORLD_MARGIN, VoxelWorld.WORLD_WIDTH / 2 - WORLD_MARGIN - 1)
		var z := rng.randi_range(-VoxelWorld.WORLD_DEPTH / 2 + WORLD_MARGIN, VoxelWorld.WORLD_DEPTH / 2 - WORLD_MARGIN - 1)
		var cell := Vector3i(x, world.get_surface_height(x, z) + 1, z)
		if not is_spawn_cell_safe(cell):
			continue
		_spawn_one(cell, type, seed_offset + attempts * 97)


func clear_animals() -> void:
	for animal: SimpleAnimal in animals:
		if is_instance_valid(animal):
			animal.queue_free()
	animals.clear()
	spawn_cells.clear()
	requested_animal_count = 0
	requested_pig_count = 0
	requested_chicken_count = 0
	pig_count = 0
	chicken_count = 0


func is_spawn_cell_safe(cell: Vector3i) -> bool:
	if world.get_block(cell + Vector3i.DOWN) != VoxelWorld.GRASS:
		return false
	if world.has_block(cell) or world.has_block(cell + Vector3i.UP):
		return false
	var spawn_offset := Vector2(float(cell.x - VoxelWorld.SPAWN_POINT.x), float(cell.z - VoxelWorld.SPAWN_POINT.y))
	if spawn_offset.length() < SPAWN_SAFE_RADIUS:
		return false
	for existing: Vector3i in spawn_cells:
		if Vector2(float(existing.x - cell.x), float(existing.z - cell.z)).length() < 3.0:
			return false
	# 避免生成在一步就会跌落的尖峰或紧贴墙体的位置。
	var surface_y := cell.y - 1
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if absi(world.get_surface_height(cell.x + offset.x, cell.z + offset.y) - surface_y) > 1:
			return false
	return true


func _spawn_one(cell: Vector3i, type: SimpleAnimal.AnimalType, random_seed: int) -> void:
	var animal := SimpleAnimal.new()
	animal.name = "%s_%02d" % ["Pig" if type == SimpleAnimal.AnimalType.PIG else "Chicken", animals.size() + 1]
	animal.configure(world, player, type, random_seed)
	# CharacterBody3D 原点位于脚底，方块顶面是 surface_y + 1。
	animal.position = Vector3(float(cell.x) + 0.5, float(cell.y) + 0.03, float(cell.z) + 0.5)
	add_child(animal)
	animals.append(animal)
	spawn_cells.append(cell)
	if type == SimpleAnimal.AnimalType.PIG:
		pig_count += 1
	else:
		chicken_count += 1
