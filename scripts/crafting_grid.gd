class_name CraftingGrid
extends RefCounted

signal grid_changed
signal output_changed(item_id: int, amount: int)
signal crafted(item_id: int, amount: int)

const GRID_SIZE := 4
const EMPTY := PlayerInventory.EMPTY_ITEM

var inventory: PlayerInventory
var recipe_book := RecipeBook.new()
var item_ids := PackedInt32Array()
var amounts := PackedInt32Array()
var matched_recipe: CraftingRecipe


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


func output_item() -> int:
	return matched_recipe.result_item if matched_recipe != null else EMPTY


func output_amount() -> int:
	return matched_recipe.result_amount if matched_recipe != null else 0


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
	_refresh_match()
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
	_refresh_match()
	return true


func set_slot_for_test(index: int, item_id: int, amount: int) -> void:
	if index < 0 or index >= GRID_SIZE:
		return
	item_ids[index] = item_id if amount > 0 else EMPTY
	amounts[index] = maxi(0, amount)
	_refresh_match()


func craft_once() -> bool:
	if matched_recipe == null:
		return false
	var result_item := matched_recipe.result_item
	var result_amount := matched_recipe.result_amount
	# 先验证输出可完整进入背包，再扣材料，保证合成是原子操作。
	if not inventory.can_add(result_item, result_amount):
		return false
	if not _can_consume_match():
		_refresh_match()
		return false
	_consume_matched_recipe()
	var remaining := inventory.add_item(result_item, result_amount)
	assert(remaining == 0, "容量预检通过后合成结果应完整进入背包")
	crafted.emit(result_item, result_amount)
	_refresh_match()
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
	_refresh_match()
	return true


func _grid_item_pattern() -> PackedInt32Array:
	var pattern := PackedInt32Array()
	pattern.resize(GRID_SIZE)
	for index: int in range(GRID_SIZE):
		pattern[index] = item_ids[index] if amounts[index] > 0 else EMPTY
	return pattern


func _refresh_match() -> void:
	var previous_item := output_item()
	var previous_amount := output_amount()
	matched_recipe = recipe_book.find_match(_grid_item_pattern())
	grid_changed.emit()
	if previous_item != output_item() or previous_amount != output_amount():
		output_changed.emit(output_item(), output_amount())


func _can_consume_match() -> bool:
	if matched_recipe == null:
		return false
	var pattern := _grid_item_pattern()
	if not recipe_book._matches_recipe(pattern, matched_recipe):
		return false
	for index: int in range(GRID_SIZE):
		if pattern[index] != EMPTY and amounts[index] < 1:
			return false
	return true


func _consume_matched_recipe() -> void:
	# 当前两张配方每个占用格消耗1个；未来配方若支持单格数量，可把pattern升级为Ingredient数组。
	var pattern := _grid_item_pattern()
	for index: int in range(GRID_SIZE):
		if pattern[index] == EMPTY:
			continue
		amounts[index] -= 1
		if amounts[index] == 0:
			item_ids[index] = EMPTY
