extends SceneTree

const TEST_SAVE_PATH := "user://test_save_slot_1.json"
const TEST_TEMP_PATH := "user://test_save_slot_1.tmp"
const TEST_BACKUP_PATH := "user://test_save_slot_1.bak"

var failures := 0
var frame := 0
var main: Node
var world: VoxelWorld
var player: FirstPersonPlayer
var inventory: PlayerInventory
var day_night: DayNightCycle
var save_manager: SaveGameManager
var changed_cell := Vector3i.ZERO
var saved_position := Vector3.ZERO


func _init() -> void:
	_cleanup_test_save()
	var scene := load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	frame += 1
	if frame == 6:
		world = main.get_node("VoxelWorld") as VoxelWorld
		player = main.get_node("Player") as FirstPersonPlayer
		inventory = main.inventory as PlayerInventory
		day_night = main.get_node("DayNightCycle") as DayNightCycle
		save_manager = main.get_node("SaveGameManager") as SaveGameManager
		save_manager.save_path = TEST_SAVE_PATH
		save_manager.temp_save_path = TEST_TEMP_PATH
		save_manager.backup_save_path = TEST_BACKUP_PATH
		_test_configuration()
		_test_manual_input_trigger()
		_test_automatic_save_trigger()
		_prepare_and_save_state()
	elif frame == 8:
		_test_json_contents()
		_mutate_state_after_save()
		_expect(save_manager.load_game(), "单槽JSON存档可成功读取")
		_test_restored_state()
	elif frame == 11:
		_test_runtime_resumes_after_load()
		_test_new_game_reset()
		_cleanup_test_save()
		main.queue_free()
	elif frame == 22:
		quit(failures)


func _test_configuration() -> void:
	_expect(SaveGameManager.AUTO_SAVE_INTERVAL == 300.0, "自动保存间隔为5分钟")
	_expect(InputMap.has_action(&"save_game"), "项目注册F5保存动作")
	var has_f5 := false
	for event: InputEvent in InputMap.action_get_events(&"save_game"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_F5:
			has_f5 = true
	_expect(has_f5, "save_game动作绑定F5")
	_expect(not save_manager.has_save_file(), "测试单槽初始不存在时直接进入新游戏")


func _test_manual_input_trigger() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F5
	event.pressed = true
	save_manager._unhandled_input(event)
	_expect(save_manager.last_save_reason == &"manual" and save_manager.save_count == 1, "真实F5输入触发手动保存")
	save_manager.delete_save_file()


func _test_automatic_save_trigger() -> void:
	save_manager.autosave_time_remaining = 0.001
	save_manager._process(0.01)
	_expect(save_manager.last_save_reason == &"auto" and save_manager.save_count == 2, "倒计时到期触发自动保存")
	_expect(save_manager.autosave_time_remaining == SaveGameManager.AUTO_SAVE_INTERVAL, "自动保存成功后重置5分钟倒计时")
	save_manager.delete_save_file()


func _prepare_and_save_state() -> void:
	var surface_y := world.get_surface_height(24, 24)
	changed_cell = Vector3i(24, surface_y + 1, 24)
	_expect(world.place_block(changed_cell, VoxelWorld.BRICKS), "准备一个世界方块修改")
	saved_position = Vector3(8.5, float(world.get_surface_height(8, 8) + 2), 8.5)
	player.global_position = saved_position
	player.rotation.y = 1.15
	player.head.rotation.x = -0.32
	inventory.set_slot(10, VoxelWorld.STONE, 37)
	inventory.select_hotbar(4)
	day_night.set_hour(19.5)
	_expect(save_manager.save_game(&"manual"), "F5同入口可写入单槽存档")
	_expect(save_manager.has_save_file(), "保存后单槽文件存在")
	_expect(save_manager.last_save_reason == &"manual", "记录手动保存原因")


func _test_json_contents() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	_expect(file != null, "JSON存档文件可读取")
	if file == null:
		return
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	_expect(parse_error == OK and json.data is Dictionary, "存档是合法JSON对象")
	if parse_error != OK or not json.data is Dictionary:
		return
	var data := json.data as Dictionary
	_expect(int(data.get("version", 0)) == SaveGameManager.SAVE_VERSION, "存档包含格式版本")
	var world_data := data.get("world", {}) as Dictionary
	_expect((world_data.get("modified_blocks", []) as Array).size() == 1, "世界只保存修改过的方块差异")
	var inventory_data := data.get("inventory", {}) as Dictionary
	_expect((inventory_data.get("slots", []) as Array).size() == PlayerInventory.SLOT_COUNT, "存档包含全部36格背包数据")
	_expect((data.get("player", {}) as Dictionary).has("position"), "存档包含玩家位置和朝向")
	_expect((data.get("day_night", {}) as Dictionary).has("time_of_day"), "存档包含昼夜时间")


func _mutate_state_after_save() -> void:
	world.remove_block(changed_cell)
	player.global_position = Vector3(0.5, 20.0, 0.5)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	inventory.set_slot(10, VoxelWorld.DIRT, 2)
	inventory.select_hotbar(0)
	day_night.set_hour(2.0)


func _test_restored_state() -> void:
	_expect(world.get_block(changed_cell) == VoxelWorld.BRICKS, "读档恢复修改后的世界方块")
	_expect(world.modified_blocks.size() == 1, "读档后继续保留方块差异集合")
	_expect(player.global_position.distance_to(saved_position) < 0.01, "读档恢复玩家位置")
	_expect(absf(player.rotation.y - 1.15) < 0.001 and absf(player.head.rotation.x + 0.32) < 0.001, "读档恢复玩家水平和垂直朝向")
	_expect(inventory.get_item(10) == VoxelWorld.STONE and inventory.get_amount(10) == 37, "读档恢复背包全部槽位")
	_expect(inventory.selected_hotbar_index == 4, "读档恢复快捷栏选择")
	_expect(absf(day_night.get_hour() - 19.5) < 0.01, "读档恢复昼夜时间")
	_expect(save_manager.autosave_time_remaining == SaveGameManager.AUTO_SAVE_INTERVAL, "读档后重置自动保存倒计时")


func _test_runtime_resumes_after_load() -> void:
	_expect(day_night.get_hour() > 19.5, "读档完成后昼夜系统继续正常推进")
	_expect(save_manager.autosave_time_remaining < SaveGameManager.AUTO_SAVE_INTERVAL, "读档完成后自动保存倒计时继续运行")


func _test_new_game_reset() -> void:
	save_manager.start_new_game()
	_expect(not save_manager.has_save_file(), "开始新游戏会删除旧单槽存档")
	_expect(world.modified_blocks.is_empty(), "开始新游戏重建固定种子初始世界")
	_expect(inventory.get_amount(0) == ItemCatalog.MAX_STACK, "开始新游戏恢复初始背包")
	_expect(absf(day_night.get_hour() - DayNightCycle.START_HOUR) < 0.01, "开始新游戏恢复默认昼夜时间")


func _cleanup_test_save() -> void:
	for path: String in [TEST_SAVE_PATH, TEST_TEMP_PATH, TEST_BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
