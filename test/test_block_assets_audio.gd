extends SceneTree

var failures := 0
var frame := 0
var main: Node
var world: VoxelWorld
var audio_manager: BlockAudioManager
var triggered_events: Array[Array] = []


func _init() -> void:
	var scene := load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	frame += 1
	if frame == 5:
		world = main.get_node("VoxelWorld") as VoxelWorld
		audio_manager = main.get_node("BlockAudioManager") as BlockAudioManager
		audio_manager.sfx_triggered.connect(_on_sfx_triggered)
		_test_texture_resources()
		_test_audio_setup()
		_trigger_world_changes()
	elif frame == 8:
		_test_trigger_mapping()
		for player: AudioStreamPlayer3D in audio_manager.break_players + audio_manager.place_players:
			player.stop()
		main.queue_free()
	elif frame == 12:
		triggered_events.clear()
		world = null
		audio_manager = null
		main = null
	elif frame == 30:
		quit(failures)


func _test_texture_resources() -> void:
	_expect(VoxelWorld.BLOCK_TEXTURE_PATHS.size() == 8, "地形、建筑与自然装饰方块均注册独立纹理")
	for block_id: int in VoxelWorld.BLOCK_TEXTURE_PATHS:
		var texture_path: String = VoxelWorld.BLOCK_TEXTURE_PATHS[block_id] as String
		var texture := load(texture_path) as Texture2D
		_expect(texture != null, "纹理可加载: %s" % texture_path)
		if texture != null:
			_expect(texture.get_width() == 16 and texture.get_height() == 16, "纹理尺寸为 16x16: %s" % texture_path)

	var library := world.mesh_library
	for block_id: int in VoxelWorld.BLOCK_NAMES:
		var mesh := library.get_item_mesh(block_id)
		var material: StandardMaterial3D
		if mesh is BoxMesh:
			material = (mesh as BoxMesh).material as StandardMaterial3D
		elif mesh is ArrayMesh:
			material = (mesh as ArrayMesh).surface_get_material(0) as StandardMaterial3D
		_expect(material != null and material.albedo_texture != null, "方块 %d 使用贴图材质" % block_id)
		_expect(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "方块 %d 使用最近邻过滤" % block_id)


func _test_audio_setup() -> void:
	_expect(audio_manager.break_players.size() == BlockAudioManager.POOL_SIZE, "破坏音效池大小固定")
	_expect(audio_manager.place_players.size() == BlockAudioManager.POOL_SIZE, "放置音效池大小固定")
	_expect(BlockAudioManager.BREAK_STREAM != null, "破坏 WAV 可加载")
	_expect(BlockAudioManager.PLACE_STREAM != null, "放置 WAV 可加载")
	_expect(BlockAudioManager.BREAK_STREAM != BlockAudioManager.PLACE_STREAM, "破坏与放置使用不同音频资源")
	for player: AudioStreamPlayer3D in audio_manager.break_players + audio_manager.place_players:
		_expect(player.max_distance == BlockAudioManager.MAX_DISTANCE, "3D 音效具有有限传播距离")


func _trigger_world_changes() -> void:
	var cell := Vector3i(12, 3, 12)
	world.place_block(cell, VoxelWorld.PLANKS)
	world.remove_block(cell)
	# 无变化写入不应发出信号，也不应播放音效。
	world.set_block(cell, VoxelWorld.AIR)


func _test_trigger_mapping() -> void:
	_expect(triggered_events.size() == 2, "一次成功放置和一次成功破坏只触发两个音效")
	if triggered_events.size() >= 2:
		_expect(triggered_events[0][0] == &"place", "空气变方块映射为放置音效")
		_expect(triggered_events[1][0] == &"break", "方块变空气映射为破坏音效")
		_expect(triggered_events[0][1] == Vector3i(12, 3, 12), "放置音效位于变化单元")
		_expect(triggered_events[1][1] == Vector3i(12, 3, 12), "破坏音效位于变化单元")
	_expect(audio_manager.last_event_kind == &"break", "管理器记录最后一次破坏事件")


func _on_sfx_triggered(kind: StringName, cell: Vector3i) -> void:
	triggered_events.append([kind, cell])


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
