extends SceneTree

var failures := 0
var frame := 0
var main: Node
var world: VoxelWorld
var player: FirstPersonPlayer
var block_audio: BlockAudioManager
var audio_system: GameAudioSystem
var hud: GameHUD


func _init() -> void:
	var scene := load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	frame += 1
	if frame == 6:
		world = main.get_node("VoxelWorld") as VoxelWorld
		player = main.get_node("Player") as FirstPersonPlayer
		block_audio = main.get_node("BlockAudioManager") as BlockAudioManager
		audio_system = main.get_node("GameAudioSystem") as GameAudioSystem
		hud = main.get_node("HUD") as GameHUD
		_test_bus_layout()
		_test_ambient_and_music()
		_test_block_sound_groups()
		_test_footstep_mapping()
		_test_volume_controls()
	elif frame == 10:
		_test_runtime_block_switching()
		main.queue_free()
	elif frame == 24:
		quit(failures)


func _test_bus_layout() -> void:
	var music_index := AudioServer.get_bus_index(GameAudioSystem.MUSIC_BUS)
	var sfx_index := AudioServer.get_bus_index(GameAudioSystem.SFX_BUS)
	var ambient_index := AudioServer.get_bus_index(GameAudioSystem.AMBIENT_BUS)
	_expect(music_index >= 0 and sfx_index >= 0 and ambient_index >= 0, "创建Music、SFX和Ambient音频总线")
	_expect(AudioServer.get_bus_send(music_index) == &"Master", "Music总线发送到Master")
	_expect(AudioServer.get_bus_send(sfx_index) == &"Master", "SFX总线发送到Master")
	_expect(AudioServer.get_bus_send(ambient_index) == GameAudioSystem.SFX_BUS, "Ambient子总线受SFX音量统一控制")


func _test_ambient_and_music() -> void:
	_expect(audio_system.music_player.stream != null, "背景音乐资源可加载")
	_expect(audio_system.wind_player.stream != null, "循环风声资源可加载")
	_expect(audio_system.bird_player.stream != null, "偶发鸟鸣资源可加载")
	_expect(audio_system.music_player.bus == GameAudioSystem.MUSIC_BUS, "背景音乐挂载Music总线")
	_expect(audio_system.wind_player.bus == GameAudioSystem.AMBIENT_BUS and audio_system.bird_player.bus == GameAudioSystem.AMBIENT_BUS, "环境音挂载Ambient总线")
	_expect((audio_system.music_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "背景音乐设置为循环播放")
	_expect((audio_system.wind_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "风声设置为循环播放")
	_expect(audio_system.bird_time_remaining >= GameAudioSystem.BIRD_MIN_DELAY, "鸟鸣使用低频随机计时")


func _test_block_sound_groups() -> void:
	_expect(BlockAudioManager.sound_group_for_block(VoxelWorld.GRASS) == &"grass", "草方块映射草地音色")
	_expect(BlockAudioManager.sound_group_for_block(VoxelWorld.STONE) == &"stone", "石头映射石质音色")
	_expect(BlockAudioManager.sound_group_for_block(VoxelWorld.BRICKS) == &"stone", "砖块复用石质音色")
	_expect(BlockAudioManager.sound_group_for_block(VoxelWorld.LOG) == &"wood", "原木映射木质音色")
	_expect(BlockAudioManager.sound_group_for_block(VoxelWorld.PLANKS) == &"wood", "木板映射木质音色")
	_expect(BlockAudioManager.BREAK_STREAMS.size() == 3 and BlockAudioManager.PLACE_STREAMS.size() == 3, "破坏和放置均提供草石木三组独立音效")
	for audio_player: AudioStreamPlayer3D in block_audio.break_players + block_audio.place_players:
		_expect(audio_player.bus == GameAudioSystem.SFX_BUS, "方块3D音效挂载SFX总线")


func _test_footstep_mapping() -> void:
	var footsteps := audio_system.footstep_controller
	_expect(footsteps != null and footsteps.get_parent() == player, "脚步控制器挂在玩家节点下")
	_expect(FootstepController.surface_group_for_block(VoxelWorld.GRASS) == &"grass", "草地脚步使用草音色")
	_expect(FootstepController.surface_group_for_block(VoxelWorld.STONE) == &"stone", "石头脚步使用石质音色")
	_expect(FootstepController.surface_group_for_block(VoxelWorld.LOG) == &"wood", "原木脚步使用木质音色")
	_expect(footsteps.audio_player.bus == GameAudioSystem.SFX_BUS, "脚步声挂载SFX总线")
	footsteps.play_footstep()
	_expect(footsteps.step_count == 1 and footsteps.audio_player.stream != null, "脚步控制器可按脚下方块播放一次音效")
	var slow_distance := lerpf(FootstepController.MAX_STEP_DISTANCE, FootstepController.MIN_STEP_DISTANCE, 0.25)
	var fast_distance := lerpf(FootstepController.MAX_STEP_DISTANCE, FootstepController.MIN_STEP_DISTANCE, 1.0)
	_expect(fast_distance < slow_distance, "移动越快触发脚步所需距离越短")


func _test_volume_controls() -> void:
	_expect(hud.master_volume_slider != null and hud.music_volume_slider != null and hud.sfx_volume_slider != null, "背包设置包含三档音量滑块")
	hud.master_volume_slider.value = 64.0
	hud.music_volume_slider.value = 27.0
	hud.sfx_volume_slider.value = 71.0
	_expect(absf(audio_system.get_master_volume() - 0.64) < 0.02, "主音量滑块控制Master总线")
	_expect(absf(audio_system.get_music_volume() - 0.27) < 0.02, "音乐音量滑块控制Music总线")
	_expect(absf(audio_system.get_sfx_volume() - 0.71) < 0.02, "音效音量滑块控制SFX总线")


func _test_runtime_block_switching() -> void:
	var grass_cell := Vector3i(31, 7, 31)
	world.place_block(grass_cell, VoxelWorld.GRASS)
	_expect(block_audio.last_event_group == &"grass", "放置草方块动态选择草地音效")
	world.remove_block(grass_cell)
	var stone_cell := grass_cell + Vector3i.RIGHT
	world.place_block(stone_cell, VoxelWorld.STONE)
	_expect(block_audio.last_event_group == &"stone", "放置石头动态选择石质音效")
	world.remove_block(stone_cell)
	var wood_cell := stone_cell + Vector3i.RIGHT
	world.place_block(wood_cell, VoxelWorld.PLANKS)
	_expect(block_audio.last_event_group == &"wood", "放置木板动态选择木质音效")
	world.remove_block(wood_cell)
	_expect(block_audio.last_event_group == &"wood", "破坏木板保留木质音效映射")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
