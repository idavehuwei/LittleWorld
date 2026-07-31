class_name DayNightCycle
extends Node3D

signal time_changed(normalized_time: float, hour: float)

const DAY_DURATION_SECONDS := 600.0
const HOURS_PER_DAY := 24.0
const START_HOUR := 8.0

const NIGHT_SKY_TOP := Color("071127")
const NIGHT_SKY_HORIZON := Color("17264a")
const DAY_SKY_TOP := Color("4c9fe8")
const DAY_SKY_HORIZON := Color("b9e5ff")
const SUNSET_SKY_TOP := Color("4f6096")
const SUNSET_SKY_HORIZON := Color("f09a69")
const NIGHT_GROUND := Color("090d18")
const DAY_GROUND := Color("587070")
const NIGHT_AMBIENT := Color("7891c4")
const DAY_AMBIENT := Color("d9edff")
const NIGHT_SUN_COLOR := Color("7082ad")
const DAY_SUN_COLOR := Color("fff1c9")
const SUNSET_SUN_COLOR := Color("ff9b63")

var world_environment: WorldEnvironment
var environment: Environment
var sky: Sky
var sky_material: ProceduralSkyMaterial
var sun: DirectionalLight3D
var time_of_day := START_HOUR / HOURS_PER_DAY
var time_scale := 1.0
var running := true


func _ready() -> void:
	_build_environment()
	_build_sun()
	set_time_of_day(time_of_day)


func _process(delta: float) -> void:
	if not running:
		return
	time_of_day = fposmod(time_of_day + delta * time_scale / DAY_DURATION_SECONDS, 1.0)
	_apply_time_state()


func set_time_of_day(normalized_time: float) -> void:
	time_of_day = fposmod(normalized_time, 1.0)
	if environment != null and sun != null:
		_apply_time_state()


func set_hour(hour: float) -> void:
	set_time_of_day(hour / HOURS_PER_DAY)


func get_hour() -> float:
	return time_of_day * HOURS_PER_DAY


func get_daylight_factor() -> float:
	# 正午为 1，午夜为 0；黎明和黄昏附近平滑过渡。
	var solar_height := sin((time_of_day - 0.25) * TAU)
	return smoothstep(-0.16, 0.24, solar_height)


func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX

	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_curve = 0.12
	sky_material.sky_energy_multiplier = 1.0
	sky_material.ground_curve = 0.08
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.08

	sky = Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.sky_material = sky_material
	environment.sky = sky
	world_environment.environment = environment
	add_child(world_environment)


func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_angular_distance = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _apply_time_state() -> void:
	var daylight := get_daylight_factor()
	var horizon_weight := _get_horizon_weight()

	# 6:00 时太阳在东侧地平线，12:00 在最高点，18:00 在西侧地平线。
	var sun_pitch := time_of_day * 360.0 - 90.0
	sun.rotation_degrees = Vector3(sun_pitch, -28.0, 0.0)

	var sky_top := NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, daylight)
	var sky_horizon := NIGHT_SKY_HORIZON.lerp(DAY_SKY_HORIZON, daylight)
	sky_top = sky_top.lerp(SUNSET_SKY_TOP, horizon_weight * 0.58)
	sky_horizon = sky_horizon.lerp(SUNSET_SKY_HORIZON, horizon_weight)
	sky_material.sky_top_color = sky_top
	sky_material.sky_horizon_color = sky_horizon
	sky_material.ground_bottom_color = NIGHT_GROUND.lerp(DAY_GROUND, daylight)
	sky_material.ground_horizon_color = sky_horizon.darkened(0.38)

	environment.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, daylight)
	environment.ambient_light_energy = lerpf(0.14, 0.72, daylight)
	environment.background_energy_multiplier = lerpf(0.22, 1.0, daylight)

	var daylight_sun_energy := lerpf(0.0, 1.18, daylight)
	var moonlight_energy := lerpf(0.055, 0.0, daylight)
	sun.light_energy = maxf(daylight_sun_energy, moonlight_energy)
	var sun_color := NIGHT_SUN_COLOR.lerp(DAY_SUN_COLOR, daylight)
	sun.light_color = sun_color.lerp(SUNSET_SUN_COLOR, horizon_weight * 0.82)
	sun.shadow_enabled = daylight > 0.08

	time_changed.emit(time_of_day, get_hour())


func _get_horizon_weight() -> float:
	var dawn_distance := absf(time_of_day - 0.25)
	var dusk_distance := absf(time_of_day - 0.75)
	var distance_to_horizon := minf(dawn_distance, dusk_distance)
	return 1.0 - smoothstep(0.0, 0.11, distance_to_horizon)
