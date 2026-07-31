class_name BlockAudioManager
extends Node3D

signal sfx_triggered(kind: StringName, cell: Vector3i)

const BREAK_STREAM: AudioStream = preload("res://assets/audio/sfx/block_break.wav")
const PLACE_STREAM: AudioStream = preload("res://assets/audio/sfx/block_place.wav")
const BREAK_STREAMS := {
	&"grass": preload("res://assets/audio/sfx/break_grass.wav"),
	&"stone": preload("res://assets/audio/sfx/break_stone.wav"),
	&"wood": preload("res://assets/audio/sfx/break_wood.wav"),
}
const PLACE_STREAMS := {
	&"grass": preload("res://assets/audio/sfx/place_grass.wav"),
	&"stone": preload("res://assets/audio/sfx/place_stone.wav"),
	&"wood": preload("res://assets/audio/sfx/place_wood.wav"),
}
const POOL_SIZE := 4
const MAX_DISTANCE := 18.0

var world: VoxelWorld
var break_players: Array[AudioStreamPlayer3D] = []
var place_players: Array[AudioStreamPlayer3D] = []
var break_cursor := 0
var place_cursor := 0
var last_event_kind: StringName = &""
var last_event_cell := Vector3i.ZERO
var last_event_group: StringName = &"grass"


func _ready() -> void:
	assert(world != null, "BlockAudioManager 需要在进入场景树前设置 world")
	break_players = _create_player_pool(&"Break", BREAK_STREAM, -4.0)
	place_players = _create_player_pool(&"Place", PLACE_STREAM, -5.0)
	world.block_changed.connect(_on_block_changed)


func _create_player_pool(prefix: StringName, stream: AudioStream, volume_db: float) -> Array[AudioStreamPlayer3D]:
	var pool: Array[AudioStreamPlayer3D] = []
	for index: int in range(POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		player.name = "%sPlayer%d" % [prefix, index]
		player.stream = stream
		player.bus = GameAudioSystem.SFX_BUS
		player.volume_db = volume_db
		player.max_distance = MAX_DISTANCE
		player.unit_size = 3.0
		player.attenuation_filter_cutoff_hz = 12000.0
		add_child(player)
		pool.append(player)
	return pool


func _on_block_changed(cell: Vector3i, previous_type: int, new_type: int) -> void:
	if previous_type != VoxelWorld.AIR and new_type == VoxelWorld.AIR:
		_play_break(cell, previous_type)
	elif previous_type == VoxelWorld.AIR and new_type != VoxelWorld.AIR:
		_play_place(cell, new_type)


func _play_break(cell: Vector3i, block_type: int) -> void:
	var player := _next_player(break_players, break_cursor)
	break_cursor = (break_cursor + 1) % break_players.size()
	last_event_group = sound_group_for_block(block_type)
	player.stream = BREAK_STREAMS[last_event_group] as AudioStream
	_play_at_cell(player, cell, randf_range(0.92, 1.06), &"break")


func _play_place(cell: Vector3i, block_type: int) -> void:
	var player := _next_player(place_players, place_cursor)
	place_cursor = (place_cursor + 1) % place_players.size()
	last_event_group = sound_group_for_block(block_type)
	player.stream = PLACE_STREAMS[last_event_group] as AudioStream
	_play_at_cell(player, cell, randf_range(0.96, 1.04), &"place")


static func sound_group_for_block(block_type: int) -> StringName:
	if block_type in [VoxelWorld.STONE, VoxelWorld.BRICKS]:
		return &"stone"
	if block_type in [VoxelWorld.LOG, VoxelWorld.PLANKS]:
		return &"wood"
	return &"grass"


func _next_player(pool: Array[AudioStreamPlayer3D], fallback_index: int) -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in pool:
		if not player.playing:
			return player
	# 池已满时只复用最旧的轮转播放器，限制并发节点数量并避免无限叠音。
	var fallback := pool[fallback_index]
	fallback.stop()
	return fallback


func _play_at_cell(player: AudioStreamPlayer3D, cell: Vector3i, pitch: float, kind: StringName) -> void:
	player.global_position = world.to_global(world.map_to_local(cell))
	player.pitch_scale = pitch
	player.play()
	last_event_kind = kind
	last_event_cell = cell
	sfx_triggered.emit(kind, cell)
