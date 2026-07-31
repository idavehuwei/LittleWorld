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
	]


func find_match(grid: PackedInt32Array) -> CraftingRecipe:
	assert(grid.size() == 4, "2x2合成网格必须包含4格")
	for recipe: CraftingRecipe in recipes:
		if _matches_recipe(grid, recipe):
			return recipe
	return null


func _matches_recipe(grid: PackedInt32Array, recipe: CraftingRecipe) -> bool:
	# 有形配方允许在2x2网格内平移；1x1木头因此可以放在任一格。
	for offset_y: int in range(3 - recipe.height):
		for offset_x: int in range(3 - recipe.width):
			if _matches_at(grid, recipe, offset_x, offset_y):
				return true
	return false


func _matches_at(grid: PackedInt32Array, recipe: CraftingRecipe, offset_x: int, offset_y: int) -> bool:
	for grid_y: int in range(2):
		for grid_x: int in range(2):
			var expected := EMPTY
			var recipe_x := grid_x - offset_x
			var recipe_y := grid_y - offset_y
			if recipe_x >= 0 and recipe_x < recipe.width and recipe_y >= 0 and recipe_y < recipe.height:
				expected = recipe.pattern[recipe_y * recipe.width + recipe_x]
			if grid[grid_y * 2 + grid_x] != expected:
				return false
	return true
