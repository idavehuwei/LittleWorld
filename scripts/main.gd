extends Node3D

var world: VoxelWorld
var player: FirstPersonPlayer


func _ready() -> void:
	_setup_font()
	_register_inputs()
	_build_environment()

	world = VoxelWorld.new()
	world.name = "VoxelWorld"
	add_child(world)
	world.build_flat_world(50, 50)

	player = FirstPersonPlayer.new()
	player.name = "Player"
	player.world = world
	player.position = Vector3(0.0, 2.0, 5.0)
	add_child(player)

	var hud := GameHUD.new()
	hud.name = "HUD"
	add_child(hud)
	player.selection_changed.connect(hud.set_selected_block)
	hud.set_selected_block(player.selected_block)


func _setup_font() -> void:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC"])
	ThemeDB.fallback_font = system_font


func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8ed5f7")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8ecff")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_color = Color("fff3cf")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func _register_inputs() -> void:
	_bind_key(&"move_forward", KEY_W)
	_bind_key(&"move_back", KEY_S)
	_bind_key(&"move_left", KEY_A)
	_bind_key(&"move_right", KEY_D)
	_bind_key(&"jump", KEY_SPACE)
	_bind_key(&"slot_1", KEY_1)
	_bind_key(&"slot_2", KEY_2)
	_bind_key(&"slot_3", KEY_3)
	_bind_key(&"slot_4", KEY_4)


func _bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)
