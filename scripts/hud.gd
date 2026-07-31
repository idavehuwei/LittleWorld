class_name GameHUD
extends CanvasLayer

const SLOT_SIZE := Vector2(56.0, 56.0)
const HOTBAR_GAP := 6

var inventory: PlayerInventory
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
var held_slot_index := -1


func _ready() -> void:
	assert(inventory != null, "GameHUD 需要在进入场景树前设置 inventory")
	_build_ui()
	inventory.slot_changed.connect(_on_slot_changed)
	inventory.selection_changed.connect(_on_selection_changed)
	refresh_all_slots()


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
	inventory_title.text = "背包  ·  36 格  ·  点击两个格子可交换" if is_open else "背包"
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
	selected_label.position = Vector2(-150, -116)
	selected_label.size = Vector2(300, 28)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.add_theme_font_size_override("font_size", 17)
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
	hotbar.position = Vector2(-width * 0.5, -82)
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
	inventory_panel.position = Vector2(-310, -180)
	inventory_panel.custom_minimum_size = Vector2(620, 360)
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.065, 0.08, 0.97)
	panel_style.border_color = Color(0.92, 0.86, 0.68, 0.72)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 24
	inventory_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(inventory_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	inventory_panel.add_child(content)
	inventory_title = Label.new()
	inventory_title.text = "背包  ·  36 格"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_title.add_theme_font_size_override("font_size", 24)
	content.add_child(inventory_title)

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
	icon.position = Vector2(9, 8)
	icon.size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var count := Label.new()
	count.position = Vector2(4, 31)
	count.size = Vector2(47, 21)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 15)
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
		key_label.add_theme_font_size_override("font_size", 12)
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
	inventory_title.text = "背包  ·  36 格  ·  点击两个格子可交换"
	_refresh_selection_styles()


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
