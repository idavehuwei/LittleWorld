extends SceneTree

var failures := 0
var frame := 0
var main: Node
var inventory: PlayerInventory
var crafting: CraftingGrid
var hud: GameHUD


func _init() -> void:
	var scene := load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	frame += 1
	if frame == 5:
		inventory = main.get("inventory") as PlayerInventory
		crafting = main.get("crafting_grid") as CraftingGrid
		hud = main.get_node("HUD") as GameHUD
		_test_catalog_and_ui()
		_test_log_recipe_any_position()
		_test_invalid_pattern()
		_test_planks_recipe()
		_test_click_movement_and_repeat()
		_test_full_inventory_atomicity()
		main.queue_free()
	elif frame == 15:
		quit(failures)


func _test_catalog_and_ui() -> void:
	_expect(ItemCatalog.is_valid_item(ItemCatalog.LOG), "物品目录注册木头")
	_expect(ItemCatalog.is_valid_item(ItemCatalog.CRAFTING_TABLE), "物品目录注册工作台")
	_expect(load(ItemCatalog.icon_path(ItemCatalog.LOG)) is Texture2D, "木头图标可加载")
	_expect(load(ItemCatalog.icon_path(ItemCatalog.CRAFTING_TABLE)) is Texture2D, "工作台图标可加载")
	_expect(hud.crafting_buttons.size() == 4, "背包界面包含2×2四个合成输入格")
	_expect(hud.crafting_output_button != null, "背包界面包含一个输出格")
	_expect(inventory.get_item(5) == ItemCatalog.LOG and inventory.get_amount(5) == 8, "演示背包提供8个木头")


func _test_log_recipe_any_position() -> void:
	for position: int in range(CraftingGrid.GRID_SIZE):
		var isolated_inventory := PlayerInventory.new()
		var isolated := CraftingGrid.new(isolated_inventory)
		isolated.set_slot_for_test(position, ItemCatalog.LOG, 1)
		_expect(isolated.output_item() == VoxelWorld.PLANKS, "木头位于格%d时匹配木板配方" % position)
		_expect(isolated.output_amount() == 4, "1个木头预览4个木板")
		_expect(isolated.craft_once(), "木头配方可以领取输出")
		_expect(isolated_inventory.get_item(0) == VoxelWorld.PLANKS and isolated_inventory.get_amount(0) == 4, "成品进入背包")
		_expect(isolated.get_amount(position) == 0, "领取后消耗1个木头")


func _test_invalid_pattern() -> void:
	var isolated := CraftingGrid.new(PlayerInventory.new())
	isolated.set_slot_for_test(0, ItemCatalog.LOG, 1)
	isolated.set_slot_for_test(1, VoxelWorld.STONE, 1)
	_expect(isolated.output_item() == PlayerInventory.EMPTY_ITEM, "存在多余材料时输出为空")
	_expect(not isolated.craft_once(), "无匹配配方不能领取输出")


func _test_planks_recipe() -> void:
	var isolated_inventory := PlayerInventory.new()
	var isolated := CraftingGrid.new(isolated_inventory)
	for index: int in range(CraftingGrid.GRID_SIZE):
		isolated.set_slot_for_test(index, VoxelWorld.PLANKS, 2)
	_expect(isolated.output_item() == ItemCatalog.CRAFTING_TABLE, "四格木板匹配工作台配方")
	_expect(isolated.output_amount() == 1, "工作台配方输出1个")
	_expect(isolated.craft_once(), "可领取工作台")
	_expect(isolated_inventory.get_item(0) == ItemCatalog.CRAFTING_TABLE, "工作台进入背包")
	for index: int in range(CraftingGrid.GRID_SIZE):
		_expect(isolated.get_amount(index) == 1, "工作台合成每格消耗1个木板")
	_expect(isolated.output_item() == ItemCatalog.CRAFTING_TABLE, "材料仍足够时继续显示工作台预览")


func _test_click_movement_and_repeat() -> void:
	var isolated_inventory := PlayerInventory.new()
	isolated_inventory.set_slot(7, ItemCatalog.LOG, 2)
	var isolated := CraftingGrid.new(isolated_inventory)
	_expect(isolated.move_one_from_inventory(7, 3), "点击流程可从背包移入1个材料")
	_expect(isolated_inventory.get_amount(7) == 1 and isolated.get_amount(3) == 1, "移动时背包与合成格数量同步")
	_expect(isolated.craft_once(), "第一次木头合成成功")
	_expect(isolated.move_one_from_inventory(7, 3), "可继续移入第二个木头")
	_expect(isolated.craft_once(), "第二次木头合成成功")
	_expect(isolated_inventory.get_amount(0) == 8, "两次结果自动堆叠为8个木板")
	isolated_inventory.set_slot(8, VoxelWorld.STONE, 1)
	_expect(isolated.move_one_from_inventory(8, 1), "材料可移入空合成格")
	_expect(isolated.return_one_to_inventory(1), "点击合成格可取回1个材料")
	_expect(isolated_inventory.count_item(VoxelWorld.STONE) == 1, "取回材料返回背包")


func _test_full_inventory_atomicity() -> void:
	var full_inventory := PlayerInventory.new()
	for index: int in range(PlayerInventory.SLOT_COUNT):
		full_inventory.set_slot(index, VoxelWorld.DIRT, 64)
	var isolated := CraftingGrid.new(full_inventory)
	isolated.set_slot_for_test(0, ItemCatalog.LOG, 1)
	_expect(isolated.output_item() == VoxelWorld.PLANKS, "满包时仍显示正确配方预览")
	_expect(not isolated.craft_once(), "背包无法容纳完整输出时拒绝合成")
	_expect(isolated.get_item(0) == ItemCatalog.LOG and isolated.get_amount(0) == 1, "拒绝合成不会消耗材料")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
