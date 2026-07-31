class_name PlayerInventory
extends RefCounted

signal slot_changed(index: int)
signal inventory_changed
signal selection_changed(index: int)

const SLOT_COUNT := 36
const HOTBAR_SIZE := 9
const EMPTY_ITEM := VoxelWorld.AIR

var item_ids := PackedInt32Array()
var amounts := PackedInt32Array()
var selected_hotbar_index := 0


func _init() -> void:
	item_ids.resize(SLOT_COUNT)
	amounts.resize(SLOT_COUNT)
	for index: int in range(SLOT_COUNT):
		item_ids[index] = EMPTY_ITEM
		amounts[index] = 0


func seed_demo_items() -> void:
	var starter_items: Array[int] = [
		VoxelWorld.GRASS,
		VoxelWorld.DIRT,
		VoxelWorld.STONE,
		VoxelWorld.PLANKS,
		VoxelWorld.BRICKS,
	]
	for index: int in range(starter_items.size()):
		set_slot(index, starter_items[index], ItemCatalog.MAX_STACK)
	set_slot(5, ItemCatalog.LOG, 8)


func is_valid_slot(index: int) -> bool:
	return index >= 0 and index < SLOT_COUNT


func is_empty(index: int) -> bool:
	return not is_valid_slot(index) or item_ids[index] == EMPTY_ITEM or amounts[index] <= 0


func get_item(index: int) -> int:
	return item_ids[index] if is_valid_slot(index) else EMPTY_ITEM


func get_amount(index: int) -> int:
	return amounts[index] if is_valid_slot(index) else 0


func selected_item() -> int:
	return get_item(selected_hotbar_index)


func selected_amount() -> int:
	return get_amount(selected_hotbar_index)


func count_item(item_id: int) -> int:
	var total := 0
	for index: int in range(SLOT_COUNT):
		if item_ids[index] == item_id:
			total += amounts[index]
	return total


func set_slot(index: int, item_id: int, amount: int) -> bool:
	if not is_valid_slot(index):
		return false
	if amount <= 0 or item_id == EMPTY_ITEM:
		item_ids[index] = EMPTY_ITEM
		amounts[index] = 0
	else:
		if not ItemCatalog.is_valid_item(item_id):
			return false
		item_ids[index] = item_id
		amounts[index] = mini(amount, ItemCatalog.stack_limit(item_id))
	_emit_slot_change(index)
	return true


func can_add(item_id: int, amount: int = 1) -> bool:
	if not ItemCatalog.is_valid_item(item_id) or amount <= 0:
		return false
	var remaining := amount
	var stack_limit := ItemCatalog.stack_limit(item_id)
	for index: int in range(SLOT_COUNT):
		if item_ids[index] == item_id:
			remaining -= maxi(0, stack_limit - amounts[index])
			if remaining <= 0:
				return true
	for index: int in range(SLOT_COUNT):
		if is_empty(index):
			remaining -= stack_limit
			if remaining <= 0:
				return true
	return false


func add_item(item_id: int, amount: int = 1) -> int:
	if not ItemCatalog.is_valid_item(item_id) or amount <= 0:
		return amount
	var remaining := amount
	var changed_indices: Array[int] = []
	var stack_limit := ItemCatalog.stack_limit(item_id)
	# 先填充已有同类堆栈，避免无谓占用新格子。
	for index: int in range(SLOT_COUNT):
		if item_ids[index] != item_id or amounts[index] >= stack_limit:
			continue
		var moved := mini(remaining, stack_limit - amounts[index])
		amounts[index] += moved
		remaining -= moved
		changed_indices.append(index)
		if remaining == 0:
			break
	# 再按槽位顺序使用空格。
	if remaining > 0:
		for index: int in range(SLOT_COUNT):
			if not is_empty(index):
				continue
			var moved := mini(remaining, stack_limit)
			item_ids[index] = item_id
			amounts[index] = moved
			remaining -= moved
			changed_indices.append(index)
			if remaining == 0:
				break
	_emit_multiple_slot_changes(changed_indices)
	return remaining


func remove_from_slot(index: int, amount: int = 1) -> bool:
	if not is_valid_slot(index) or amount <= 0 or amounts[index] < amount:
		return false
	amounts[index] -= amount
	if amounts[index] == 0:
		item_ids[index] = EMPTY_ITEM
	_emit_slot_change(index)
	return true


func swap_slots(first: int, second: int) -> bool:
	if not is_valid_slot(first) or not is_valid_slot(second):
		return false
	if first == second:
		return true
	var first_item := item_ids[first]
	var first_amount := amounts[first]
	item_ids[first] = item_ids[second]
	amounts[first] = amounts[second]
	item_ids[second] = first_item
	amounts[second] = first_amount
	_emit_multiple_slot_changes([first, second])
	return true


func select_hotbar(index: int) -> bool:
	if index < 0 or index >= HOTBAR_SIZE:
		return false
	if selected_hotbar_index == index:
		return true
	selected_hotbar_index = index
	selection_changed.emit(index)
	return true


func cycle_hotbar(step: int) -> void:
	select_hotbar(posmod(selected_hotbar_index + step, HOTBAR_SIZE))


func serialize_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for index: int in range(SLOT_COUNT):
		slots.append({"item": item_ids[index], "amount": amounts[index]})
	return slots


func restore_slots(slots: Array, selected_index: int) -> void:
	for index: int in range(SLOT_COUNT):
		var item_id := EMPTY_ITEM
		var amount := 0
		if index < slots.size() and slots[index] is Dictionary:
			var slot := slots[index] as Dictionary
			item_id = int(slot.get("item", EMPTY_ITEM))
			amount = int(slot.get("amount", 0))
		if amount > 0 and ItemCatalog.is_valid_item(item_id):
			item_ids[index] = item_id
			amounts[index] = mini(amount, ItemCatalog.stack_limit(item_id))
		else:
			item_ids[index] = EMPTY_ITEM
			amounts[index] = 0
		slot_changed.emit(index)
	selected_hotbar_index = clampi(selected_index, 0, HOTBAR_SIZE - 1)
	selection_changed.emit(selected_hotbar_index)
	inventory_changed.emit()


func clear() -> void:
	for index: int in range(SLOT_COUNT):
		item_ids[index] = EMPTY_ITEM
		amounts[index] = 0
		slot_changed.emit(index)
	inventory_changed.emit()


func _emit_slot_change(index: int) -> void:
	slot_changed.emit(index)
	inventory_changed.emit()


func _emit_multiple_slot_changes(indices: Array[int]) -> void:
	if indices.is_empty():
		return
	for index: int in indices:
		slot_changed.emit(index)
	inventory_changed.emit()
