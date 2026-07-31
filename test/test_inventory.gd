extends SceneTree

var failures := 0
var frame := 0
var main: Node
var world: VoxelWorld
var player: FirstPersonPlayer
var hud: GameHUD
var inventory: PlayerInventory


func _init() -> void:
	var scene := load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	physics_frame.connect(_on_physics_frame)


func _on_physics_frame() -> void:
	frame += 1
	if frame == 5:
		world = main.get_node("VoxelWorld") as VoxelWorld
		player = main.get_node("Player") as FirstPersonPlayer
		hud = main.get_node("HUD") as GameHUD
		inventory = player.inventory
		_test_structure_and_starter_items()
		_test_stacking_and_capacity()
		_test_hotbar_selection()
		_test_inventory_ui_mode()
		_prepare_break_pickup()
	elif frame == 8:
		_test_break_pickup()
		_test_full_inventory_rejection()
		_prepare_place_consumption()
	elif frame == 11:
		_test_place_consumption()
		_test_empty_slot_rejection()
		_test_slot_swap()
		main.queue_free()
	elif frame == 20:
		quit(failures)


func _test_structure_and_starter_items() -> void:
	_expect(inventory != null, "玩家持有唯一背包数据对象")
	_expect(inventory.item_ids.size() == 36 and inventory.amounts.size() == 36, "背包固定包含36格")
	_expect(PlayerInventory.HOTBAR_SIZE == 9, "前9格定义为快捷栏")
	_expect(hud.hotbar_buttons.size() == 9, "HUD始终显示9格快捷栏")
	_expect(hud.inventory_buttons.size() == 36, "完整背包界面显示全部36格")
	_expect(inventory.get_item(0) == VoxelWorld.GRASS and inventory.get_amount(0) == 64, "第一格初始为64个草方块")
	_expect(inventory.get_item(4) == VoxelWorld.BRICKS and inventory.get_amount(4) == 64, "第五格初始为64个砖块")
	_expect(inventory.is_empty(8), "第九格可以为空")


func _test_stacking_and_capacity() -> void:
	var isolated := PlayerInventory.new()
	isolated.set_slot(10, VoxelWorld.STONE, 63)
	_expect(isolated.can_add(VoxelWorld.STONE, 2), "同类未满堆栈和空格可共同容纳物品")
	_expect(isolated.add_item(VoxelWorld.STONE, 2) == 0, "添加算法完整接收两个石头")
	_expect(isolated.get_amount(10) == 64, "优先补满已有同类堆栈")
	_expect(isolated.get_item(0) == VoxelWorld.STONE and isolated.get_amount(0) == 1, "剩余物品占用第一个空格")
	for index: int in range(PlayerInventory.SLOT_COUNT):
		isolated.set_slot(index, VoxelWorld.DIRT, 64)
	_expect(not isolated.can_add(VoxelWorld.STONE, 1), "36格全部堆满时无法容纳新物品")
	_expect(isolated.add_item(VoxelWorld.STONE, 1) == 1, "背包满时返回未放入数量")


func _test_hotbar_selection() -> void:
	player.select_slot(4)
	_expect(inventory.selected_hotbar_index == 4, "数字槽位逻辑选择第五格")
	_expect(player.selected_block == VoxelWorld.BRICKS, "当前方块来自所选快捷栏物品")
	player.select_slot(8)
	_expect(player.selected_block == PlayerInventory.EMPTY_ITEM, "选择空快捷栏时当前物品为空")
	player.cycle_slot(1)
	_expect(inventory.selected_hotbar_index == 0, "滚轮可从第九格循环到第一格")


func _test_inventory_ui_mode() -> void:
	player.set_inventory_open(true)
	_expect(player.inventory_open, "E键对应逻辑可打开背包")
	_expect(hud.inventory_panel.visible, "打开时显示完整背包面板")
	_expect(not hud.crosshair.visible, "打开背包时隐藏准星")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "打开背包时释放鼠标")
	player.set_inventory_open(false)
	_expect(not hud.inventory_panel.visible, "关闭时隐藏完整背包面板")
	_expect(hud.crosshair.visible, "关闭背包时恢复准星")
	_expect(not player.inventory_open, "关闭后恢复第一人称交互状态")


func _prepare_break_pickup() -> void:
	inventory.clear()
	inventory.set_slot(0, VoxelWorld.STONE, 63)
	var cell := Vector3i(15, 2, 15)
	world.place_block(cell, VoxelWorld.STONE)
	player.has_target = true
	player.target_cell = cell
	player.target_normal = Vector3i.UP


func _test_break_pickup() -> void:
	var cell := Vector3i(15, 2, 15)
	player.has_target = true
	player.target_cell = cell
	player.target_normal = Vector3i.UP
	_expect(player.try_break_target_block(), "破坏方块成功时收入背包")
	_expect(world.get_block(cell) == VoxelWorld.AIR, "收入背包后世界方块消失")
	_expect(inventory.get_amount(0) == 64, "破坏所得优先叠加到同类未满槽")


func _test_full_inventory_rejection() -> void:
	for index: int in range(PlayerInventory.SLOT_COUNT):
		inventory.set_slot(index, VoxelWorld.DIRT, 64)
	var cell := Vector3i(16, 2, 16)
	world.place_block(cell, VoxelWorld.STONE)
	player.has_target = true
	player.target_cell = cell
	player.target_normal = Vector3i.UP
	_expect(not player.try_break_target_block(), "背包满且无同类空间时拒绝破坏")
	_expect(world.get_block(cell) == VoxelWorld.STONE, "背包满时保留世界方块")


func _prepare_place_consumption() -> void:
	inventory.clear()
	inventory.set_slot(0, VoxelWorld.BRICKS, 2)
	player.select_slot(0)
	player.position = Vector3(20.0, 1.0, 20.0)
	player.velocity = Vector3.ZERO


func _test_place_consumption() -> void:
	player.has_target = true
	player.target_cell = Vector3i(5, 0, 5)
	player.target_normal = Vector3i.UP
	_expect(player.try_place_target_block(), "快捷栏有物品时可放置方块")
	_expect(world.get_block(Vector3i(5, 1, 5)) == VoxelWorld.BRICKS, "放置类型来自快捷栏当前格")
	_expect(inventory.get_amount(0) == 1, "成功放置后消耗一个物品")


func _test_empty_slot_rejection() -> void:
	inventory.set_slot(0, VoxelWorld.BRICKS, 1)
	inventory.remove_from_slot(0, 1)
	player.select_slot(0)
	player.has_target = true
	player.target_cell = Vector3i(6, 0, 6)
	player.target_normal = Vector3i.UP
	_expect(inventory.is_empty(0), "数量归零后快捷栏格自动清空")
	_expect(not player.try_place_target_block(), "空快捷栏格无法继续放置")
	_expect(world.get_block(Vector3i(6, 1, 6)) == VoxelWorld.AIR, "失败放置不修改世界")


func _test_slot_swap() -> void:
	inventory.set_slot(20, VoxelWorld.PLANKS, 12)
	inventory.swap_slots(20, 2)
	_expect(inventory.get_item(2) == VoxelWorld.PLANKS and inventory.get_amount(2) == 12, "主背包物品可以交换到快捷栏")
	_expect(inventory.is_empty(20), "交换后原主背包格为空")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
