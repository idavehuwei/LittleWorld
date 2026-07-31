class_name GameHUD
extends CanvasLayer

const SLOT_SIZE := Vector2(68.0, 68.0)
const CRAFT_SLOT_SIZE := Vector2(82.0, 82.0)
const HOTBAR_GAP := 8

var inventory: PlayerInventory
var crafting_grid: CraftingGrid
var game_audio_system: GameAudioSystem
var title_label: Label
var selected_label: Label
var crosshair: Control
var inventory_panel: PanelContainer
var inventory_title: Label
var slot_panels: Array[PanelContainer] = []
var hotbar_buttons: Array[Button] = []
var hotbar_icons: Array[TextureRect] = []
var hotbar_counts: Array[Label] = []
var inventory_buttons: Array[Button] = []
var inventory_icons: Array[TextureRect] = []
var inventory_counts: Array[Label] = []
var crafting_buttons: Array[Button] = []
var crafting_icons: Array[TextureRect] = []
var crafting_counts: Array[Label] = []
var crafting_output_button: Button
var crafting_output_icon: TextureRect
var crafting_output_count: Label
var preview_button: Button
var craft_button: Button
var crafting_status: Label
var recipe_candidates: VBoxContainer
var recipe_candidate_buttons: Array[Button] = []
var held_slot_index := -1
var master_volume_slider: HSlider
var music_volume_slider: HSlider
var sfx_volume_slider: HSlider
var volume_value_labels: Dictionary = {}


func _ready() -> void:
	assert(inventory != null, "GameHUD 需要在进入场景树前设置 inventory")
	assert(crafting_grid != null, "GameHUD 需要在进入场景树前设置 crafting_grid")
	assert(game_audio_system != null, "GameHUD 需要在进入场景树前设置 game_audio_system")
	_build_ui()
	inventory.slot_changed.connect(_on_slot_changed)
	inventory.selection_changed.connect(_on_selection_changed)
	crafting_grid.grid_changed.connect(_refresh_crafting_slots)
	crafting_grid.preview_changed.connect(_on_preview_candidates_changed)
	crafting_grid.output_changed.connect(_on_crafting_output_changed)
	refresh_all_slots()
	_refresh_crafting_slots()


func set_selected_block(block_type: int) -> void:
	if selected_label == null:
		return
	if block_type == PlayerInventory.EMPTY_ITEM:
		selected_label.text = "当前格为空"
	else:
		selected_label.text = "当前物品：%s  ×%d" % [
			ItemCatalog.display_name(block_type),
			inventory.selected_amount(),
		]
	_refresh_selection_styles()


func set_inventory_open(is_open: bool) -> void:
	inventory_panel.visible = is_open
	crosshair.visible = not is_open
	held_slot_index = -1
	inventory_title.text = "背包  ·  36 格  ·  点击物品后点击合成格放入材料" if is_open else "背包"
	_refresh_selection_styles()


func refresh_all_slots() -> void:
	for index: int in range(PlayerInventory.SLOT_COUNT):
		_refresh_slot(index)
	set_selected_block(inventory.selected_item())


func _build_ui() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_title_and_help(root)
	_build_crosshair(root)
	_build_hotbar(root)
	_build_inventory_panel(root)

	selected_label = Label.new()
	selected_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	selected_label.position = Vector2(-190, -134)
	selected_label.size = Vector2(380, 32)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.add_theme_font_size_override("font_size", 20)
	selected_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	root.add_child(selected_label)


func _build_title_and_help(root: Control) -> void:
	var title_panel := PanelContainer.new()
	title_panel.position = Vector2(20, 18)
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.06, 0.08, 0.10, 0.72)
	title_style.set_corner_radius_all(9)
	title_style.content_margin_left = 14
	title_style.content_margin_right = 14
	title_style.content_margin_top = 8
	title_style.content_margin_bottom = 8
	title_panel.add_theme_stylebox_override("panel", title_style)
	root.add_child(title_panel)
	title_label = Label.new()
	title_label.text = "哼哼的小小世界"
	title_label.add_theme_font_size_override("font_size", 22)
	title_panel.add_child(title_label)

	var help := Label.new()
	help.text = "WASD 移动  ·  空格跳跃  ·  左键破坏  ·  右键放置  ·  滚轮/1-9 切换  ·  E 背包"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	help.add_theme_constant_override("shadow_offset_x", 2)
	help.add_theme_constant_override("shadow_offset_y", 2)
	help.set_anchors_preset(Control.PRESET_CENTER_TOP)
	help.position = Vector2(-420, 22)
	help.size = Vector2(840, 32)
	root.add_child(help)


func _build_hotbar(root: Control) -> void:
	var hotbar := HBoxContainer.new()
	hotbar.name = "Hotbar"
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var width := PlayerInventory.HOTBAR_SIZE * int(SLOT_SIZE.x) + (PlayerInventory.HOTBAR_SIZE - 1) * HOTBAR_GAP
	hotbar.position = Vector2(-width * 0.5, -98)
	hotbar.add_theme_constant_override("separation", HOTBAR_GAP)
	root.add_child(hotbar)

	for index: int in range(PlayerInventory.HOTBAR_SIZE):
		var slot := _create_slot_button(index, true)
		hotbar.add_child(slot["panel"] as PanelContainer)
		slot_panels.append(slot["panel"] as PanelContainer)
		hotbar_buttons.append(slot["button"] as Button)
		hotbar_icons.append(slot["icon"] as TextureRect)
		hotbar_counts.append(slot["count"] as Label)


func _build_inventory_panel(root: Control) -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.position = Vector2(-510, -390)
	inventory_panel.custom_minimum_size = Vector2(1020, 780)
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.105, 0.085, 0.985)
	panel_style.border_color = Color(0.74, 0.62, 0.42, 0.98)
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 42
	panel_style.content_margin_right = 42
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 32
	inventory_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(inventory_panel)

	var content := VBoxContainer.new()
	# 新增音量区后收紧纵向间距，确保所有内容仍完整容纳在 1020×780 面板内。
	content.add_theme_constant_override("separation", 12)
	inventory_panel.add_child(content)
	inventory_title = Label.new()
	inventory_title.text = "背包  ·  36 格"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_title.add_theme_font_size_override("font_size", 30)
	content.add_child(inventory_title)
	_build_crafting_ui(content)
	_build_audio_settings(content)

	var separator := HSeparator.new()
	content.add_child(separator)
	var storage_label := Label.new()
	storage_label.text = "物品栏"
	storage_label.add_theme_font_size_override("font_size", 21)
	content.add_child(storage_label)

	var grid := GridContainer.new()
	grid.columns = PlayerInventory.HOTBAR_SIZE
	grid.add_theme_constant_override("h_separation", HOTBAR_GAP)
	grid.add_theme_constant_override("v_separation", HOTBAR_GAP)
	content.add_child(grid)

	# 完整背包按 9×4 排列：第一行是快捷栏，后三行是仅打开界面可见的27格。
	for index: int in range(PlayerInventory.SLOT_COUNT):
		var slot := _create_slot_button(index, false)
		grid.add_child(slot["panel"] as PanelContainer)
		inventory_buttons.append(slot["button"] as Button)
		inventory_icons.append(slot["icon"] as TextureRect)
		inventory_counts.append(slot["count"] as Label)
	inventory_panel.visible = false


func _build_audio_settings(content: VBoxContainer) -> void:
	var settings_panel := PanelContainer.new()
	settings_panel.name = "AudioSettings"
	var settings_style := StyleBoxFlat.new()
	settings_style.bg_color = Color(0.15, 0.14, 0.12, 0.96)
	settings_style.border_color = Color(0.42, 0.35, 0.25, 0.9)
	settings_style.set_border_width_all(2)
	settings_style.set_corner_radius_all(7)
	settings_style.content_margin_left = 18
	settings_style.content_margin_right = 18
	settings_style.content_margin_top = 12
	settings_style.content_margin_bottom = 12
	settings_panel.add_theme_stylebox_override("panel", settings_style)
	content.add_child(settings_panel)

	var settings_row := HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_theme_constant_override("separation", 24)
	settings_panel.add_child(settings_row)
	var heading := Label.new()
	heading.text = "音量"
	heading.add_theme_font_size_override("font_size", 21)
	settings_row.add_child(heading)
	master_volume_slider = _create_volume_control(settings_row, "主音量", &"master", game_audio_system.get_master_volume())
	music_volume_slider = _create_volume_control(settings_row, "音乐", &"music", game_audio_system.get_music_volume())
	sfx_volume_slider = _create_volume_control(settings_row, "音效", &"sfx", game_audio_system.get_sfx_volume())


func _create_volume_control(parent: HBoxContainer, label_text: String, key: StringName, initial_value: float) -> HSlider:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	parent.add_child(group)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(62, 0)
	label.add_theme_font_size_override("font_size", 17)
	group.add_child(label)
	var slider := HSlider.new()
	slider.name = "%sVolumeSlider" % label_text
	slider.custom_minimum_size = Vector2(145, 28)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_value * 100.0
	slider.value_changed.connect(_on_volume_slider_changed.bind(key))
	group.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.text = "%d%%" % roundi(slider.value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	group.add_child(value_label)
	volume_value_labels[key] = value_label
	return slider


func _on_volume_slider_changed(value: float, key: StringName) -> void:
	var linear_value := value / 100.0
	if key == &"master":
		game_audio_system.set_master_volume(linear_value)
	elif key == &"music":
		game_audio_system.set_music_volume(linear_value)
	else:
		game_audio_system.set_sfx_volume(linear_value)
	var value_label := volume_value_labels.get(key) as Label
	if value_label != null:
		value_label.text = "%d%%" % roundi(value)


func _build_crafting_ui(content: VBoxContainer) -> void:
	var workbench := PanelContainer.new()
	var workbench_style := StyleBoxFlat.new()
	workbench_style.bg_color = Color(0.22, 0.18, 0.12, 0.96)
	workbench_style.border_color = Color(0.48, 0.36, 0.21, 1.0)
	workbench_style.set_border_width_all(3)
	workbench_style.set_corner_radius_all(8)
	workbench_style.content_margin_left = 24
	workbench_style.content_margin_right = 24
	workbench_style.content_margin_top = 20
	workbench_style.content_margin_bottom = 20
	workbench.add_theme_stylebox_override("panel", workbench_style)
	content.add_child(workbench)

	var crafting_row := HBoxContainer.new()
	crafting_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crafting_row.add_theme_constant_override("separation", 28)
	workbench.add_child(crafting_row)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(220, 190)
	left_column.add_theme_constant_override("separation", 10)
	crafting_row.add_child(left_column)
	var recipe_heading := Label.new()
	recipe_heading.text = "简易工作台"
	recipe_heading.add_theme_font_size_override("font_size", 24)
	left_column.add_child(recipe_heading)
	var recipe_hint := Label.new()
	recipe_hint.text = "按材料总量匹配，可多放材料\n• 1 木头 → 4 木板\n• 4 木板 → 工作台 / 砖块"
	recipe_hint.add_theme_font_size_override("font_size", 18)
	recipe_hint.add_theme_color_override("font_color", Color(0.94, 0.88, 0.72))
	left_column.add_child(recipe_hint)

	var input_column := VBoxContainer.new()
	input_column.add_theme_constant_override("separation", 8)
	crafting_row.add_child(input_column)
	var input_label := Label.new()
	input_label.text = "合成材料"
	input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_label.add_theme_font_size_override("font_size", 20)
	input_column.add_child(input_label)
	var input_grid := GridContainer.new()
	input_grid.columns = 2
	input_grid.add_theme_constant_override("h_separation", 10)
	input_grid.add_theme_constant_override("v_separation", 10)
	input_column.add_child(input_grid)
	for index: int in range(CraftingGrid.GRID_SIZE):
		var slot := _create_crafting_button(index)
		input_grid.add_child(slot["button"] as Button)
		crafting_buttons.append(slot["button"] as Button)
		crafting_icons.append(slot["icon"] as TextureRect)
		crafting_counts.append(slot["count"] as Label)

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size = Vector2(170, 190)
	action_column.alignment = BoxContainer.ALIGNMENT_CENTER
	action_column.add_theme_constant_override("separation", 12)
	crafting_row.add_child(action_column)
	preview_button = Button.new()
	preview_button.name = "PreviewRecipeButton"
	preview_button.text = "预览配方"
	preview_button.custom_minimum_size = Vector2(170, 54)
	preview_button.add_theme_font_size_override("font_size", 20)
	preview_button.pressed.connect(_on_preview_pressed)
	action_column.add_child(preview_button)
	craft_button = Button.new()
	craft_button.name = "CraftButton"
	craft_button.text = "合成"
	craft_button.custom_minimum_size = Vector2(170, 54)
	craft_button.add_theme_font_size_override("font_size", 21)
	craft_button.disabled = true
	craft_button.pressed.connect(_on_crafting_output_pressed)
	action_column.add_child(craft_button)
	crafting_status = Label.new()
	crafting_status.text = "放入材料后点击预览"
	crafting_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crafting_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crafting_status.add_theme_font_size_override("font_size", 16)
	action_column.add_child(crafting_status)
	recipe_candidates = VBoxContainer.new()
	recipe_candidates.add_theme_constant_override("separation", 6)
	action_column.add_child(recipe_candidates)

	var output_column := VBoxContainer.new()
	output_column.add_theme_constant_override("separation", 8)
	crafting_row.add_child(output_column)
	var output_label := Label.new()
	output_label.text = "成品预览"
	output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	output_label.add_theme_font_size_override("font_size", 20)
	output_column.add_child(output_label)
	var output_slot := _create_crafting_button(-1)
	crafting_output_button = output_slot["button"] as Button
	crafting_output_button.name = "CraftingOutput"
	crafting_output_button.disabled = true
	crafting_output_icon = output_slot["icon"] as TextureRect
	crafting_output_count = output_slot["count"] as Label
	output_column.add_child(crafting_output_button)


func _create_crafting_button(index: int) -> Dictionary:
	var button := Button.new()
	button.name = "CraftingInput%d" % index
	button.custom_minimum_size = CRAFT_SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_crafting_slot_pressed.bind(index))
	var icon := TextureRect.new()
	icon.position = Vector2(13, 11)
	icon.size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var count := Label.new()
	count.position = Vector2(8, 51)
	count.size = Vector2(64, 25)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 18)
	count.add_theme_color_override("font_shadow_color", Color.BLACK)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	_apply_button_style(button, false, false)
	return {"button": button, "icon": icon, "count": count}


func _create_slot_button(index: int, is_hotbar: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	var button := Button.new()
	button.name = ("HotbarSlot%d" if is_hotbar else "InventorySlot%d") % index
	button.custom_minimum_size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_slot_pressed.bind(index))
	panel.add_child(button)

	var icon := TextureRect.new()
	icon.position = Vector2(10, 9)
	icon.size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var count := Label.new()
	count.position = Vector2(6, 43)
	count.size = Vector2(55, 23)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 17)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_shadow_color", Color.BLACK)
	count.add_theme_constant_override("shadow_offset_x", 1)
	count.add_theme_constant_override("shadow_offset_y", 1)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)

	if is_hotbar:
		var key_label := Label.new()
		key_label.text = str(index + 1)
		key_label.position = Vector2(4, 1)
		key_label.size = Vector2(18, 18)
		key_label.add_theme_font_size_override("font_size", 14)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(key_label)
	return {"panel": panel, "button": button, "icon": icon, "count": count}


func _build_crosshair(root: Control) -> void:
	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-12.0, -12.0)
	crosshair.size = Vector2(24.0, 24.0)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	_add_crosshair_rect(Vector2(10.0, 1.0), Vector2(4.0, 8.0), Color(0.0, 0.0, 0.0, 0.72))
	_add_crosshair_rect(Vector2(10.0, 15.0), Vector2(4.0, 8.0), Color(0.0, 0.0, 0.0, 0.72))
	_add_crosshair_rect(Vector2(1.0, 10.0), Vector2(8.0, 4.0), Color(0.0, 0.0, 0.0, 0.72))
	_add_crosshair_rect(Vector2(15.0, 10.0), Vector2(8.0, 4.0), Color(0.0, 0.0, 0.0, 0.72))
	_add_crosshair_rect(Vector2(11.0, 2.0), Vector2(2.0, 7.0), Color.WHITE)
	_add_crosshair_rect(Vector2(11.0, 15.0), Vector2(2.0, 7.0), Color.WHITE)
	_add_crosshair_rect(Vector2(2.0, 11.0), Vector2(7.0, 2.0), Color.WHITE)
	_add_crosshair_rect(Vector2(15.0, 11.0), Vector2(7.0, 2.0), Color.WHITE)


func _add_crosshair_rect(rect_position: Vector2, rect_size: Vector2, color: Color) -> void:
	var line := ColorRect.new()
	line.position = rect_position
	line.size = rect_size
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(line)


func _on_slot_changed(index: int) -> void:
	_refresh_slot(index)
	if index == inventory.selected_hotbar_index:
		set_selected_block(inventory.selected_item())


func _on_selection_changed(_index: int) -> void:
	set_selected_block(inventory.selected_item())


func _on_slot_pressed(index: int) -> void:
	if not inventory_panel.visible:
		if index < PlayerInventory.HOTBAR_SIZE:
			inventory.select_hotbar(index)
		return
	if held_slot_index < 0:
		held_slot_index = index
		inventory_title.text = "已选中第 %d 格  ·  再点击一个格子交换" % (index + 1)
		_refresh_selection_styles()
		return
	inventory.swap_slots(held_slot_index, index)
	held_slot_index = -1
	inventory_title.text = "背包  ·  36 格  ·  点击物品后再点击合成格可放入材料"
	_refresh_selection_styles()


func _on_crafting_slot_pressed(index: int) -> void:
	if index < 0:
		return
	if held_slot_index >= 0:
		if crafting_grid.move_one_from_inventory(held_slot_index, index):
			inventory_title.text = "已放入1个材料  ·  可继续点击合成格"
			if inventory.is_empty(held_slot_index):
				held_slot_index = -1
	else:
		crafting_grid.return_one_to_inventory(index)
		inventory_title.text = "已从合成格取回1个材料"
	_refresh_selection_styles()


func _on_preview_pressed() -> void:
	if crafting_grid.total_material_count() <= 0:
		crafting_status.text = "请放入2×2材料"
		inventory_title.text = "请先从背包选择材料，再放入2×2合成格"
		return
	var recipes := crafting_grid.preview_all_recipes()
	if recipes.is_empty():
		crafting_status.text = "当前材料不足以制作任何物品"
		inventory_title.text = "预览失败：可以多放材料，系统按总数量判断"
	else:
		crafting_status.text = "可制作 %d 种，请点击选择" % recipes.size()
		inventory_title.text = "预览完成：点击一个成品候选，再点击合成"


func _on_recipe_candidate_pressed(index: int) -> void:
	if crafting_grid.select_preview(index):
		crafting_status.text = "已选择：%s ×%d" % [
			ItemCatalog.display_name(crafting_grid.output_item()),
			crafting_grid.output_amount(),
		]
		inventory_title.text = "已选择目标配方，点击“合成”制作该物品"
		_refresh_recipe_candidate_styles(index)


func _on_crafting_output_pressed() -> void:
	var result_item := crafting_grid.output_item()
	var result_amount := crafting_grid.output_amount()
	if crafting_grid.craft_once():
		inventory_title.text = "合成成功：%s ×%d" % [
			ItemCatalog.display_name(result_item),
			result_amount,
		]
		crafting_status.text = "材料已变化，请重新预览"
	else:
		inventory_title.text = "无法合成：请先预览配方并检查背包空间"
		crafting_status.text = "需要先成功预览"


func _refresh_crafting_slots() -> void:
	for index: int in range(CraftingGrid.GRID_SIZE):
		var item_id := crafting_grid.get_item(index)
		crafting_icons[index].texture = load(ItemCatalog.icon_path(item_id)) as Texture2D if item_id != PlayerInventory.EMPTY_ITEM else null
		crafting_counts[index].text = str(crafting_grid.get_amount(index)) if crafting_grid.get_amount(index) > 0 else ""
	_on_crafting_output_changed(crafting_grid.output_item(), crafting_grid.output_amount())
	crafting_status.text = "材料已变化，点击“预览配方”"


func _on_preview_candidates_changed(recipes: Array[CraftingRecipe]) -> void:
	for child: Node in recipe_candidates.get_children():
		child.queue_free()
	recipe_candidate_buttons.clear()
	for index: int in range(recipes.size()):
		var recipe := recipes[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(170, 42)
		button.text = "%s ×%d" % [ItemCatalog.display_name(recipe.result_item), recipe.result_amount]
		button.tooltip_text = _recipe_material_text(recipe)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_recipe_candidate_pressed.bind(index))
		recipe_candidates.add_child(button)
		recipe_candidate_buttons.append(button)
	if recipes.is_empty():
		craft_button.disabled = true


func _refresh_recipe_candidate_styles(selected_index: int) -> void:
	for index: int in range(recipe_candidate_buttons.size()):
		var button := recipe_candidate_buttons[index]
		button.modulate = Color("ffd75c") if index == selected_index else Color.WHITE


func _recipe_material_text(recipe: CraftingRecipe) -> String:
	var parts: PackedStringArray = []
	for item_id: int in recipe.required_items:
		parts.append("%s ×%d" % [ItemCatalog.display_name(item_id), recipe.required_items[item_id]])
	return "需要：" + "、".join(parts)


func _on_crafting_output_changed(item_id: int, amount: int) -> void:
	crafting_output_icon.texture = load(ItemCatalog.icon_path(item_id)) as Texture2D if item_id != PlayerInventory.EMPTY_ITEM else null
	crafting_output_count.text = str(amount) if amount > 0 else ""
	crafting_output_button.disabled = true
	craft_button.disabled = item_id == PlayerInventory.EMPTY_ITEM


func _refresh_slot(index: int) -> void:
	var texture: Texture2D = null
	var item_id := inventory.get_item(index)
	if item_id != PlayerInventory.EMPTY_ITEM:
		texture = load(ItemCatalog.icon_path(item_id)) as Texture2D
	var amount_text := "" if inventory.get_amount(index) <= 0 else str(inventory.get_amount(index))
	if index < PlayerInventory.HOTBAR_SIZE:
		hotbar_icons[index].texture = texture
		hotbar_counts[index].text = amount_text
	inventory_icons[index].texture = texture
	inventory_counts[index].text = amount_text


func _refresh_selection_styles() -> void:
	for index: int in range(hotbar_buttons.size()):
		_apply_button_style(hotbar_buttons[index], index == inventory.selected_hotbar_index, false)
	for index: int in range(inventory_buttons.size()):
		_apply_button_style(
			inventory_buttons[index],
			index == inventory.selected_hotbar_index,
			index == held_slot_index
		)


func _apply_button_style(button: Button, selected: bool, held: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.18, 0.96)
	style.border_color = Color("64d8ff") if held else (Color("ffd75c") if selected else Color(1.0, 1.0, 1.0, 0.28))
	style.set_border_width_all(3 if selected or held else 1)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.25, 0.29, 0.98)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
