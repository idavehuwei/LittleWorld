extends SceneTree

var failures := 0
var frame := 0
var main: Node
var save_path := SaveGameManager.DEFAULT_SAVE_PATH
var temp_path := SaveGameManager.DEFAULT_TEMP_SAVE_PATH
var backup_path := SaveGameManager.DEFAULT_BACKUP_SAVE_PATH
var backup_save := PackedByteArray()
var backup_temp := PackedByteArray()
var had_save := false
var had_temp := false


func _init() -> void:
	_backup_real_files()
	_write_valid_save_stub()
	var scene := load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	frame += 1
	if frame == 4:
		var menu := main.get_node_or_null("StartMenu") as CanvasLayer
		_expect(menu != null, "启动时检测到存档并显示选择界面")
		_expect(paused, "存档选择期间暂停整个游戏世界")
		if menu != null:
			_expect(menu.find_child("ContinueGameButton", true, false) != null, "启动界面包含继续游戏按钮")
			var new_game_button := menu.find_child("NewGameButton", true, false) as Button
			_expect(new_game_button != null, "启动界面包含开始新游戏按钮")
			if new_game_button != null:
				new_game_button.pressed.emit()
	elif frame == 8:
		_expect(not paused, "选择开始新游戏后恢复世界运行")
		_expect(main.get_node_or_null("StartMenu") == null or main.start_menu == null, "选择后关闭启动菜单")
		main.queue_free()
	elif frame == 14:
		_restore_real_files()
		quit(failures)


func _write_valid_save_stub() -> void:
	var data := {
		"version": SaveGameManager.SAVE_VERSION,
		"world": {"terrain_seed": VoxelWorld.TERRAIN_SEED, "modified_blocks": []},
		"player": {"position": [0.5, 2.0, 5.5], "body_rotation_y": 0.0, "head_rotation_x": 0.0},
		"inventory": {"selected_hotbar_index": 0, "slots": []},
		"day_night": {"time_of_day": DayNightCycle.START_HOUR / DayNightCycle.HOURS_PER_DAY},
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _backup_real_files() -> void:
	had_save = FileAccess.file_exists(save_path)
	had_temp = FileAccess.file_exists(temp_path)
	if had_save:
		backup_save = FileAccess.get_file_as_bytes(save_path)
	if had_temp:
		backup_temp = FileAccess.get_file_as_bytes(temp_path)


func _restore_real_files() -> void:
	for path: String in [save_path, temp_path, backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(backup_save)
		file.close()
	if had_temp:
		var file := FileAccess.open(temp_path, FileAccess.WRITE)
		file.store_buffer(backup_temp)
		file.close()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
