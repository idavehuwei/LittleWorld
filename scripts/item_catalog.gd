class_name ItemCatalog
extends RefCounted

const MAX_STACK := 64
const LOG := 100
const CRAFTING_TABLE := 101

const ITEM_NAMES := {
	VoxelWorld.GRASS: "草方块",
	VoxelWorld.DIRT: "泥土",
	VoxelWorld.STONE: "石头",
	VoxelWorld.PLANKS: "木板",
	VoxelWorld.BRICKS: "砖块",
	VoxelWorld.LEAVES: "树叶",
	VoxelWorld.FLOWER: "花朵",
	LOG: "木头",
	CRAFTING_TABLE: "工作台",
}

const ITEM_ICON_PATHS := {
	VoxelWorld.GRASS: "res://assets/textures/blocks/grass.png",
	VoxelWorld.DIRT: "res://assets/textures/blocks/dirt.png",
	VoxelWorld.STONE: "res://assets/textures/blocks/stone.png",
	VoxelWorld.PLANKS: "res://assets/textures/blocks/planks.png",
	VoxelWorld.BRICKS: "res://assets/textures/blocks/bricks.png",
	VoxelWorld.LEAVES: "res://assets/textures/blocks/leaves.png",
	VoxelWorld.FLOWER: "res://assets/textures/blocks/flower.png",
	LOG: "res://assets/textures/blocks/log.png",
	CRAFTING_TABLE: "res://assets/textures/blocks/crafting_table.png",
}


static func is_valid_item(item_id: int) -> bool:
	return ITEM_NAMES.has(item_id)


static func display_name(item_id: int) -> String:
	return ITEM_NAMES.get(item_id, "未知物品") as String


static func icon_path(item_id: int) -> String:
	return ITEM_ICON_PATHS.get(item_id, "") as String


static func stack_limit(item_id: int) -> int:
	return MAX_STACK if is_valid_item(item_id) else 0
