class_name GameHUD
extends CanvasLayer

var title_label: Label
var selected_label: Label
var crosshair: Control
var slot_panels: Array[PanelContainer] = []


func _ready() -> void:
	_build_ui()


func set_selected_block(block_type: int) -> void:
	if selected_label == null:
		return
	selected_label.text = "当前方块：%s" % VoxelWorld.BLOCK_NAMES.get(block_type, "未知")
	var selected_index := FirstPersonPlayer.BLOCK_SLOTS.find(block_type)
	for i: int in range(slot_panels.size()):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.10, 0.12, 0.90)
		style.border_color = Color("ffd75c") if i == selected_index else Color(1.0, 1.0, 1.0, 0.30)
		style.set_border_width_all(3 if i == selected_index else 1)
		style.set_corner_radius_all(7)
		slot_panels[i].add_theme_stylebox_override("panel", style)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

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
	help.text = "WASD 移动  ·  空格跳跃  ·  左键破坏  ·  右键放置  ·  滚轮/1-5 切换  ·  ESC 释放鼠标"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	help.add_theme_constant_override("shadow_offset_x", 2)
	help.add_theme_constant_override("shadow_offset_y", 2)
	help.set_anchors_preset(Control.PRESET_CENTER_TOP)
	help.position = Vector2(-380, 22)
	help.size = Vector2(760, 32)
	root.add_child(help)

	_build_crosshair(root)

	var hotbar := HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.position = Vector2(-231, -96)
	hotbar.add_theme_constant_override("separation", 8)
	root.add_child(hotbar)

	for i: int in range(FirstPersonPlayer.BLOCK_SLOTS.size()):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(86, 66)
		hotbar.add_child(panel)
		slot_panels.append(panel)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(box)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(48, 20)
		var block_type: int = FirstPersonPlayer.BLOCK_SLOTS[i]
		swatch.color = VoxelWorld.BLOCK_COLORS[block_type] as Color
		box.add_child(swatch)
		var name_label := Label.new()
		name_label.text = "%d  %s" % [i + 1, VoxelWorld.BLOCK_NAMES[block_type]]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		box.add_child(name_label)

	selected_label = Label.new()
	selected_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	selected_label.position = Vector2(-120, -130)
	selected_label.size = Vector2(240, 28)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.add_theme_font_size_override("font_size", 17)
	selected_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	root.add_child(selected_label)
	set_selected_block(VoxelWorld.GRASS)


func _build_crosshair(root: Control) -> void:
	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-12.0, -12.0)
	crosshair.size = Vector2(24.0, 24.0)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	# 使用 ColorRect 而不是字体字符，任何字体和分辨率下都保持像素稳定。
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
