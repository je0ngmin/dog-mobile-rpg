class_name WorldView
extends Node2D

const DAMAGE_FONT := preload("res://fonts/AstaSans-ExtraBold.ttf")

var _combat_lines: Array[Dictionary] = []


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	for line in _combat_lines:
		line["life"] = float(line["life"]) - delta
	_combat_lines = _combat_lines.filter(func(line: Dictionary) -> bool: return float(line["life"]) > 0.0)
	queue_redraw()


func add_combat_line(from: Vector2, to: Vector2, color: Color) -> void:
	_combat_lines.append({"from": from, "to": to, "color": color, "life": 0.14})


func add_damage_number(world_position: Vector2, amount: float, boss_hit: bool = false) -> Label:
	var damage_label := Label.new()
	damage_label.name = "DamageNumber"
	damage_label.add_to_group("damage_numbers")
	damage_label.z_index = 20
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label.text = format_damage_number(amount)
	damage_label.custom_minimum_size = Vector2(150.0, 48.0)
	damage_label.size = damage_label.custom_minimum_size
	damage_label.pivot_offset = damage_label.size * 0.5
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_label.add_theme_font_override("font", DAMAGE_FONT)
	damage_label.add_theme_font_size_override("font_size", 31 if boss_hit else 25)
	damage_label.add_theme_color_override(
		"font_color",
		Color("#ffd45a") if boss_hit else Color.WHITE
	)
	damage_label.add_theme_color_override("font_outline_color", Color(0.16, 0.025, 0.02, 0.98))
	damage_label.add_theme_constant_override("outline_size", 5)
	add_child(damage_label)

	var visual_offset_y := -108.0 if boss_hit else -67.0
	var start_position := (
		to_local(world_position)
		+ Vector2(randf_range(-18.0, 18.0) - damage_label.size.x * 0.5, visual_offset_y)
	)
	damage_label.position = start_position + Vector2(0.0, 18.0)
	damage_label.scale = Vector2.ONE * 0.72
	var tween := damage_label.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_label, "position", start_position + Vector2(0.0, -62.0), 0.82)
	tween.parallel().tween_property(damage_label, "scale", Vector2.ONE * (1.12 if boss_hit else 1.0), 0.18).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.42).set_delay(0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(damage_label.queue_free)
	return damage_label


func format_damage_number(amount: float) -> String:
	return GameState.format_large_number(maxi(int(round(amount)), 0))


func _draw() -> void:
	for line in _combat_lines:
		var alpha := clampf(float(line["life"]) / 0.14, 0.0, 1.0)
		var color: Color = line["color"]
		color.a = alpha
		draw_line(to_local(line["from"]), to_local(line["to"]), color, 5.0)
