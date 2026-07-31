class_name VoxelWorld
extends GridMap

signal block_changed(cell: Vector3i, previous_type: int, new_type: int)

const AIR := -1
const GRASS := 0
const DIRT := 1
const STONE := 2
const PLANKS := 3
const BRICKS := 4
const LEAVES := 5
const FLOWER := 6
# 原木沿用背包/合成系统既有 ID，破坏树干后可直接参与“木头→木板”配方。
const LOG := 100

const WORLD_WIDTH := 250
const WORLD_DEPTH := 250
const BLOCK_SIZE := 1.0
const WORLD_COLLISION_LAYER := 1
const MIN_SURFACE_HEIGHT := -3
const MAX_SURFACE_HEIGHT := 5
const WORLD_BOTTOM_Y := -8
const TERRAIN_SEED := 20260731
const TERRAIN_FREQUENCY := 0.018
const SPAWN_POINT := Vector2i(0, 5)
const SPAWN_FLAT_RADIUS := 10.0
const SPAWN_BLEND_RADIUS := 18.0
const SPAWN_SURFACE_HEIGHT := 0
const DECORATION_SAFE_RADIUS := 18.0
const TREE_CHANCE := 0.0014
const FLOWER_CHANCE := 0.007

const BLOCK_NAMES := {
	GRASS: "草方块",
	DIRT: "泥土",
	STONE: "石头",
	PLANKS: "木板",
	BRICKS: "砖块",
	LOG: "原木",
	LEAVES: "树叶",
	FLOWER: "花朵",
}

const BLOCK_COLORS := {
	GRASS: Color("67ad42"),
	DIRT: Color("8a5a36"),
	STONE: Color("8a9098"),
	PLANKS: Color("c98b4b"),
	BRICKS: Color("b5523b"),
	LOG: Color("9b6436"),
	LEAVES: Color("4f963d"),
	FLOWER: Color("f5d95c"),
}

const BLOCK_TEXTURE_PATHS := {
	GRASS: "res://assets/textures/blocks/grass.png",
	DIRT: "res://assets/textures/blocks/dirt.png",
	STONE: "res://assets/textures/blocks/stone.png",
	PLANKS: "res://assets/textures/blocks/planks.png",
	BRICKS: "res://assets/textures/blocks/bricks.png",
	LOG: "res://assets/textures/blocks/log.png",
	LEAVES: "res://assets/textures/blocks/leaves.png",
	FLOWER: "res://assets/textures/blocks/flower.png",
}

var highlight: MeshInstance3D
var terrain_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var height_map := PackedInt32Array()
var generated_tree_count := 0
var generated_flower_count := 0
var tree_origins: Array[Vector3i] = []
var flower_cells: Array[Vector3i] = []


func _ready() -> void:
	cell_size = Vector3.ONE * BLOCK_SIZE
	# GridMap 默认开启 cell_center_y，cell y=0 的中心位于 y=0.5。
	mesh_library = _create_block_library()
	collision_layer = WORLD_COLLISION_LAYER
	collision_mask = 0
	_configure_noise()
	_create_highlight()


func build_initial_world() -> void:
	build_natural_world(WORLD_WIDTH, WORLD_DEPTH)


func build_natural_world(width: int, depth: int) -> void:
	clear()
	generated_tree_count = 0
	generated_flower_count = 0
	tree_origins.clear()
	flower_cells.clear()
	_generate_height_map(width, depth)
	_fill_terrain_layers(width, depth)
	_scatter_natural_decorations(width, depth)


func build_flat_world(width: int, depth: int) -> void:
	# 保留用于独立测试或特殊地图的平地构建入口。
	clear()
	height_map.resize(width * depth)
	height_map.fill(0)
	var start_x: int = -width / 2
	var start_z: int = -depth / 2
	for x: int in range(start_x, start_x + width):
		for z: int in range(start_z, start_z + depth):
			set_cell_item(Vector3i(x, 0, z), GRASS)


func get_surface_height(x: int, z: int) -> int:
	var start_x: int = -WORLD_WIDTH / 2
	var start_z: int = -WORLD_DEPTH / 2
	var local_x := x - start_x
	var local_z := z - start_z
	if local_x < 0 or local_x >= WORLD_WIDTH or local_z < 0 or local_z >= WORLD_DEPTH:
		return MIN_SURFACE_HEIGHT - 1
	var index := local_z * WORLD_WIDTH + local_x
	if index < 0 or index >= height_map.size():
		return MIN_SURFACE_HEIGHT - 1
	return height_map[index]


func spawn_world_position() -> Vector3:
	var surface_y := get_surface_height(SPAWN_POINT.x, SPAWN_POINT.y)
	return Vector3(SPAWN_POINT.x + 0.5, surface_y + 2.0, SPAWN_POINT.y + 0.5)


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


func _configure_noise() -> void:
	terrain_noise.seed = TERRAIN_SEED
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = TERRAIN_FREQUENCY
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_lacunarity = 2.0
	terrain_noise.fractal_gain = 0.5

	detail_noise.seed = TERRAIN_SEED + 9173
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.frequency = 0.085
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 2


func _generate_height_map(width: int, depth: int) -> void:
	height_map.resize(width * depth)
	var start_x: int = -width / 2
	var start_z: int = -depth / 2
	for local_z: int in range(depth):
		var z := start_z + local_z
		for local_x: int in range(width):
			var x := start_x + local_x
			var noise_value := terrain_noise.get_noise_2d(float(x), float(z))
			var normalized := clampf((noise_value + 1.0) * 0.5, 0.0, 1.0)
			var raw_height := roundi(lerpf(float(MIN_SURFACE_HEIGHT), float(MAX_SURFACE_HEIGHT), normalized))
			var distance := Vector2(float(x - SPAWN_POINT.x), float(z - SPAWN_POINT.y)).length()
			var blend := smoothstep(SPAWN_FLAT_RADIUS, SPAWN_BLEND_RADIUS, distance)
			var final_height := roundi(lerpf(float(SPAWN_SURFACE_HEIGHT), float(raw_height), blend))
			height_map[local_z * width + local_x] = clampi(final_height, MIN_SURFACE_HEIGHT, MAX_SURFACE_HEIGHT)


func _fill_terrain_layers(width: int, depth: int) -> void:
	var start_x: int = -width / 2
	var start_z: int = -depth / 2
	for local_z: int in range(depth):
		var z := start_z + local_z
		for local_x: int in range(width):
			var x := start_x + local_x
			var surface_y := height_map[local_z * width + local_x]
			var dirt_depth := _dirt_depth_at(x, z)
			set_cell_item(Vector3i(x, surface_y, z), GRASS)
			for layer: int in range(1, dirt_depth + 1):
				set_cell_item(Vector3i(x, surface_y - layer, z), DIRT)
			for y: int in range(surface_y - dirt_depth - 1, WORLD_BOTTOM_Y - 1, -1):
				set_cell_item(Vector3i(x, y, z), STONE)


func _dirt_depth_at(x: int, z: int) -> int:
	var detail := detail_noise.get_noise_2d(float(x), float(z))
	return clampi(2 + roundi(detail), 1, 3)


func _scatter_natural_decorations(width: int, depth: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TERRAIN_SEED + 44021
	var start_x: int = -width / 2
	var start_z: int = -depth / 2
	for z: int in range(start_z + 3, start_z + depth - 3):
		for x: int in range(start_x + 3, start_x + width - 3):
			var distance := Vector2(float(x - SPAWN_POINT.x), float(z - SPAWN_POINT.y)).length()
			if distance <= DECORATION_SAFE_RADIUS:
				continue
			var roll := rng.randf()
			if roll < TREE_CHANCE and _can_grow_tree(x, z):
				_build_tree(x, z, rng.randi_range(3, 5))
			elif roll < TREE_CHANCE + FLOWER_CHANCE and _can_place_flower(x, z):
				_place_flower(x, z)


func _can_grow_tree(x: int, z: int) -> bool:
	var center_height := get_surface_height(x, z)
	for offset_z: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if absi(get_surface_height(x + offset_x, z + offset_z) - center_height) > 1:
				return false
			if has_block(Vector3i(x + offset_x, center_height + 1, z + offset_z)):
				return false
	return true


func _can_place_flower(x: int, z: int) -> bool:
	var surface_y := get_surface_height(x, z)
	return get_block(Vector3i(x, surface_y, z)) == GRASS and not has_block(Vector3i(x, surface_y + 1, z))


func _build_tree(x: int, z: int, trunk_height: int) -> void:
	var surface_y := get_surface_height(x, z)
	var trunk_top := surface_y + trunk_height
	for y: int in range(surface_y + 1, trunk_top + 1):
		set_cell_item(Vector3i(x, y, z), LOG)
	# 树冠主体为两层 3×3，顶部再加十字形叶片，形成比 3×3 更饱满的轮廓。
	for y: int in range(trunk_top, trunk_top + 2):
		for offset_z: int in range(-1, 2):
			for offset_x: int in range(-1, 2):
				var cell := Vector3i(x + offset_x, y, z + offset_z)
				if get_block(cell) == AIR:
					set_cell_item(cell, LEAVES)
	var crown_y := trunk_top + 2
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		set_cell_item(Vector3i(x + offset.x, crown_y, z + offset.y), LEAVES)
	tree_origins.append(Vector3i(x, surface_y + 1, z))
	generated_tree_count += 1


func _place_flower(x: int, z: int) -> void:
	var cell := Vector3i(x, get_surface_height(x, z) + 1, z)
	set_cell_item(cell, FLOWER)
	flower_cells.append(cell)
	generated_flower_count += 1


func _create_block_library() -> MeshLibrary:
	var library := MeshLibrary.new()
	for block_id: int in BLOCK_NAMES.keys():
		library.create_item(block_id)
		library.set_item_name(block_id, BLOCK_NAMES[block_id] as String)
		var material := _create_block_material(block_id)
		if block_id == FLOWER:
			library.set_item_mesh(block_id, _create_cross_plant_mesh(material))
			# 花朵使用无碰撞十字面，玩家可自然穿过；树木与地形保持实体碰撞。
			library.set_item_shapes(block_id, [])
		else:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			cube.material = material
			library.set_item_mesh(block_id, cube)
			var shape := BoxShape3D.new()
			shape.size = Vector3.ONE
			library.set_item_shapes(block_id, [shape, Transform3D.IDENTITY])
	return library


func _create_block_material(block_type: int) -> StandardMaterial3D:
	var texture_path: String = BLOCK_TEXTURE_PATHS[block_type] as String
	var texture := load(texture_path) as Texture2D
	assert(texture != null, "无法加载方块纹理: %s" % texture_path)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.92
	if block_type == FLOWER:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.35
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _create_cross_plant_mesh(material: Material) -> ArrayMesh:
	var half_width := 0.34
	var bottom := -0.5
	var top := 0.34
	var vertices := PackedVector3Array([
		Vector3(-half_width, bottom, 0.0), Vector3(half_width, bottom, 0.0), Vector3(half_width, top, 0.0),
		Vector3(-half_width, bottom, 0.0), Vector3(half_width, top, 0.0), Vector3(-half_width, top, 0.0),
		Vector3(0.0, bottom, -half_width), Vector3(0.0, bottom, half_width), Vector3(0.0, top, half_width),
		Vector3(0.0, bottom, -half_width), Vector3(0.0, top, half_width), Vector3(0.0, top, -half_width),
	])
	var uvs := PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0),
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


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
