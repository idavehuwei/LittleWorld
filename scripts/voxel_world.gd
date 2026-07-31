class_name VoxelWorld
extends GridMap

signal block_changed(cell: Vector3i, previous_type: int, new_type: int)

const AIR := -1
const GRASS := 0
const DIRT := 1
const STONE := 2
const PLANKS := 3
const BRICKS := 4

const WORLD_WIDTH := 250
const WORLD_DEPTH := 250
const BLOCK_SIZE := 1.0
const GROUND_CELL_Y := 0
const WORLD_COLLISION_LAYER := 1

const BLOCK_NAMES := {
	GRASS: "草方块",
	DIRT: "泥土",
	STONE: "石头",
	PLANKS: "木板",
	BRICKS: "砖块",
}

const BLOCK_COLORS := {
	GRASS: Color("67ad42"),
	DIRT: Color("8a5a36"),
	STONE: Color("8a9098"),
	PLANKS: Color("c98b4b"),
	BRICKS: Color("b5523b"),
}

var highlight: MeshInstance3D


func _ready() -> void:
	cell_size = Vector3.ONE * BLOCK_SIZE
	# GridMap 默认开启 cell_center_y，cell y=0 的中心会自动位于 y=0.5，
	# 因此 1 米方块无需移动就严格占据世界空间 y=0 到 y=1。
	mesh_library = _create_block_library()
	collision_layer = WORLD_COLLISION_LAYER
	collision_mask = 0
	_create_highlight()


func build_initial_world() -> void:
	build_flat_world(WORLD_WIDTH, WORLD_DEPTH)


func build_flat_world(width: int, depth: int) -> void:
	clear()
	var start_x: int = -width / 2
	var start_z: int = -depth / 2
	for x: int in range(start_x, start_x + width):
		for z: int in range(start_z, start_z + depth):
			set_cell_item(Vector3i(x, GROUND_CELL_Y, z), GRASS)


func get_block(cell: Vector3i) -> int:
	return get_cell_item(cell)


func has_block(cell: Vector3i) -> bool:
	return get_block(cell) != AIR


func set_block(cell: Vector3i, block_type: int) -> bool:
	if block_type != AIR and not BLOCK_NAMES.has(block_type):
		return false
	var previous_type := get_block(cell)
	if previous_type == block_type:
		return false
	set_cell_item(cell, block_type)
	block_changed.emit(cell, previous_type, block_type)
	return true


func remove_block(cell: Vector3i) -> bool:
	if not has_block(cell):
		return false
	return set_block(cell, AIR)


func place_block(cell: Vector3i, block_type: int) -> bool:
	if has_block(cell):
		return false
	return set_block(cell, block_type)


func set_highlight(cell: Vector3i, visible: bool) -> void:
	highlight.visible = visible
	if visible:
		highlight.position = map_to_local(cell)


func block_name(block_type: int) -> String:
	return BLOCK_NAMES.get(block_type, "未知") as String


func block_color(block_type: int) -> Color:
	return BLOCK_COLORS.get(block_type, Color.WHITE) as Color


func _create_block_library() -> MeshLibrary:
	var library := MeshLibrary.new()
	for block_id: int in BLOCK_NAMES.keys():
		library.create_item(block_id)
		library.set_item_name(block_id, BLOCK_NAMES[block_id] as String)
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		cube.material = _create_block_material(block_id)
		library.set_item_mesh(block_id, cube)
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE
		library.set_item_shapes(block_id, [shape, Transform3D.IDENTITY])
	return library


func _create_block_material(block_type: int) -> StandardMaterial3D:
	var base_color: Color = BLOCK_COLORS[block_type] as Color
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y: int in range(16):
		for x: int in range(16):
			var checker: float = 0.90 if ((x / 4 + y / 4) as int) % 2 == 0 else 1.08
			var noise: float = 0.96 + float((x * 13 + y * 7 + block_type * 11) % 9) / 100.0
			var color := Color(
				clampf(base_color.r * checker * noise, 0.0, 1.0),
				clampf(base_color.g * checker * noise, 0.0, 1.0),
				clampf(base_color.b * checker * noise, 0.0, 1.0),
				1.0
			)
			if block_type == PLANKS and y % 5 == 0:
				color = color.darkened(0.20)
			if block_type == BRICKS:
				var mortar_row := y % 6 == 0
				var row_offset := 4 if (y / 6 as int) % 2 == 1 else 0
				var mortar_column := (x + row_offset) % 8 == 0
				if mortar_row or mortar_column:
					color = Color("d3b09b")
			if block_type == GRASS and y > 11:
				color = color.darkened(0.10)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.92
	return material


func _create_highlight() -> void:
	highlight = MeshInstance3D.new()
	highlight.name = "BlockHighlight"
	highlight.mesh = _create_wireframe_cube_mesh()
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.visible = false
	add_child(highlight)


func _create_wireframe_cube_mesh() -> ArrayMesh:
	var half_size := BLOCK_SIZE * 0.506
	var corners := PackedVector3Array([
		Vector3(-half_size, -half_size, -half_size),
		Vector3(half_size, -half_size, -half_size),
		Vector3(half_size, half_size, -half_size),
		Vector3(-half_size, half_size, -half_size),
		Vector3(-half_size, -half_size, half_size),
		Vector3(half_size, -half_size, half_size),
		Vector3(half_size, half_size, half_size),
		Vector3(-half_size, half_size, half_size),
	])
	var edge_indices := PackedInt32Array([
		0, 1, 1, 2, 2, 3, 3, 0,
		4, 5, 5, 6, 6, 7, 7, 4,
		0, 4, 1, 5, 2, 6, 3, 7,
	])
	var line_vertices := PackedVector3Array()
	for index: int in edge_indices:
		line_vertices.append(corners[index])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = line_vertices
	var line_mesh := ArrayMesh.new()
	line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.86, 0.24, 0.88)
	material.no_depth_test = true
	line_mesh.surface_set_material(0, material)
	return line_mesh
