class_name CraftingGrid
extends RefCounted

signal grid_changed
signal preview_changed(recipes: Array[CraftingRecipe])
signal output_changed(item_id: int, amount: int)
signal crafted(item_id: int, amount: int)

const GRID_SIZE := 4
const EMPTY := PlayerInventory.EMPTY_ITEM

var inventory: PlayerInventory
var recipe_book := RecipeBook.new()
var item_ids := PackedInt32Array()
var amounts := PackedInt32Array()
var preview_recipes: Array[CraftingRecipe] = []
var previewed_recipe: CraftingRecipe


func _init(player_inventory: PlayerInventory) -> void:
	inventory = player_inventory
	item_ids.resize(GRID_SIZE)
	amounts.resize(GRID_SIZE)
	for index: int in range(GRID_SIZE):
		item_ids[index] = EMPTY
		amounts[index] = 0


func get_item(index: int) -> int:
	return item_ids[index] if index >= 0 and index < GRID_SIZE else EMPTY


func get_amount(index: int) -> int:
	return amounts[index] if index >= 0 and index < GRID_SIZE else 0


func total_material_count() -> int:
	var total := 0
	for amount: int in amounts:
		total += amount
	return total


func output_item() -> int:
	return previewed_recipe.result_item if previewed_recipe != null else EMPTY


func output_amount() -> int:
	return previewed_recipe.result_amount if previewed_recipe != null else 0


func has_preview() -> bool:
	return previewed_recipe != null


func preview_all_recipes() -> Array[CraftingRecipe]:
	preview_recipes = recipe_book.find_matches(_available_item_counts())
	previewed_recipe = null
	preview_changed.emit(preview_recipes)
	output_changed.emit(EMPTY, 0)
	return preview_recipes


func preview_recipe() -> bool:
	# 保留简便接口：找到候选后默认选择第一项；UI使用 preview_all_recipes + select_preview。
	preview_all_recipes()
	return select_preview(0)


func select_preview(index: int) -> bool:
	if index < 0 or index >= preview_recipes.size():
		previewed_recipe = null
		output_changed.emit(EMPTY, 0)
		return false
	previewed_recipe = preview_recipes[index]
	output_changed.emit(output_item(), output_amount())
	return true


func selected_recipe_id() -> StringName:
	return previewed_recipe.id if previewed_recipe != null else &""


func move_one_from_inventory(inventory_slot: int, grid_slot: int) -> bool:
	if grid_slot < 0 or grid_slot >= GRID_SIZE or inventory.is_empty(inventory_slot):
		return false
	var item_id := inventory.get_item(inventory_slot)
	if item_ids[grid_slot] != EMPTY and item_ids[grid_slot] != item_id:
		return false
	if amounts[grid_slot] >= ItemCatalog.stack_limit(item_id):
		return false
	if not inventory.remove_from_slot(inventory_slot, 1):
		return false
	item_ids[grid_slot] = item_id
	amounts[grid_slot] += 1
	_invalidate_preview()
	grid_changed.emit()
	return true


func return_one_to_inventory(grid_slot: int) -> bool:
	if grid_slot < 0 or grid_slot >= GRID_SIZE or amounts[grid_slot] <= 0:
		return false
	var item_id := item_ids[grid_slot]
	if not inventory.can_add(item_id, 1):
		return false
	var remaining := inventory.add_item(item_id, 1)
	if remaining != 0:
		return false
	amounts[grid_slot] -= 1
	if amounts[grid_slot] == 0:
		item_ids[grid_slot] = EMPTY
	_invalidate_preview()
	grid_changed.emit()
	return true


func set_slot_for_test(index: int, item_id: int, amount: int) -> void:
	if index < 0 or index >= GRID_SIZE:
		return
	item_ids[index] = item_id if amount > 0 else EMPTY
	amounts[index] = maxi(0, amount)
	_invalidate_preview()
	grid_changed.emit()


func craft_once() -> bool:
	if previewed_recipe == null:
		return false
	var selected_id := previewed_recipe.id
	var current_matches := recipe_book.find_matches(_available_item_counts())
	var current_recipe: CraftingRecipe
	for recipe: CraftingRecipe in current_matches:
		if recipe.id == selected_id:
			current_recipe = recipe
			break
	if current_recipe == null:
		_invalidate_preview()
		return false
	var result_item := current_recipe.result_item
	var result_amount := current_recipe.result_amount
	if not inventory.can_add(result_item, result_amount):
		return false
	_consume_recipe(current_recipe)
	var remaining := inventory.add_item(result_item, result_amount)
	assert(remaining == 0, "容量预检通过后合成结果应完整进入背包")
	crafted.emit(result_item, result_amount)
	_invalidate_preview()
	grid_changed.emit()
	return true


func return_all_to_inventory() -> bool:
	for index: int in range(GRID_SIZE):
		if amounts[index] > 0 and not inventory.can_add(item_ids[index], amounts[index]):
			return false
	for index: int in range(GRID_SIZE):
		if amounts[index] <= 0:
			continue
		var remaining := inventory.add_item(item_ids[index], amounts[index])
		assert(remaining == 0)
		item_ids[index] = EMPTY
		amounts[index] = 0
	_invalidate_preview()
	grid_changed.emit()
	return true


func _available_item_counts() -> Dictionary:
	var available := {}
	for index: int in range(GRID_SIZE):
		if item_ids[index] == EMPTY or amounts[index] <= 0:
			continue
		available[item_ids[index]] = (available.get(item_ids[index], 0) as int) + amounts[index]
	return available


func _consume_recipe(recipe: CraftingRecipe) -> void:
	for required_item: int in recipe.required_items:
		var remaining: int = recipe.required_items[required_item] as int
		for index: int in range(GRID_SIZE):
			if item_ids[index] != required_item or remaining <= 0:
				continue
			var consumed := mini(amounts[index], remaining)
			amounts[index] -= consumed
			remaining -= consumed
			if amounts[index] == 0:
				item_ids[index] = EMPTY
		assert(remaining == 0, "匹配成功的配方必须能完整扣除材料")


func _invalidate_preview() -> void:
	var had_state := previewed_recipe != null or not preview_recipes.is_empty()
	previewed_recipe = null
	preview_recipes.clear()
	if had_state:
		preview_changed.emit(preview_recipes)
		output_changed.emit(EMPTY, 0)
