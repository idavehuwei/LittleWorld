class_name FootstepController
extends Node

signal footstep_played(surface_group: StringName, block_type: int)

const STEP_STREAMS := {
	&"grass": preload("res://assets/audio/sfx/step_grass.wav"),
	&"stone": preload("res://assets/audio/sfx/step_stone.wav"),
	&"wood": preload("res://assets/audio/sfx/step_wood.wav"),
}
const MIN_STEP_DISTANCE := 1.6
const MAX_STEP_DISTANCE := 2.35

var world: VoxelWorld
var player: FirstPersonPlayer
var audio_player: AudioStreamPlayer3D
var distance_since_step := 0.0
var last_horizontal_position := Vector2.ZERO
var last_surface_group: StringName = &"grass"
var last_block_type := VoxelWorld.GRASS
var step_count := 0


func _ready() -> void:
	assert(world != null, "FootstepController 需要在进入场景树前设置 world")
	assert(player != null, "FootstepController 需要在进入场景树前设置 player")
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "FootstepPlayer"
	audio_player.bus = GameAudioSystem.SFX_BUS
	audio_player.max_distance = 10.0
	audio_player.unit_size = 2.0
	audio_player.volume_db = -7.0
	add_child(audio_player)
	last_horizontal_position = Vector2(player.global_position.x, player.global_position.z)


func _physics_process(_delta: float) -> void:
	var current_position := Vector2(player.global_position.x, player.global_position.z)
	var moved_distance := current_position.distance_to(last_horizontal_position)
	last_horizontal_position = current_position
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if not player.is_on_floor() or horizontal_speed < 0.35:
		distance_since_step = 0.0
		return
	distance_since_step += moved_distance
	var step_distance := lerpf(MAX_STEP_DISTANCE, MIN_STEP_DISTANCE, clampf(horizontal_speed / FirstPersonPlayer.WALK_SPEED, 0.0, 1.0))
	if distance_since_step >= step_distance:
		distance_since_step = fmod(distance_since_step, step_distance)
		play_footstep()


func play_footstep() -> void:
	last_block_type = block_below_player()
	last_surface_group = surface_group_for_block(last_block_type)
	audio_player.stream = STEP_STREAMS[last_surface_group] as AudioStream
	audio_player.pitch_scale = randf_range(0.94, 1.06)
	audio_player.play()
	step_count += 1
	footstep_played.emit(last_surface_group, last_block_type)


func block_below_player() -> int:
	var local_position := world.to_local(player.global_position + Vector3(0.0, -0.08, 0.0))
	var cell := world.local_to_map(local_position)
	if world.get_block(cell) == VoxelWorld.AIR:
		cell.y -= 1
	return world.get_block(cell)


static func surface_group_for_block(block_type: int) -> StringName:
	if block_type in [VoxelWorld.STONE, VoxelWorld.BRICKS]:
		return &"stone"
	if block_type in [VoxelWorld.LOG, VoxelWorld.PLANKS]:
		return &"wood"
	return &"grass"
