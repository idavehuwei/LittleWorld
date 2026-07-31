class_name CraftingRecipe
extends RefCounted

var id: StringName
var width: int
var height: int
var pattern: PackedInt32Array
var result_item: int
var result_amount: int


func _init(
	recipe_id: StringName,
	recipe_width: int,
	recipe_height: int,
	recipe_pattern: PackedInt32Array,
	output_item: int,
	output_amount: int
) -> void:
	id = recipe_id
	width = recipe_width
	height = recipe_height
	pattern = recipe_pattern
	result_item = output_item
	result_amount = output_amount
	assert(pattern.size() == width * height, "配方图案尺寸与宽高不一致")
