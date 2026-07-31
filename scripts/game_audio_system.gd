class_name GameAudioSystem
extends Node

signal volume_changed(bus_name: StringName, linear_value: float)
signal ambient_event(kind: StringName)

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const AMBIENT_BUS := &"Ambient"
const DEFAULT_MASTER_VOLUME := 0.82
const DEFAULT_MUSIC_VOLUME := 0.38
const DEFAULT_SFX_VOLUME := 0.78
const BIRD_MIN_DELAY := 8.0
const BIRD_MAX_DELAY := 18.0

const MUSIC_STREAM: AudioStream = preload("res://assets/audio/music/little_world_theme.wav")
const WIND_STREAM: AudioStream = preload("res://assets/audio/ambient/wind_loop.wav")
const BIRD_STREAM: AudioStream = preload("res://assets/audio/ambient/bird_chirp.wav")

var world: VoxelWorld
var player: FirstPersonPlayer
var music_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var bird_player: AudioStreamPlayer
var footstep_controller: FootstepController
var bird_time_remaining := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	assert(world != null, "GameAudioSystem 需要在进入场景树前设置 world")
	assert(player != null, "GameAudioSystem 需要在进入场景树前设置 player")
	configure_audio_buses()
	rng.seed = 20260801
	_build_ambient_players()
	_build_footsteps()
	set_master_volume(DEFAULT_MASTER_VOLUME)
	set_music_volume(DEFAULT_MUSIC_VOLUME)
	set_sfx_volume(DEFAULT_SFX_VOLUME)
	music_player.play()
	wind_player.play()
	_schedule_next_bird()


func _process(delta: float) -> void:
	bird_time_remaining -= delta
	if bird_time_remaining <= 0.0:
		bird_player.pitch_scale = rng.randf_range(0.94, 1.08)
		bird_player.play()
		ambient_event.emit(&"bird")
		_schedule_next_bird()


func configure_audio_buses() -> void:
	_ensure_bus(MUSIC_BUS, &"Master")
	_ensure_bus(SFX_BUS, &"Master")
	_ensure_bus(AMBIENT_BUS, SFX_BUS)


func set_master_volume(linear_value: float) -> void:
	_set_bus_linear(&"Master", linear_value)


func set_music_volume(linear_value: float) -> void:
	_set_bus_linear(MUSIC_BUS, linear_value)


func set_sfx_volume(linear_value: float) -> void:
	_set_bus_linear(SFX_BUS, linear_value)


func get_master_volume() -> float:
	return _get_bus_linear(&"Master")


func get_music_volume() -> float:
	return _get_bus_linear(MUSIC_BUS)


func get_sfx_volume() -> float:
	return _get_bus_linear(SFX_BUS)


func _ensure_bus(bus_name: StringName, send_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, send_name)


func _set_bus_linear(bus_name: StringName, linear_value: float) -> void:
	var value := clampf(linear_value, 0.0, 1.0)
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.0001)))
	volume_changed.emit(bus_name, value)


func _get_bus_linear(bus_name: StringName) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0 or AudioServer.is_bus_mute(bus_index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index))


func _build_ambient_players() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.bus = MUSIC_BUS
	music_player.volume_db = -2.0
	music_player.stream = _looping_copy(MUSIC_STREAM)
	add_child(music_player)

	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindAmbience"
	wind_player.bus = AMBIENT_BUS
	wind_player.volume_db = -10.0
	wind_player.stream = _looping_copy(WIND_STREAM)
	add_child(wind_player)

	bird_player = AudioStreamPlayer.new()
	bird_player.name = "BirdAmbience"
	bird_player.bus = AMBIENT_BUS
	bird_player.volume_db = -7.0
	bird_player.stream = BIRD_STREAM
	add_child(bird_player)


func _build_footsteps() -> void:
	footstep_controller = FootstepController.new()
	footstep_controller.name = "Footsteps"
	footstep_controller.world = world
	footstep_controller.player = player
	player.add_child(footstep_controller)


func _looping_copy(source: AudioStream) -> AudioStream:
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


func _schedule_next_bird() -> void:
	bird_time_remaining = rng.randf_range(BIRD_MIN_DELAY, BIRD_MAX_DELAY)
