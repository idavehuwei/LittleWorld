class_name SimpleAnimal
extends CharacterBody3D

# 碰撞层约定：1=方块世界，2=玩家，4=动物。
const WORLD_COLLISION_LAYER := 1
const ANIMAL_COLLISION_LAYER := 4
const DETECTION_DISTANCE := 3.0
const WANDER_SPEED := 1.15
const FLEE_SPEED := 3.2
const GRAVITY := 18.0
const FLEE_DURATION := 2.4
const TURN_COOLDOWN := 0.35

enum State {
	IDLE,
	WANDER,
	FLEE,
}

enum AnimalType {
	PIG,
	CHICKEN,
}

var world: VoxelWorld
var player: FirstPersonPlayer
var animal_type := AnimalType.PIG
var state := State.IDLE
var movement_direction := Vector3.FORWARD
var state_time_remaining := 0.0
var turn_cooldown_remaining := 0.0
var navigation_turn_count := 0
var rng := RandomNumberGenerator.new()

var visual_root: Node3D
var body_collision: CollisionShape3D
var obstacle_ray: RayCast3D
var ground_ahead_ray: RayCast3D
var animation_time := 0.0


func configure(
	p_world: VoxelWorld,
	p_player: FirstPersonPlayer,
	p_animal_type: AnimalType,
	random_seed: int
) -> void:
	world = p_world
	player = p_player
	animal_type = p_animal_type
	rng.seed = random_seed


func _ready() -> void:
	assert(world != null, "SimpleAnimal 需要在进入场景树前设置 world")
	assert(player != null, "SimpleAnimal 需要在进入场景树前设置 player")
	collision_layer = ANIMAL_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_LAYER
	floor_stop_on_slope = true
	floor_snap_length = 0.16
	_build_collision()
	_build_navigation_rays()
	_build_visual_model()
	_choose_random_direction()
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_update_state(delta)
	_update_navigation(delta)
	_apply_horizontal_velocity()
	move_and_slide()
	_update_visual_animation(delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


func _update_state(delta: float) -> void:
	var away_from_player := horizontal_direction_away_from_player()
	var player_distance := horizontal_distance_to_player()
	if player_distance < DETECTION_DISTANCE and away_from_player != Vector3.ZERO:
		movement_direction = away_from_player
		if state != State.FLEE:
			_enter_state(State.FLEE)
		else:
			state_time_remaining = FLEE_DURATION
		return

	state_time_remaining -= delta
	if state == State.FLEE:
		if state_time_remaining <= 0.0:
			_enter_state(State.WANDER)
	elif state == State.IDLE:
		if state_time_remaining <= 0.0:
			_enter_state(State.WANDER)
	elif state == State.WANDER and state_time_remaining <= 0.0:
		if rng.randf() < 0.58:
			_enter_state(State.IDLE)
		else:
			_choose_random_direction()
			state_time_remaining = rng.randf_range(2.2, 5.0)


func _enter_state(next_state: State) -> void:
	state = next_state
	if state == State.IDLE:
		state_time_remaining = rng.randf_range(0.8, 2.4)
	elif state == State.WANDER:
		state_time_remaining = rng.randf_range(2.4, 5.5)
		_choose_random_direction()
	else:
		state_time_remaining = FLEE_DURATION


func _update_navigation(delta: float) -> void:
	turn_cooldown_remaining = maxf(0.0, turn_cooldown_remaining - delta)
	if state == State.IDLE or turn_cooldown_remaining > 0.0:
		return
	_face_movement_direction()
	obstacle_ray.force_raycast_update()
	ground_ahead_ray.force_raycast_update()
	if obstacle_ray.is_colliding() or not ground_ahead_ray.is_colliding() or _is_near_world_edge():
		_turn_away_from_hazard()


func _apply_horizontal_velocity() -> void:
	if state == State.IDLE:
		velocity.x = move_toward(velocity.x, 0.0, 0.22)
		velocity.z = move_toward(velocity.z, 0.0, 0.22)
		return
	var speed := FLEE_SPEED if state == State.FLEE else WANDER_SPEED
	velocity.x = movement_direction.x * speed
	velocity.z = movement_direction.z * speed
	_face_movement_direction()


func horizontal_distance_to_player() -> float:
	if not is_instance_valid(player):
		return INF
	var offset := player.global_position - global_position
	offset.y = 0.0
	return offset.length()


func horizontal_direction_away_from_player() -> Vector3:
	if not is_instance_valid(player):
		return Vector3.ZERO
	var direction := global_position - player.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return movement_direction
	return direction.normalized()


func state_name() -> String:
	return State.keys()[state] as String


func animal_type_name() -> String:
	return "猪" if animal_type == AnimalType.PIG else "鸡"


func hazard_ahead() -> bool:
	obstacle_ray.force_raycast_update()
	ground_ahead_ray.force_raycast_update()
	return obstacle_ray.is_colliding() or not ground_ahead_ray.is_colliding() or _is_near_world_edge()


func _turn_away_from_hazard() -> void:
	var turn_angle := rng.randf_range(0.75, 1.45)
	if rng.randf() < 0.5:
		turn_angle = -turn_angle
	movement_direction = movement_direction.rotated(Vector3.UP, turn_angle).normalized()
	turn_cooldown_remaining = TURN_COOLDOWN
	navigation_turn_count += 1
	_face_movement_direction()


func _choose_random_direction() -> void:
	var angle := rng.randf_range(-PI, PI)
	movement_direction = Vector3(sin(angle), 0.0, cos(angle)).normalized()
	_face_movement_direction()


func _face_movement_direction() -> void:
	if movement_direction.length_squared() < 0.0001:
		return
	rotation.y = atan2(-movement_direction.x, -movement_direction.z)


func _is_near_world_edge() -> bool:
	var limit_x := float(VoxelWorld.WORLD_WIDTH) * 0.5 - 2.0
	var limit_z := float(VoxelWorld.WORLD_DEPTH) * 0.5 - 2.0
	return absf(global_position.x) >= limit_x or absf(global_position.z) >= limit_z


func _build_collision() -> void:
	body_collision = CollisionShape3D.new()
	body_collision.name = "BodyCollision"
	var shape := BoxShape3D.new()
	if animal_type == AnimalType.PIG:
		shape.size = Vector3(0.9, 0.82, 1.15)
		body_collision.position.y = 0.41
	else:
		shape.size = Vector3(0.55, 0.72, 0.55)
		body_collision.position.y = 0.36
	body_collision.shape = shape
	add_child(body_collision)


func _build_navigation_rays() -> void:
	obstacle_ray = RayCast3D.new()
	obstacle_ray.name = "ObstacleRay"
	obstacle_ray.position = Vector3(0.0, 0.45, 0.0)
	obstacle_ray.target_position = Vector3(0.0, 0.0, -0.95)
	obstacle_ray.collision_mask = WORLD_COLLISION_LAYER
	obstacle_ray.exclude_parent = true
	obstacle_ray.enabled = true
	add_child(obstacle_ray)

	ground_ahead_ray = RayCast3D.new()
	ground_ahead_ray.name = "GroundAheadRay"
	ground_ahead_ray.position = Vector3(0.0, 0.55, -0.72)
	ground_ahead_ray.target_position = Vector3(0.0, -1.65, 0.0)
	ground_ahead_ray.collision_mask = WORLD_COLLISION_LAYER
	ground_ahead_ray.exclude_parent = true
	ground_ahead_ray.enabled = true
	add_child(ground_ahead_ray)


func _build_visual_model() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	if animal_type == AnimalType.PIG:
		_build_pig_model()
	else:
		_build_chicken_model()


func _build_pig_model() -> void:
	var pink := _material(Color("e79aa0"))
	var light_pink := _material(Color("f2b4b8"))
	var dark_pink := _material(Color("bd6f78"))
	var black := _material(Color("25252b"))
	_add_box_part("Body", Vector3(0.82, 0.58, 1.05), Vector3(0.0, 0.55, 0.0), pink)
	_add_box_part("Head", Vector3(0.66, 0.62, 0.58), Vector3(0.0, 0.67, -0.72), light_pink)
	_add_box_part("Snout", Vector3(0.42, 0.27, 0.18), Vector3(0.0, 0.59, -1.08), dark_pink)
	_add_box_part("EyeLeft", Vector3(0.08, 0.08, 0.04), Vector3(-0.18, 0.79, -1.025), black)
	_add_box_part("EyeRight", Vector3(0.08, 0.08, 0.04), Vector3(0.18, 0.79, -1.025), black)
	for leg_data: Array in [
		["LegFL", Vector3(-0.27, 0.2, -0.3)],
		["LegFR", Vector3(0.27, 0.2, -0.3)],
		["LegBL", Vector3(-0.27, 0.2, 0.3)],
		["LegBR", Vector3(0.27, 0.2, 0.3)],
	]:
		_add_box_part(leg_data[0] as String, Vector3(0.2, 0.4, 0.2), leg_data[1] as Vector3, dark_pink)


func _build_chicken_model() -> void:
	var white := _material(Color("f1eee4"))
	var cream := _material(Color("fff5cf"))
	var yellow := _material(Color("e8ba42"))
	var red := _material(Color("cf4b45"))
	var black := _material(Color("25252b"))
	_add_box_part("Body", Vector3(0.58, 0.62, 0.58), Vector3(0.0, 0.48, 0.0), white)
	_add_box_part("Head", Vector3(0.46, 0.46, 0.44), Vector3(0.0, 0.82, -0.38), cream)
	_add_box_part("Beak", Vector3(0.24, 0.14, 0.22), Vector3(0.0, 0.78, -0.69), yellow)
	_add_box_part("Comb", Vector3(0.17, 0.18, 0.16), Vector3(0.0, 1.12, -0.36), red)
	_add_box_part("EyeLeft", Vector3(0.06, 0.06, 0.04), Vector3(-0.13, 0.9, -0.595), black)
	_add_box_part("EyeRight", Vector3(0.06, 0.06, 0.04), Vector3(0.13, 0.9, -0.595), black)
	_add_box_part("LegLeft", Vector3(0.09, 0.34, 0.09), Vector3(-0.16, 0.17, 0.0), yellow)
	_add_box_part("LegRight", Vector3(0.09, 0.34, 0.09), Vector3(0.16, 0.17, 0.0), yellow)


func _add_box_part(part_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = part_name
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = position
	visual_root.add_child(mesh_instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func _update_visual_animation(delta: float) -> void:
	animation_time += delta
	if state == State.IDLE:
		visual_root.position.y = sin(animation_time * 1.8) * 0.012
		visual_root.scale = Vector3.ONE
		return
	var speed_factor := 10.0 if state == State.FLEE else 6.0
	var bounce := absf(sin(animation_time * speed_factor))
	visual_root.position.y = bounce * (0.06 if state == State.FLEE else 0.035)
	var squash := 1.0 - bounce * 0.035
	visual_root.scale = Vector3(1.0 + bounce * 0.02, squash, 1.0 + bounce * 0.02)
