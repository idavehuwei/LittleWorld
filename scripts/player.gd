class_name FirstPersonPlayer
extends CharacterBody3D

signal selection_changed(block_type: int)
signal inventory_visibility_changed(is_open: bool)

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
const HOTBAR_SIZE := PlayerInventory.HOTBAR_SIZE

var world: VoxelWorld
var inventory: PlayerInventory
var selected_block: int = VoxelWorld.GRASS
var head: Node3D
var camera: Camera3D
var body_collision: CollisionShape3D
var gravity: float = 18.0
var target_cell := Vector3i.ZERO
var target_normal := Vector3i.ZERO
var has_target := false
var inventory_open := false


func _ready() -> void:
	assert(inventory != null, "FirstPersonPlayer 需要在进入场景树前设置 inventory")
	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_LAYER
	floor_stop_on_slope = true
	floor_snap_length = 0.12
	_build_body()
	inventory.selection_changed.connect(_on_inventory_selection_changed)
	_sync_selected_item()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if not inventory_open:
		_try_jump()
		_apply_horizontal_movement(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, GROUND_ACCELERATION * delta)
	move_and_slide()
	if not inventory_open:
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
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_E:
			set_inventory_open(not inventory_open)
			return
		if inventory_open:
			return
		if key_event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
			select_slot(int(key_event.keycode - KEY_1))
	elif inventory_open:
		return
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		apply_look_delta(motion.relative)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			if mouse_button.button_index == MOUSE_BUTTON_LEFT:
				try_break_target_block()
			elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
				try_place_target_block()
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				cycle_slot(-1)
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				cycle_slot(1)


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


func try_break_target_block() -> bool:
	if inventory_open or not has_target or not world.has_block(target_cell):
		return false
	var block_type := world.get_block(target_cell)
	# 先确认整个掉落可入包，再修改世界，避免背包已满时方块凭空消失。
	if not inventory.can_add(block_type, 1):
		return false
	if not world.remove_block(target_cell):
		return false
	var remaining := inventory.add_item(block_type, 1)
	assert(remaining == 0, "预检查通过后方块应完整进入背包")
	update_target_block()
	return true


func try_place_target_block() -> bool:
	if inventory_open or not has_target or not is_valid_face_normal(target_normal):
		return false
	var selected_item := inventory.selected_item()
	if selected_item == PlayerInventory.EMPTY_ITEM or inventory.selected_amount() <= 0:
		return false
	var place_cell := target_cell + target_normal
	if world.has_block(place_cell) or cell_overlaps_player(place_cell):
		return false
	if not world.place_block(place_cell, selected_item):
		return false
	var consumed := inventory.remove_from_slot(inventory.selected_hotbar_index, 1)
	assert(consumed, "成功放置后必须能消耗已预检查的快捷栏物品")
	_sync_selected_item()
	update_target_block()
	return true


func is_valid_face_normal(normal: Vector3i) -> bool:
	return absi(normal.x) + absi(normal.y) + absi(normal.z) == 1


func cell_overlaps_player(cell: Vector3i) -> bool:
	var block_shape := BoxShape3D.new()
	# 略微缩小查询盒，允许方块与玩家脚底或身体边界刚好接触。
	block_shape.size = Vector3.ONE * (VoxelWorld.BLOCK_SIZE - 0.002)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = block_shape
	query.transform = Transform3D(Basis.IDENTITY, world.to_global(world.map_to_local(cell)))
	query.collision_mask = PLAYER_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var intersections: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 1)
	for intersection: Dictionary in intersections:
		if intersection.get("collider") == self:
			return true
	return false


func cycle_slot(step: int) -> void:
	inventory.cycle_hotbar(step)
	_sync_selected_item()


func select_slot(index: int) -> void:
	if inventory.select_hotbar(index):
		_sync_selected_item()


func set_inventory_open(is_open: bool) -> void:
	inventory_open = is_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_open else Input.MOUSE_MODE_CAPTURED
	if inventory_open:
		has_target = false
		world.set_highlight(target_cell, false)
	inventory_visibility_changed.emit(inventory_open)


func _on_inventory_selection_changed(_index: int) -> void:
	_sync_selected_item()


func _sync_selected_item() -> void:
	selected_block = inventory.selected_item()
	selection_changed.emit(selected_block)
