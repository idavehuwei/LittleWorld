extends Node3D

var world: VoxelWorld
var player: FirstPersonPlayer
var day_night_cycle: DayNightCycle
var block_audio_manager: BlockAudioManager
var inventory: PlayerInventory
var crafting_grid: CraftingGrid
var animal_spawner: AnimalSpawner
var game_audio_system: GameAudioSystem
var save_game_manager: SaveGameManager
var start_menu: CanvasLayer


func _ready() -> void:
	_setup_font()
	_register_inputs()

	day_night_cycle = DayNightCycle.new()
	day_night_cycle.name = "DayNightCycle"
	add_child(day_night_cycle)

	world = VoxelWorld.new()
	world.name = "VoxelWorld"
	add_child(world)
	world.build_initial_world()

	block_audio_manager = BlockAudioManager.new()
	block_audio_manager.name = "BlockAudioManager"
	block_audio_manager.world = world
	add_child(block_audio_manager)

	inventory = PlayerInventory.new()
	inventory.seed_demo_items()
	crafting_grid = CraftingGrid.new(inventory)

	player = FirstPersonPlayer.new()
	player.name = "Player"
	player.world = world
	player.inventory = inventory
	player.position = world.spawn_world_position()
	add_child(player)

	animal_spawner = AnimalSpawner.new()
	animal_spawner.name = "Animals"
	animal_spawner.world = world
	animal_spawner.player = player
	add_child(animal_spawner)

	game_audio_system = GameAudioSystem.new()
	game_audio_system.name = "GameAudioSystem"
	game_audio_system.world = world
	game_audio_system.player = player
	add_child(game_audio_system)

	save_game_manager = SaveGameManager.new()
	save_game_manager.name = "SaveGameManager"
	save_game_manager.world = world
	save_game_manager.player = player
	save_game_manager.inventory = inventory
	save_game_manager.day_night_cycle = day_night_cycle
	add_child(save_game_manager)

	var hud := GameHUD.new()
	hud.name = "HUD"
	hud.inventory = inventory
	hud.crafting_grid = crafting_grid
	hud.game_audio_system = game_audio_system
	add_child(hud)
	player.selection_changed.connect(hud.set_selected_block)
	player.inventory_visibility_changed.connect(hud.set_inventory_open)
	hud.set_selected_block(player.selected_block)
	if save_game_manager.has_save_file():
		_show_start_menu()


func _show_start_menu() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_menu = CanvasLayer.new()
	start_menu.name = "StartMenu"
	start_menu.layer = 100
	start_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(start_menu)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.025, 0.035, 0.82)
	start_menu.add_child(overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -150)
	panel.custom_minimum_size = Vector2(500, 300)
	overlay.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 22)
	panel.add_child(content)
	var title := Label.new()
	title.text = "哼哼的小小世界"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	content.add_child(title)
	var prompt := Label.new()
	prompt.text = "检测到存档，请选择"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 21)
	content.add_child(prompt)
	var continue_button := Button.new()
	continue_button.name = "ContinueGameButton"
	continue_button.text = "继续游戏"
	continue_button.custom_minimum_size = Vector2(300, 58)
	continue_button.add_theme_font_size_override("font_size", 22)
	continue_button.pressed.connect(_continue_saved_game)
	content.add_child(continue_button)
	var new_game_button := Button.new()
	new_game_button.name = "NewGameButton"
	new_game_button.text = "开始新游戏"
	new_game_button.custom_minimum_size = Vector2(300, 58)
	new_game_button.add_theme_font_size_override("font_size", 22)
	new_game_button.pressed.connect(_start_new_game)
	content.add_child(new_game_button)


func _continue_saved_game() -> void:
	if save_game_manager.load_game():
		_close_start_menu()


func _start_new_game() -> void:
	save_game_manager.start_new_game()
	_close_start_menu()


func _close_start_menu() -> void:
	if is_instance_valid(start_menu):
		start_menu.queue_free()
	start_menu = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_font() -> void:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC"])
	ThemeDB.fallback_font = system_font


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
	_bind_key(&"slot_5", KEY_5)
	_bind_key(&"slot_6", KEY_6)
	_bind_key(&"slot_7", KEY_7)
	_bind_key(&"slot_8", KEY_8)
	_bind_key(&"slot_9", KEY_9)
	_bind_key(&"toggle_inventory", KEY_E)
	_bind_key(&"save_game", KEY_F5)


func _bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)
