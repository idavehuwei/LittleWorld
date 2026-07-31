extends SceneTree

var failures := 0
var frame := 0
var main: Node
var world: VoxelWorld
var player: FirstPersonPlayer
var fall_start_y := 0.0
var landed := false
var jump_started := false
var jump_landed := false
var jump_peak_y := 0.0
var wall_test_started := false
var wall_start_x := 0.0


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
		_assert_structure()
		_start_fall_test()
	elif frame > 5 and frame < 150:
		_update_fall_test()
	elif frame == 150:
		_finish_fall_and_start_jump()
	elif frame > 150 and frame < 260:
		_update_jump_test()
	elif frame == 260:
		_finish_jump_and_start_wall_test()
	elif frame > 260 and frame < 320:
		_update_wall_test()
	elif frame == 320:
		_finish_wall_test()
		quit(failures)


func _assert_structure() -> void:
	_expect(player != null, "玩家节点是 FirstPersonPlayer")
	_expect(player is CharacterBody3D, "玩家根节点使用 CharacterBody3D")
	_expect(player.body_collision != null, "玩家拥有身体碰撞节点")
	_expect(player.head != null, "玩家拥有独立 Head 节点")
	_expect(player.camera != null, "玩家拥有第一人称摄像机")
	var capsule := player.body_collision.shape as CapsuleShape3D
	_expect(capsule != null, "玩家碰撞形状是胶囊体")
	_expect(is_equal_approx(capsule.height, FirstPersonPlayer.BODY_HEIGHT), "玩家身高为 1.8 米")
	_expect(is_equal_approx(player.head.position.y, FirstPersonPlayer.EYE_HEIGHT), "眼睛高度为 1.62 米")
	_expect(player.camera.get_parent() == player.head, "摄像机挂在 Head 下")
	_expect(player.collision_layer == FirstPersonPlayer.PLAYER_COLLISION_LAYER, "玩家位于碰撞层 2")
	_expect(player.collision_mask == FirstPersonPlayer.WORLD_COLLISION_LAYER, "玩家只检测世界层 1")
	player.apply_look_delta(Vector2(0.0, -100000.0))
	_expect(player.head.rotation.x <= FirstPersonPlayer.MAX_LOOK_ANGLE + 0.001, "向上看不会翻转")
	player.apply_look_delta(Vector2(0.0, 200000.0))
	_expect(player.head.rotation.x >= -FirstPersonPlayer.MAX_LOOK_ANGLE - 0.001, "向下看不会翻转")
	player.head.rotation.x = 0.0


func _start_fall_test() -> void:
	player.position = Vector3(0.0, 6.0, 0.0)
	player.velocity = Vector3.ZERO
	fall_start_y = player.position.y


func _update_fall_test() -> void:
	if player.is_on_floor():
		landed = true


func _finish_fall_and_start_jump() -> void:
	_expect(player.position.y < fall_start_y, "玩家受到重力后会下落")
	_expect(landed, "玩家能够落到方块表面")
	var expected_floor_y := float(world.get_surface_height(0, 0) + 1)
	_expect(absf(player.position.y - expected_floor_y) < 0.08, "落地时脚底位于高度图对应地表顶面")
	player.velocity.y = FirstPersonPlayer.JUMP_VELOCITY
	jump_started = true
	jump_peak_y = player.position.y


func _update_jump_test() -> void:
	if jump_started:
		jump_peak_y = maxf(jump_peak_y, player.position.y)
		var expected_floor_y := float(world.get_surface_height(0, 0) + 1)
		if player.is_on_floor() and player.position.y < expected_floor_y + 0.08:
			jump_landed = true


func _finish_jump_and_start_wall_test() -> void:
	_expect(jump_peak_y > 2.0, "玩家跳跃高度足以越过 1 米")
	_expect(jump_landed, "跳跃后玩家会重新落地")
	for y: int in range(1, 4):
		world.place_block(Vector3i(2, y, 0), VoxelWorld.STONE)
	player.position = Vector3(0.8, 1.0, 0.5)
	player.velocity = Vector3(6.0, 0.0, 0.0)
	wall_start_x = player.position.x
	wall_test_started = true


func _update_wall_test() -> void:
	if wall_test_started:
		player.velocity.x = 6.0


func _finish_wall_test() -> void:
	_expect(player.position.x > wall_start_x, "玩家向墙体方向发生移动")
	_expect(player.position.x < 1.67, "方块碰撞阻止玩家穿墙")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
