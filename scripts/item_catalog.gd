class_name ItemCatalog
extends RefCounted

const MAX_STACK := 64


static func is_valid_item(item_id: int) -> bool:
	return VoxelWorld.BLOCK_NAMES.has(item_id)


static func display_name(item_id: int) -> String:
	return VoxelWorld.BLOCK_NAMES.get(item_id, "未知物品") as String


static func icon_path(item_id: int) -> String:
	return VoxelWorld.BLOCK_TEXTURE_PATHS.get(item_id, "") as String


static func stack_limit(item_id: int) -> int:
	return MAX_STACK if is_valid_item(item_id) else 0
