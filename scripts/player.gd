class_name FirstPersonPlayer
extends CharacterBody3D

signal selection_changed(block_type: int)

const WALK_SPEED := 6.0
const JUMP_VELOCITY := 7.0
const MOUSE_SENSITIVITY := 0.0022
const REACH := 7.0
const BLOCK_SLOTS := [VoxelWorld.GRASS, VoxelWorld.DIRT, VoxelWorld.STONE, VoxelWorld.PLANKS]

var world: VoxelWorld
var selected_block: int = VoxelWorld.GRASS
var camera: Camera3D
var gravity: float = 18.0
var target_cell := Vector3i.ZERO
var target_normal := Vector3i.ZERO
var has_target := false


func _ready() -> void:
	_build_body()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * WALK_SPEED
		velocity.z = direction.z * WALK_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * 8.0 * delta)
	move_and_slide()
	_update_target_block()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, -1.50, 1.50)
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


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.80
	collision.shape = capsule
	collision.position.y = 0.90
	add_child(collision)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.62
	camera.current = true
	add_child(camera)


func _update_target_block() -> void:
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * REACH)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [self])
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	has_target = not result.is_empty() and result.get("collider") == world
	if has_target:
		var hit_position: Vector3 = result["position"] as Vector3
		var hit_normal: Vector3 = result["normal"] as Vector3
		target_normal = Vector3i(roundi(hit_normal.x), roundi(hit_normal.y), roundi(hit_normal.z))
		target_cell = world.local_to_map(world.to_local(hit_position - hit_normal * 0.01))
	world.set_highlight(target_cell, has_target)


func _break_target_block() -> void:
	if has_target:
		world.remove_block(target_cell)
		_update_target_block()


func _place_next_to_target() -> void:
	if not has_target:
		return
	var place_cell := target_cell + target_normal
	if _cell_overlaps_player(place_cell):
		return
	world.place_block(place_cell, selected_block)
	_update_target_block()


func _cell_overlaps_player(cell: Vector3i) -> bool:
	var center: Vector3 = world.to_global(world.map_to_local(cell))
	var feet_y := global_position.y
	var head_y := feet_y + 1.80
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
