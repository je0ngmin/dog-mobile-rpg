class_name WorldView
extends Node2D

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


func _draw() -> void:
	for line in _combat_lines:
		var alpha := clampf(float(line["life"]) / 0.14, 0.0, 1.0)
		var color: Color = line["color"]
		color.a = alpha
		draw_line(to_local(line["from"]), to_local(line["to"]), color, 5.0)
