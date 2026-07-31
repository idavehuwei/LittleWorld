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
		_test_empty_preview_hint()
		_test_log_recipe_any_position()
		_test_extra_materials_allowed()
		_test_multiple_candidates_and_selected_result()
		_test_preview_invalidation()
		_test_click_movement_and_repeat()
		_test_full_inventory_atomicity()
		_test_hud_candidate_buttons()
		main.queue_free()
	elif frame == 15:
		quit(failures)


func _test_catalog_and_ui() -> void:
	_expect(ItemCatalog.is_valid_item(ItemCatalog.LOG), "物品目录注册木头")
	_expect(ItemCatalog.is_valid_item(ItemCatalog.CRAFTING_TABLE), "物品目录注册工作台")
	_expect(load(ItemCatalog.icon_path(ItemCatalog.LOG)) is Texture2D, "木头图标可加载")
	_expect(load(ItemCatalog.icon_path(ItemCatalog.CRAFTING_TABLE)) is Texture2D, "工作台图标可加载")
	_expect(hud.crafting_buttons.size() == 4, "背包界面包含2×2四个合成输入格")
	_expect(hud.crafting_output_button != null, "背包界面包含一个输出预览格")
	_expect(hud.preview_button != null and hud.preview_button.text == "预览配方", "背包界面包含预览按钮")
	_expect(hud.craft_button != null and hud.craft_button.text == "合成", "背包界面包含独立合成按钮")
	_expect(hud.recipe_candidates != null, "背包界面包含多配方候选列表")
	_expect(hud.inventory_panel.custom_minimum_size.x >= 1000.0, "背包面板已放大为桌面宽面板")
	_expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 1600, "桌面逻辑宽度提升为1600")
	_expect(ProjectSettings.get_setting("display/window/size/viewport_height") == 900, "桌面逻辑高度提升为900")
	_expect(inventory.get_item(5) == ItemCatalog.LOG and inventory.get_amount(5) == 8, "演示背包提供8个木头")


func _test_empty_preview_hint() -> void:
	_expect(crafting.total_material_count() == 0, "主场景合成网格初始为空")
	hud._on_preview_pressed()
	_expect(hud.crafting_status.text == "请放入2×2材料", "空网格点击预览提示请放入2×2材料")
	_expect(not crafting.has_preview(), "空网格不会选中配方")


func _test_log_recipe_any_position() -> void:
	for position: int in range(CraftingGrid.GRID_SIZE):
		var isolated_inventory := PlayerInventory.new()
		var isolated := CraftingGrid.new(isolated_inventory)
		isolated.set_slot_for_test(position, ItemCatalog.LOG, 1)
		_expect(isolated.output_item() == PlayerInventory.EMPTY_ITEM, "材料变化后不会自动显示输出")
		_expect(not isolated.craft_once(), "未点击预览时不能直接合成")
		var matches := isolated.preview_all_recipes()
		_expect(matches.size() == 1 and matches[0].id == &"log_to_planks", "木头位于格%d时预览返回木板配方" % position)
		_expect(isolated.output_item() == PlayerInventory.EMPTY_ITEM, "仅生成候选时尚未选定成品")
		_expect(isolated.select_preview(0), "点击木板候选后完成选择")
		_expect(isolated.output_item() == VoxelWorld.PLANKS and isolated.output_amount() == 4, "选择后显示4个木板")
		_expect(isolated.craft_once(), "选择后木头配方可以合成")
		_expect(isolated_inventory.get_item(0) == VoxelWorld.PLANKS and isolated_inventory.get_amount(0) == 4, "木板成品进入背包")
		_expect(isolated.get_amount(position) == 0, "领取后只消耗1个木头")


func _test_extra_materials_allowed() -> void:
	var isolated_inventory := PlayerInventory.new()
	var isolated := CraftingGrid.new(isolated_inventory)
	isolated.set_slot_for_test(0, ItemCatalog.LOG, 3)
	isolated.set_slot_for_test(1, VoxelWorld.STONE, 5)
	var matches := isolated.preview_all_recipes()
	_expect(matches.size() == 1 and matches[0].id == &"log_to_planks", "存在多余或无关材料时仍按总数量匹配")
	_expect(isolated.select_preview(0) and isolated.craft_once(), "有额外材料时仍可制作木板")
	_expect(isolated_inventory.count_item(VoxelWorld.PLANKS) == 4, "额外材料场景正确产出4个木板")
	_expect(isolated.get_item(0) == ItemCatalog.LOG and isolated.get_amount(0) == 2, "只消耗配方需要的1个木头")
	_expect(isolated.get_item(1) == VoxelWorld.STONE and isolated.get_amount(1) == 5, "无关石头完全保留")


func _test_multiple_candidates_and_selected_result() -> void:
	var isolated_inventory := PlayerInventory.new()
	var isolated := CraftingGrid.new(isolated_inventory)
	isolated.set_slot_for_test(0, VoxelWorld.PLANKS, 8)
	isolated.set_slot_for_test(2, VoxelWorld.STONE, 3)
	var matches := isolated.preview_all_recipes()
	var table_index := _find_recipe_index(matches, &"planks_to_crafting_table")
	var bricks_index := _find_recipe_index(matches, &"planks_to_bricks")
	_expect(matches.size() == 2, "8个木板一次预览显示全部两个可制作配方")
	_expect(table_index >= 0 and bricks_index >= 0, "候选同时包含工作台和砖块")
	_expect(isolated.output_item() == PlayerInventory.EMPTY_ITEM, "多候选出现后必须由玩家选择")
	_expect(isolated.select_preview(bricks_index), "可选择第二个砖块候选")
	_expect(isolated.selected_recipe_id() == &"planks_to_bricks", "运行时记录玩家选择的配方")
	_expect(isolated.output_item() == VoxelWorld.BRICKS and isolated.output_amount() == 2, "选择砖块后只预览砖块成品")
	_expect(isolated.craft_once(), "所选砖块配方合成成功")
	_expect(isolated_inventory.count_item(VoxelWorld.BRICKS) == 2, "只产出所选配方的2个砖块")
	_expect(isolated_inventory.count_item(ItemCatalog.CRAFTING_TABLE) == 0, "未同时产出另一个工作台候选")
	_expect(isolated.get_item(0) == VoxelWorld.PLANKS and isolated.get_amount(0) == 4, "只扣除砖块配方需要的4个木板")
	_expect(isolated.get_item(2) == VoxelWorld.STONE and isolated.get_amount(2) == 3, "多候选合成不消耗无关石头")
	_expect(not isolated.has_preview() and isolated.preview_recipes.is_empty(), "合成后清空旧候选和选择")


func _test_preview_invalidation() -> void:
	var isolated := CraftingGrid.new(PlayerInventory.new())
	isolated.set_slot_for_test(0, VoxelWorld.PLANKS, 4)
	var matches := isolated.preview_all_recipes()
	_expect(matches.size() == 2, "材料足够时生成两个候选")
	_expect(isolated.select_preview(0), "可选择第一个候选")
	isolated.set_slot_for_test(1, VoxelWorld.STONE, 1)
	_expect(isolated.preview_recipes.is_empty(), "材料变化后候选列表失效")
	_expect(not isolated.has_preview() and isolated.output_item() == PlayerInventory.EMPTY_ITEM, "材料变化后已选成品同步失效")
	_expect(not isolated.craft_once(), "失效的旧选择不能继续合成")


func _test_click_movement_and_repeat() -> void:
	var isolated_inventory := PlayerInventory.new()
	isolated_inventory.set_slot(7, ItemCatalog.LOG, 2)
	var isolated := CraftingGrid.new(isolated_inventory)
	_expect(isolated.move_one_from_inventory(7, 3), "点击流程可从背包移入1个材料")
	_expect(isolated_inventory.get_amount(7) == 1 and isolated.get_amount(3) == 1, "移动时背包与合成格数量同步")
	_expect(isolated.preview_recipe() and isolated.craft_once(), "兼容接口可预览并完成第一次木头合成")
	_expect(isolated.move_one_from_inventory(7, 3), "可继续移入第二个木头")
	_expect(isolated.preview_recipe() and isolated.craft_once(), "重新预览后第二次木头合成成功")
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
	var matches := isolated.preview_all_recipes()
	_expect(matches.size() == 1 and isolated.select_preview(0), "满包时仍可预览并选择正确配方")
	_expect(not isolated.craft_once(), "背包无法容纳完整输出时拒绝合成")
	_expect(isolated.get_item(0) == ItemCatalog.LOG and isolated.get_amount(0) == 1, "拒绝合成不会消耗材料")
	_expect(isolated.has_preview(), "容量不足不会丢失当前选择，清理空间后可重试")


func _test_hud_candidate_buttons() -> void:
	crafting.set_slot_for_test(0, VoxelWorld.PLANKS, 4)
	hud._on_preview_pressed()
	_expect(hud.recipe_candidate_buttons.size() == 2, "HUD一次显示两个可制作候选按钮")
	_expect(hud.crafting_status.text == "可制作 2 种，请点击选择", "HUD提示可制作配方数量")
	hud._on_recipe_candidate_pressed(1)
	_expect(crafting.output_item() == VoxelWorld.BRICKS, "点击第二个候选后输出格只显示砖块")
	_expect(not hud.craft_button.disabled, "选择候选后启用合成按钮")


func _find_recipe_index(recipes: Array[CraftingRecipe], recipe_id: StringName) -> int:
	for index: int in range(recipes.size()):
		if recipes[index].id == recipe_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
