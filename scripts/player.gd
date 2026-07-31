class_name FirstPersonPlayer
extends CharacterBody3D

signal selection_changed(block_type: int)

const BODY_HEIGHT := 1.80
const BODY_RADIUS := 0.35
const EYE_HEIGHT := 1.62
const WALK_SPEED := 6.0
const GROUND_ACCELERATION := 28.0
const AIR_ACCELERATION := 8.0
const JUMP_VELOCITY := 7.0
const MOUSE_SENSITIVITY := 0.0022
const MAX_LOOK_ANGLE := deg_to_rad(89.0)
const REACH := 8.0
const WORLD_COLLISION_LAYER := 1
const PLAYER_COLLISION_LAYER := 2
const BLOCK_SLOTS := [VoxelWorld.GRASS, VoxelWorld.DIRT, VoxelWorld.STONE, VoxelWorld.PLANKS]

var world: VoxelWorld
var selected_block: int = VoxelWorld.GRASS
var head: Node3D
var camera: Camera3D
var body_collision: CollisionShape3D
var gravity: float = 18.0
var target_cell := Vector3i.ZERO
var target_normal := Vector3i.ZERO
var has_target := false


func _ready() -> void:
	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_LAYER
	floor_stop_on_slope = true
	floor_snap_length = 0.12
	_build_body()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_try_jump()
	_apply_horizontal_movement(delta)
	move_and_slide()
	update_target_block()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta


func _try_jump() -> void:
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY


func _apply_horizontal_movement(delta: float) -> void:
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var target_velocity := direction * WALK_SPEED
	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		apply_look_delta(motion.relative)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			if mouse_button.button_index == MOUSE_BUTTON_LEFT:
				_break_target_block()
			elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
				_place_next_to_target()
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_slot(-1)
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_slot(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key_event.keycode >= KEY_1 and key_event.keycode <= KEY_4:
			_select_slot(int(key_event.keycode - KEY_1))


func apply_look_delta(relative: Vector2) -> void:
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	head.rotation.x = clampf(head.rotation.x - relative.y * MOUSE_SENSITIVITY, -MAX_LOOK_ANGLE, MAX_LOOK_ANGLE)


func _build_body() -> void:
	body_collision = CollisionShape3D.new()
	body_collision.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	body_collision.shape = capsule
	# CharacterBody3D 的原点约定在脚底，胶囊中心上移半个身高。
	body_collision.position.y = BODY_HEIGHT * 0.5
	add_child(body_collision)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	head.add_child(camera)


func update_target_block() -> void:
	var ray_origin := camera.global_position
	var ray_direction := -camera.global_transform.basis.z.normalized()
	var ray_end := ray_origin + ray_direction * REACH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, WORLD_COLLISION_LAYER, [self])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	has_target = not result.is_empty() and result.get("collider") == world
	if has_target:
		var hit_position: Vector3 = result["position"] as Vector3
		var hit_normal: Vector3 = result["normal"] as Vector3
		target_normal = Vector3i(roundi(hit_normal.x), roundi(hit_normal.y), roundi(hit_normal.z))
		# 沿法线向命中方块内部偏移，避免落在两个网格单元的边界上。
		target_cell = world.local_to_map(world.to_local(hit_position - hit_normal * 0.01))
	world.set_highlight(target_cell, has_target)


func _break_target_block() -> void:
	if has_target:
		world.remove_block(target_cell)
		update_target_block()


func _place_next_to_target() -> void:
	if not has_target:
		return
	var place_cell := target_cell + target_normal
	if _cell_overlaps_player(place_cell):
		return
	world.place_block(place_cell, selected_block)
	update_target_block()


func _cell_overlaps_player(cell: Vector3i) -> bool:
	var center: Vector3 = world.to_global(world.map_to_local(cell))
	var feet_y := global_position.y
	var head_y := feet_y + BODY_HEIGHT
	var horizontal_overlap := absf(center.x - global_position.x) < 0.86 and absf(center.z - global_position.z) < 0.86
	var vertical_overlap := center.y + 0.5 > feet_y and center.y - 0.5 < head_y
	return horizontal_overlap and vertical_overlap


func _cycle_slot(step: int) -> void:
	var current_index := BLOCK_SLOTS.find(selected_block)
	_select_slot(posmod(current_index + step, BLOCK_SLOTS.size()))


func _select_slot(index: int) -> void:
	if index < 0 or index >= BLOCK_SLOTS.size():
		return
	selected_block = BLOCK_SLOTS[index]
	selection_changed.emit(selected_block)
