extends Node3D

var world: VoxelWorld
var player: FirstPersonPlayer
var day_night_cycle: DayNightCycle
var block_audio_manager: BlockAudioManager
var inventory: PlayerInventory
var crafting_grid: CraftingGrid
var animal_spawner: AnimalSpawner


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

	var hud := GameHUD.new()
	hud.name = "HUD"
	hud.inventory = inventory
	hud.crafting_grid = crafting_grid
	add_child(hud)
	player.selection_changed.connect(hud.set_selected_block)
	player.inventory_visibility_changed.connect(hud.set_inventory_open)
	hud.set_selected_block(player.selected_block)


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


func _bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)
