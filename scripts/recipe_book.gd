class_name RecipeBook
extends RefCounted

const EMPTY := PlayerInventory.EMPTY_ITEM

var recipes: Array[CraftingRecipe] = []


func _init() -> void:
	recipes = [
		CraftingRecipe.new(
			&"log_to_planks",
			1,
			1,
			PackedInt32Array([ItemCatalog.LOG]),
			VoxelWorld.PLANKS,
			4
		),
		CraftingRecipe.new(
			&"planks_to_crafting_table",
			2,
			2,
			PackedInt32Array([
				VoxelWorld.PLANKS, VoxelWorld.PLANKS,
				VoxelWorld.PLANKS, VoxelWorld.PLANKS,
			]),
			ItemCatalog.CRAFTING_TABLE,
			1
		),
		# 演示同一组4个木板也可制作另一种成品，预览列表由玩家选择目标。
		CraftingRecipe.new(
			&"planks_to_bricks",
			2,
			2,
			PackedInt32Array([
				VoxelWorld.PLANKS, VoxelWorld.PLANKS,
				VoxelWorld.PLANKS, VoxelWorld.PLANKS,
			]),
			VoxelWorld.BRICKS,
			2
		),
	]


func find_matches(available_items: Dictionary) -> Array[CraftingRecipe]:
	var matches: Array[CraftingRecipe] = []
	for recipe: CraftingRecipe in recipes:
		if can_craft(recipe, available_items):
			matches.append(recipe)
	return matches


func find_by_id(recipe_id: StringName) -> CraftingRecipe:
	for recipe: CraftingRecipe in recipes:
		if recipe.id == recipe_id:
			return recipe
	return null


func can_craft(recipe: CraftingRecipe, available_items: Dictionary) -> bool:
	for item_id: int in recipe.required_items:
		var required: int = recipe.required_items[item_id] as int
		var available: int = available_items.get(item_id, 0) as int
		if available < required:
			return false
	return true
