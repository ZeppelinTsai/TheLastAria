extends CanvasLayer

# ─────────────────────────────────────────
#  SceneTransition.gd
#  Autoload — 場景切換 + 顏色轉場效果
#
#  用法：
#    SceneTransition.go("res://scenes/world/act1.tscn")
#    SceneTransition.go("res://scenes/world/act2.tscn", "空島・永晝觀測站")
#    SceneTransition.flash_memory_in()
#    SceneTransition.flash_memory_out()
# ─────────────────────────────────────────

# 轉場類型
enum Type {
	NORMAL,   # 黑色淡入淡出（普通場景切換）
	SLOW,     # 慢速黑色（結局用）
	FLASH,    # 白色閃光（衝擊演出）
	MEMORY,   # 黃色褪色（記憶閃回）
}

const CONFIGS = {
	Type.NORMAL: { "color": Color(0, 0, 0, 0),       "fade_out": 0.4, "fade_in": 0.4 },
	Type.SLOW:   { "color": Color(0, 0, 0, 0),       "fade_out": 1.2, "fade_in": 1.2 },
	Type.FLASH:  { "color": Color(1, 1, 1, 0),       "fade_out": 0.12,"fade_in": 0.35 },
	Type.MEMORY: { "color": Color(0.72, 0.58, 0.2, 0), "fade_out": 0.6, "fade_in": 0.6 },
}

var overlay: ColorRect
var location_label: Label
var is_transitioning := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	location_label = Label.new()
	location_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location_label.add_theme_font_size_override("font_size", 28)
	location_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.0))
	location_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	location_label.add_theme_constant_override("shadow_offset_x", 2)
	location_label.add_theme_constant_override("shadow_offset_y", 2)
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(location_label)

# ── 場景切換 ──────────────────────────────
func go(scene_path: String, location_name: String = "", type: int = Type.NORMAL) -> void:
	if is_transitioning:
		return

	is_transitioning = true
	var cfg = CONFIGS[type]

	# 淡出
	await _fade(cfg["color"], 1.0, cfg["fade_out"])

	# 顯示地點名稱
	if location_name != "":
		location_label.text = location_name
		await _fade_label(1.0, 0.25)
		await get_tree().create_timer(0.6).timeout
		await _fade_label(0.0, 0.25)
		location_label.text = ""

	# 換場景
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame

	# 淡入
	await _fade(cfg["color"], 0.0, cfg["fade_in"])

	is_transitioning = false

# ── 記憶閃回：只做效果，不換場景 ────────
func flash_memory_in() -> void:
	var cfg = CONFIGS[Type.MEMORY]
	await _fade(cfg["color"], 0.85, cfg["fade_out"])

func flash_memory_out() -> void:
	var cfg = CONFIGS[Type.MEMORY]
	await _fade(cfg["color"], 0.0, cfg["fade_in"])

# ── 衝擊白閃（演出用，不換場景） ─────────
func flash_hit() -> void:
	var cfg = CONFIGS[Type.FLASH]
	await _fade(cfg["color"], 1.0, cfg["fade_out"])
	await _fade(cfg["color"], 0.0, cfg["fade_in"])

# ── 純黑淡出（演出用，不換場景） ─────────
func fade_to_black(duration: float = 0.6) -> void:
	await _fade(Color(0, 0, 0, 0), 1.0, duration)

func fade_from_black(duration: float = 0.6) -> void:
	await _fade(Color(0, 0, 0, 0), 0.0, duration)

# ── 內部工具 ──────────────────────────────
func _fade(base_color: Color, target_alpha: float, duration: float) -> void:
	var start_color = base_color
	start_color.a = overlay.color.a
	var end_color = base_color
	end_color.a = target_alpha

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(overlay, "color", end_color, duration)
	await tween.finished

func _fade_label(target_alpha: float, duration: float) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(location_label, "theme_override_colors/font_color:a", target_alpha, duration)
	await tween.finished