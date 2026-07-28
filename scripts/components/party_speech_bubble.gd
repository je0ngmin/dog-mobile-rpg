class_name PartySpeechBubble
extends Control

enum State {
	NORMAL,
	TEAMMATE_DOWN,
	BOSS_DEFEATED,
	BOSS_ARRIVED,
}

@export var messages: Resource

const BUBBLE_TEXTURE := preload("res://sprites/bubble.png")

var current_state: State = State.NORMAL
var current_text: String = ""
var _letters: HBoxContainer
var _state_time_remaining: float = 0.0
var _normal_time_remaining: float = 0.0
var _last_message: String = ""
var _typing_tweens: Array[Tween] = []


func _ready() -> void:
	add_to_group("party_speech_bubble")
	custom_minimum_size = Vector2(300.0, 129.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_visual()
	show_normal(true)


func _process(delta: float) -> void:
	if current_state != State.NORMAL:
		_state_time_remaining -= delta
		if _state_time_remaining <= 0.0:
			show_normal(true)
		return
	_normal_time_remaining -= delta
	if _normal_time_remaining <= 0.0:
		show_normal(true)


func show_normal(force_new: bool = false) -> void:
	current_state = State.NORMAL
	_state_time_remaining = 0.0
	_normal_time_remaining = messages.normal_change_interval if messages else 6.0
	if force_new or current_text.is_empty():
		_set_message(_pick_message(messages.normal_messages if messages else PackedStringArray()))


func show_teammate_down(character_name: String) -> void:
	current_state = State.TEAMMATE_DOWN
	_state_time_remaining = messages.event_message_duration if messages else 4.0
	var text := _pick_message(messages.teammate_down_messages if messages else PackedStringArray())
	_set_message(text.replace("{name}", character_name))


func show_boss_defeated() -> void:
	current_state = State.BOSS_DEFEATED
	_state_time_remaining = messages.event_message_duration if messages else 4.0
	_set_message(_pick_message(messages.boss_defeated_messages if messages else PackedStringArray()))


func show_boss_arrived() -> void:
	current_state = State.BOSS_ARRIVED
	_state_time_remaining = messages.event_message_duration if messages else 4.0
	_set_message(_pick_message(messages.boss_arrived_messages if messages else PackedStringArray()))


func _build_visual() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BUBBLE_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_letters = HBoxContainer.new()
	_letters.anchor_right = 1.0
	_letters.anchor_bottom = 1.0
	_letters.offset_left = 20.0
	_letters.offset_top = 31.0
	_letters.offset_right = -20.0
	_letters.offset_bottom = -14.0
	_letters.alignment = BoxContainer.ALIGNMENT_CENTER
	_letters.add_theme_constant_override("separation", 0)
	_letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letters)


func _pick_message(candidates: PackedStringArray) -> String:
	if candidates.is_empty():
		return "멍!"
	if candidates.size() == 1:
		return candidates[0]
	var picked := candidates[randi_range(0, candidates.size() - 1)]
	if picked == _last_message:
		var current_index := candidates.find(picked)
		picked = candidates[(current_index + 1) % candidates.size()]
	return picked


func _set_message(text: String) -> void:
	current_text = text
	_last_message = text
	if not is_instance_valid(_letters):
		return
	for tween in _typing_tweens:
		if tween:
			tween.kill()
	_typing_tweens.clear()
	for child in _letters.get_children():
		_letters.remove_child(child)
		child.queue_free()
	for index in text.length():
		var character := text.substr(index, 1)
		var letter := Label.new()
		letter.text = character
		letter.custom_minimum_size = Vector2(5.0 if character == " " else 12.0, 42.0)
		letter.modulate = Color(1.0, 1.0, 1.0, 0.0)
		letter.add_theme_color_override("font_color", Color("#352719"))
		letter.add_theme_font_size_override("font_size", 14)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_letters.add_child(letter)
		var fade_in := letter.create_tween()
		_typing_tweens.append(fade_in)
		fade_in.tween_interval(index * 0.045)
		fade_in.tween_property(letter, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
