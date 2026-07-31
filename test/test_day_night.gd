extends SceneTree

var failures := 0
var frame := 0
var main: Node
var cycle: DayNightCycle


func _init() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	frame += 1
	if frame == 5:
		cycle = main.get_node("DayNightCycle") as DayNightCycle
		cycle.running = false
		_test_structure()
		_test_midnight()
		_test_dawn()
		_test_noon()
		_test_dusk()
		_test_time_wrapping()
		quit(failures)


func _test_structure() -> void:
	_expect(cycle != null, "场景创建独立昼夜循环节点")
	_expect(is_equal_approx(DayNightCycle.DAY_DURATION_SECONDS, 600.0), "完整昼夜循环为 600 秒")
	_expect(cycle.world_environment != null, "昼夜系统包含 WorldEnvironment")
	_expect(cycle.environment != null, "昼夜系统包含 Environment")
	_expect(cycle.sky != null, "环境包含 Sky 资源")
	_expect(cycle.sky_material is ProceduralSkyMaterial, "天空使用 ProceduralSkyMaterial")
	_expect(cycle.sun is DirectionalLight3D, "主光源使用 DirectionalLight3D")
	_expect(cycle.environment.background_mode == Environment.BG_SKY, "环境背景来自天空")


func _test_midnight() -> void:
	cycle.set_hour(0.0)
	_expect(cycle.get_daylight_factor() < 0.01, "午夜白昼权重接近 0")
	_expect(cycle.environment.ambient_light_energy >= 0.13, "夜晚保留最低环境光")
	_expect(cycle.environment.ambient_light_energy < 0.20, "夜晚环境明显变暗")
	_expect(cycle.environment.background_energy_multiplier > 0.20, "夜空不完全为黑色")
	_expect(cycle.sun.light_energy > 0.0, "夜晚保留微弱冷色方向光")
	_expect(not cycle.sun.shadow_enabled, "夜间关闭太阳阴影")


func _test_dawn() -> void:
	cycle.set_hour(6.0)
	_expect(absf(cycle.sun.rotation_degrees.x) < 0.01, "日出时太阳位于地平线")
	_expect(cycle.sky_material.sky_horizon_color.r > cycle.sky_material.sky_horizon_color.b, "日出地平线呈暖色")


func _test_noon() -> void:
	cycle.set_hour(12.0)
	_expect(cycle.get_daylight_factor() > 0.99, "正午白昼权重接近 1")
	_expect(absf(cycle.sun.rotation_degrees.x - 90.0) < 0.01, "正午太阳达到最高角度")
	_expect(cycle.sun.light_energy > 1.1, "正午太阳光充足")
	_expect(cycle.environment.ambient_light_energy > 0.70, "正午环境光明亮")
	_expect(cycle.sun.shadow_enabled, "白天启用太阳阴影")


func _test_dusk() -> void:
	cycle.set_hour(18.0)
	_expect(absf(cycle.sun.rotation_degrees.x - 180.0) < 0.01, "日落时太阳位于西方地平线")
	_expect(cycle.sky_material.sky_horizon_color.r > cycle.sky_material.sky_horizon_color.b, "日落地平线呈暖色")


func _test_time_wrapping() -> void:
	cycle.set_hour(24.0)
	_expect(is_equal_approx(cycle.get_hour(), 0.0), "24点会循环回午夜")
	cycle.set_hour(30.0)
	_expect(is_equal_approx(cycle.get_hour(), 6.0), "超过24小时会正确循环")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
