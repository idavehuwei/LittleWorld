class_name SaveGameManager
extends Node

signal game_saved(save_path: String)
signal game_loaded(save_path: String)
signal save_failed(message: String)

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save_slot_1.json"
const DEFAULT_TEMP_SAVE_PATH := "user://save_slot_1.tmp"
const DEFAULT_BACKUP_SAVE_PATH := "user://save_slot_1.bak"
const AUTO_SAVE_INTERVAL := 300.0

var world: VoxelWorld
var player: FirstPersonPlayer
var inventory: PlayerInventory
var day_night_cycle: DayNightCycle
var save_path := DEFAULT_SAVE_PATH
var temp_save_path := DEFAULT_TEMP_SAVE_PATH
var backup_save_path := DEFAULT_BACKUP_SAVE_PATH
var autosave_time_remaining := AUTO_SAVE_INTERVAL
var last_save_reason: StringName = &""
var save_count := 0
var load_count := 0


func _ready() -> void:
	assert(world != null, "SaveGameManager 需要 world")
	assert(player != null, "SaveGameManager 需要 player")
	assert(inventory != null, "SaveGameManager 需要 inventory")
	assert(day_night_cycle != null, "SaveGameManager 需要 day_night_cycle")


func _process(delta: float) -> void:
	autosave_time_remaining -= delta
	if autosave_time_remaining <= 0.0:
		if save_game(&"auto"):
			autosave_time_remaining = AUTO_SAVE_INTERVAL
		else:
			# 写入失败时短暂延后重试，而不是静默等待下一个完整五分钟。
			autosave_time_remaining = 30.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F5:
			save_game(&"manual")
			get_viewport().set_input_as_handled()


func has_save_file() -> bool:
	return FileAccess.file_exists(save_path)


func save_game(reason: StringName = &"manual") -> bool:
	var save_data := build_save_data()
	var json_text := JSON.stringify(save_data, "\t")
	var temp_file := FileAccess.open(temp_save_path, FileAccess.WRITE)
	if temp_file == null:
		return _fail("无法创建临时存档文件")
	temp_file.store_string(json_text)
	temp_file.flush()
	temp_file.close()
	var absolute_temp := ProjectSettings.globalize_path(temp_save_path)
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_save_path)
	if FileAccess.file_exists(backup_save_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			return _fail("无法备份旧存档，错误码：%d" % backup_error)
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if rename_error != OK:
		if FileAccess.file_exists(backup_save_path):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		return _fail("无法提交存档文件，错误码：%d" % rename_error)
	if FileAccess.file_exists(backup_save_path):
		DirAccess.remove_absolute(absolute_backup)
	last_save_reason = reason
	save_count += 1
	game_saved.emit(save_path)
	return true


func load_game() -> bool:
	if not has_save_file():
		return _fail("存档文件不存在")
	var save_file := FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		return _fail("无法读取存档文件")
	var json := JSON.new()
	var parse_error := json.parse(save_file.get_as_text())
	save_file.close()
	if parse_error != OK or not json.data is Dictionary:
		return _fail("存档JSON格式无效")
	var data := json.data as Dictionary
	if int(data.get("version", -1)) != SAVE_VERSION:
		return _fail("不支持的存档版本")
	apply_save_data(data)
	load_count += 1
	game_loaded.emit(save_path)
	return true


func start_new_game() -> void:
	delete_save_file()
	world.build_initial_world()
	inventory.clear()
	inventory.seed_demo_items()
	player.global_position = world.spawn_world_position()
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	day_night_cycle.set_hour(DayNightCycle.START_HOUR)
	autosave_time_remaining = AUTO_SAVE_INTERVAL


func delete_save_file() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save_path))
	if FileAccess.file_exists(backup_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_save_path))


func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"world": {
			"terrain_seed": VoxelWorld.TERRAIN_SEED,
			"modified_blocks": world.serialize_modified_blocks(),
		},
		"player": {
			"position": _vector3_to_array(player.global_position),
			"body_rotation_y": player.rotation.y,
			"head_rotation_x": player.head.rotation.x,
		},
		"inventory": {
			"selected_hotbar_index": inventory.selected_hotbar_index,
			"slots": inventory.serialize_slots(),
		},
		"day_night": {
			"time_of_day": day_night_cycle.time_of_day,
		},
	}


func apply_save_data(data: Dictionary) -> void:
	world.build_initial_world()
	var world_data := data.get("world", {}) as Dictionary
	world.apply_modified_blocks(world_data.get("modified_blocks", []) as Array)

	var player_data := data.get("player", {}) as Dictionary
	player.global_position = _array_to_vector3(player_data.get("position", []) as Array, world.spawn_world_position())
	player.rotation.y = float(player_data.get("body_rotation_y", 0.0))
	player.head.rotation.x = clampf(float(player_data.get("head_rotation_x", 0.0)), -FirstPersonPlayer.MAX_LOOK_ANGLE, FirstPersonPlayer.MAX_LOOK_ANGLE)
	player.velocity = Vector3.ZERO

	var inventory_data := data.get("inventory", {}) as Dictionary
	inventory.restore_slots(
		inventory_data.get("slots", []) as Array,
		int(inventory_data.get("selected_hotbar_index", 0))
	)
	var time_data := data.get("day_night", {}) as Dictionary
	day_night_cycle.set_time_of_day(float(time_data.get("time_of_day", DayNightCycle.START_HOUR / DayNightCycle.HOURS_PER_DAY)))
	autosave_time_remaining = AUTO_SAVE_INTERVAL


func _vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_to_vector3(value: Array, fallback: Vector3) -> Vector3:
	if value.size() < 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _fail(message: String) -> bool:
	save_failed.emit(message)
	push_error(message)
	return false
