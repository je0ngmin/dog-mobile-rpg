extends Node

@export var dog_scene: PackedScene
@export var enemy_scene: PackedScene

@onready var world: WorldView = $World
@onready var stage_manager: StageManager = $StageManager
@onready var camera: Camera2D = $World/Camera2D
@onready var stage_label: Label = $UI/BossProgress/Stage
@onready var resource_label: Label = $UI/TopBar/Margin/HBox/HBoxContainer/Resources
@onready var level_label: Label = $UI/TopBar/Margin/HBox/Level
@onready var progress_bar: ProgressBar = $UI/BossProgress
@onready var progress_label: Label = $UI/BossProgress/Label
@onready var message_label: Label = $UI/Message
@onready var retry_button: Button = $UI/RetryButton
@onready var character_button: Button = $UI/CharacterButton
@onready var character_panel: PanelContainer = $UI/CharacterPanel
@onready var character_cards: HBoxContainer = $UI/CharacterPanel/Margin/VBox/CharacterScroll/CharacterCards
@onready var skill_button: Button = $UI/SkillButton
@onready var skill_panel: PanelContainer = $UI/SkillPanel
@onready var skill_rows: VBoxContainer = $UI/SkillPanel/Margin/VBox/SkillRows
@onready var offline_panel: PanelContainer = $UI/OfflinePanel
@onready var offline_label: Label = $UI/OfflinePanel/Margin/VBox/Reward
@onready var gold_effects: Node2D = $GoldEffects/Coins
@onready var stage_transition_overlay: ColorRect = $StageTransition/Overlay
@onready var boss_atmosphere_overlay: ColorRect = $BossAtmosphere/Overlay
var event_log_entries: VBoxContainer

const CHARACTER_DATA := [
	{"name": "보리", "role": DogActor.Role.ASSAULT, "role_name": "돌격형", "stat": "최대 체력", "percent": 1.5},
	{"name": "탄이", "role": DogActor.Role.DAMAGE, "role_name": "공격형", "stat": "공격력", "percent": 1.3},
	{"name": "모카", "role": DogActor.Role.TECH, "role_name": "기술형", "stat": "스킬 피해", "percent": 1.5},
]
const FORMATION_OFFSETS := [Vector2.ZERO, Vector2(-60.0, -42.0), Vector2(-112.0, 38.0)]
const CHARACTER_TEXTURES := [
	preload("res://sprites/dogs/dog001.png"),
	preload("res://sprites/dogs/dog002.png"),
	preload("res://sprites/dogs/dog003.png"),
]
const GOLD_TEXTURE := preload("res://sprites/gold.png")

var party: Array[DogActor] = []
var party_by_index: Dictionary = {}
var leader: DogActor
var _message_tween: Tween
var _stage_manager_ready: bool = false
var _camera_zoom_tween: Tween
var _boss_atmosphere_tween: Tween
var _camera_trauma: float = 0.0
var _camera_shake_time: float = 0.0
var _gold_label_tween: Tween
var _stage_transition_active: bool = false
var _healing_skill_cooldown_remaining: float = 0.0


func _ready() -> void:
	_create_event_log()
	_create_party()
	stage_manager.enemy_scene = enemy_scene
	stage_manager.setup(world, party, GameState.highest_stage)
	_stage_manager_ready = true
	stage_manager.stage_changed.connect(_on_stage_changed)
	stage_manager.progress_changed.connect(_on_progress_changed)
	stage_manager.boss_warning.connect(_on_boss_battle_started)
	stage_manager.boss_battle_ended.connect(_on_boss_battle_ended)
	stage_manager.boss_attacked.connect(_on_boss_attacked)
	stage_manager.gold_dropped.connect(_on_gold_dropped)
	stage_manager.reward_logged.connect(_on_reward_logged)
	stage_manager.stage_transition_requested.connect(_on_stage_transition_requested)
	stage_manager.party_defeated.connect(_on_party_defeated)
	stage_manager.combat_message.connect(_show_message)
	stage_manager.combat_message.connect(_add_event_log)
	GameState.resources_changed.connect(_refresh_resources)
	GameState.level_changed.connect(_on_account_level_changed)
	GameState.offline_reward_ready.connect(_show_offline_reward)
	GameState.character_roster_changed.connect(_on_character_roster_changed)
	GameState.account_skills_changed.connect(_on_account_skills_changed)
	retry_button.pressed.connect(_on_revive_requested)
	character_button.pressed.connect(_open_character_panel)
	skill_button.pressed.connect(_open_skill_panel)
	$UI/CharacterPanel/Margin/VBox/Close.pressed.connect(character_panel.hide)
	$UI/SkillPanel/Margin/VBox/Close.pressed.connect(skill_panel.hide)
	$UI/OfflinePanel/Margin/VBox/Close.pressed.connect(offline_panel.hide)
	_refresh_resources()
	_on_stage_changed(stage_manager.current_stage)
	_on_progress_changed(0, stage_manager.enemies_before_boss, false)
	var pending_reward: Dictionary = GameState.consume_offline_reward()
	if not pending_reward.is_empty():
		_show_offline_reward(pending_reward)


func _create_event_log() -> void:
	var panel := PanelContainer.new()
	panel.name = "EventLog"
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -362.0
	panel.offset_top = -258.0
	panel.offset_right = -24.0
	panel.offset_bottom = -58.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.07, 0.82)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.55, 0.43, 0.22, 0.72)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	$UI.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 5)
	margin.add_child(contents)

	var title := Label.new()
	title.text = "원정 기록"
	title.add_theme_color_override("font_color", Color("#ffc74d"))
	title.add_theme_font_size_override("font_size", 16)
	contents.add_child(title)

	event_log_entries = VBoxContainer.new()
	event_log_entries.name = "Entries"
	event_log_entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_log_entries.add_theme_constant_override("separation", 3)
	event_log_entries.alignment = BoxContainer.ALIGNMENT_END
	contents.add_child(event_log_entries)


func _process(delta: float) -> void:
	if is_instance_valid(leader):
		camera.global_position.x = lerpf(camera.global_position.x, leader.global_position.x + 180.0, 0.06)
	_update_camera_shake(delta)
	_update_healing_skill(delta)
	if Input.is_action_just_pressed("retry_boss"):
		_on_revive_requested()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		GameState.save_game()


func _create_party() -> void:
	for index in 3:
		if GameState.character_purchased[index]:
			_spawn_character(index)
	camera.global_position = Vector2(leader.global_position.x + 180.0, 324.0)


func _spawn_character(character_index: int) -> void:
	if party_by_index.has(character_index):
		return
	var data: Dictionary = CHARACTER_DATA[character_index]
	var dog := dog_scene.instantiate() as DogActor
	world.add_child(dog)
	var spawn_origin := Vector2(250.0, 320.0)
	if is_instance_valid(leader):
		spawn_origin = leader.global_position
	dog.global_position = spawn_origin + FORMATION_OFFSETS[character_index]
	dog.configure(
		String(data["name"]),
		int(data["role"]),
		FORMATION_OFFSETS[character_index],
		leader
	)
	dog.set_character_texture(CHARACTER_TEXTURES[character_index])
	dog.apply_progression(GameState.player_level, GameState.character_levels[character_index])
	dog.attack_visual.connect(world.add_combat_line)
	dog.skill_visual.connect(world.add_combat_line)
	party.append(dog)
	party_by_index[character_index] = dog
	if character_index == 0:
		leader = dog
		dog.leader = null
	if _stage_manager_ready:
		stage_manager.add_party_member(dog)


func _refresh_resources() -> void:
	resource_label.text = "%sG" % GameState.format_large_number(GameState.gold)
	level_label.text = "원정대 Lv.%d  EXP %d/%d" % [
		GameState.player_level, GameState.experience, GameState.experience_to_next_level()
	]
	if stage_manager.progression_paused:
		var cost := stage_manager.revival_cost()
		retry_button.text = "모두 부활  %sG" % GameState.format_large_number(cost)
		retry_button.disabled = GameState.gold < cost
	if character_panel.visible:
		_rebuild_character_rows()
	if skill_panel.visible:
		_rebuild_skill_rows()


func _on_stage_changed(stage_number: int) -> void:
	var area := ((stage_number - 1) / 10) + 1
	var local_stage := ((stage_number - 1) % 10) + 1
	stage_label.text = "버려진 주택가  %d-%d" % [area, local_stage]
	for character_index in party_by_index:
		var dog: DogActor = party_by_index[character_index]
		dog.apply_progression(GameState.player_level, GameState.character_levels[character_index])


func _on_progress_changed(kills: int, required: int, boss_active: bool) -> void:
	progress_bar.max_value = required
	progress_bar.value = required if boss_active else kills
	progress_label.text = "BOSS 전투 중" if boss_active else "보스 출현까지  %d / %d" % [kills, required]


func _on_account_level_changed(new_level: int) -> void:
	for character_index in party_by_index:
		var dog: DogActor = party_by_index[character_index]
		dog.apply_progression(new_level, GameState.character_levels[character_index])
	_show_message("원정대 레벨 %d 달성! 능력치가 상승했습니다." % new_level)
	_add_event_log("원정대 Lv.%d 달성 · 전체 능력치 상승" % new_level, Color("#7de7ff"))


func _on_party_defeated() -> void:
	var cost := stage_manager.revival_cost()
	retry_button.text = "모두 부활  %sG" % GameState.format_large_number(cost)
	retry_button.disabled = GameState.gold < cost
	retry_button.show()


func _on_boss_battle_started() -> void:
	if _camera_zoom_tween:
		_camera_zoom_tween.kill()
	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_zoom_tween.tween_property(camera, "zoom", Vector2.ONE * 1.13, 0.55)
	if _boss_atmosphere_tween:
		_boss_atmosphere_tween.kill()
	var atmosphere_material := boss_atmosphere_overlay.material as ShaderMaterial
	var current_intensity := float(atmosphere_material.get_shader_parameter("intensity"))
	boss_atmosphere_overlay.show()
	_boss_atmosphere_tween = create_tween()
	_boss_atmosphere_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_boss_atmosphere_tween.tween_method(
		func(value: float) -> void: atmosphere_material.set_shader_parameter("intensity", value),
		current_intensity,
		1.0,
		0.55
	)


func _on_boss_battle_ended() -> void:
	_camera_trauma = 0.0
	if _camera_zoom_tween:
		_camera_zoom_tween.kill()
	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_camera_zoom_tween.tween_property(camera, "zoom", Vector2.ONE, 0.75)
	if _boss_atmosphere_tween:
		_boss_atmosphere_tween.kill()
	var atmosphere_material := boss_atmosphere_overlay.material as ShaderMaterial
	var current_intensity := float(atmosphere_material.get_shader_parameter("intensity"))
	_boss_atmosphere_tween = create_tween()
	_boss_atmosphere_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_boss_atmosphere_tween.tween_method(
		func(value: float) -> void: atmosphere_material.set_shader_parameter("intensity", value),
		current_intensity,
		0.0,
		0.75
	)
	_boss_atmosphere_tween.tween_callback(boss_atmosphere_overlay.hide)


func _on_boss_attacked() -> void:
	_camera_trauma = minf(_camera_trauma + 0.82, 1.0)


func _on_stage_transition_requested(_next_stage: int) -> void:
	if _stage_transition_active:
		return
	_stage_transition_active = true
	var transition_material := stage_transition_overlay.material as ShaderMaterial
	stage_transition_overlay.show()
	transition_material.set_shader_parameter("uncover", 0.0)
	transition_material.set_shader_parameter("progress", 0.0)
	var cover_tween := create_tween()
	cover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cover_tween.tween_method(
		func(value: float) -> void: transition_material.set_shader_parameter("progress", value),
		0.0,
		1.0,
		0.72
	)
	await cover_tween.finished
	stage_manager.complete_stage_transition()
	await get_tree().process_frame
	transition_material.set_shader_parameter("uncover", 1.0)
	transition_material.set_shader_parameter("progress", 0.0)
	var uncover_tween := create_tween()
	uncover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	uncover_tween.tween_method(
		func(value: float) -> void: transition_material.set_shader_parameter("progress", value),
		0.0,
		1.0,
		0.78
	)
	await uncover_tween.finished
	stage_transition_overlay.hide()
	_stage_transition_active = false


func _on_gold_dropped(world_position: Vector2, amount: int, is_boss_drop: bool) -> void:
	var start_position := get_viewport().get_canvas_transform() * world_position
	var target_position := resource_label.get_global_rect().get_center()
	var coin_count := 8 if is_boss_drop else 4
	for index in coin_count:
		var coin := Sprite2D.new()
		coin.texture = GOLD_TEXTURE
		coin.position = start_position + Vector2(randf_range(-18.0, 18.0), randf_range(-10.0, 12.0))
		var coin_scale := 0.065 if is_boss_drop else 0.05
		coin.scale = Vector2.ONE * coin_scale
		gold_effects.add_child(coin)
		var scatter_position := start_position + Vector2(
			randf_range(-58.0, 58.0),
			randf_range(-72.0, -28.0)
		)
		var tween := create_tween()
		tween.tween_interval(index * 0.035)
		tween.tween_property(coin, "position", scatter_position, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.18 + index * 0.025)
		tween.tween_property(coin, "position", target_position, 0.72).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(coin, "scale", Vector2.ONE * 0.018, 0.72)
		if index == coin_count - 1:
			tween.tween_callback(_pulse_gold_label)
		tween.tween_callback(coin.queue_free)
	var amount_label := Label.new()
	amount_label.text = "+%sG" % GameState.format_large_number(amount)
	amount_label.position = start_position + Vector2(-52.0, -92.0)
	amount_label.add_theme_color_override("font_color", Color("#ffe568"))
	amount_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.08, 0.02, 0.9))
	amount_label.add_theme_constant_override("shadow_offset_x", 2)
	amount_label.add_theme_constant_override("shadow_offset_y", 2)
	amount_label.add_theme_font_size_override("font_size", 20 if is_boss_drop else 16)
	gold_effects.add_child(amount_label)
	var label_tween := create_tween()
	label_tween.tween_property(amount_label, "position:y", amount_label.position.y - 28.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_tween.parallel().tween_property(amount_label, "modulate:a", 0.0, 0.75).set_delay(0.3)
	label_tween.tween_callback(amount_label.queue_free)


func _on_reward_logged(gold_amount: int, experience_amount: int, skill_bonus_gold: int) -> void:
	_add_event_log(
		"골드 +%sG  ·  경험치 +%d" % [
			GameState.format_large_number(gold_amount),
			experience_amount,
		],
		Color("#ffe06a")
	)
	if skill_bonus_gold > 0:
		_add_event_log(
			"[골드 증가] 스킬 추가 +%sG" % GameState.format_large_number(skill_bonus_gold),
			Color("#78f0ae")
		)


func _add_event_log(text: String, color: Color = Color.WHITE) -> void:
	var entry := Label.new()
	entry.text = text
	entry.modulate = color
	entry.add_theme_font_size_override("font_size", 14)
	entry.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_log_entries.add_child(entry)
	if event_log_entries.get_child_count() > 7:
		var oldest := event_log_entries.get_child(0) as Label
		_expire_event_log(oldest, 0.3)
	var lifetime_tween := entry.create_tween()
	entry.set_meta("lifetime_tween", lifetime_tween)
	lifetime_tween.tween_interval(4.2)
	lifetime_tween.tween_property(entry, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lifetime_tween.tween_callback(entry.queue_free)


func _expire_event_log(entry: Label, duration: float) -> void:
	if not is_instance_valid(entry):
		return
	var old_tween: Variant = entry.get_meta("lifetime_tween", null)
	if old_tween is Tween:
		(old_tween as Tween).kill()
	var fade := entry.create_tween()
	entry.set_meta("lifetime_tween", fade)
	fade.tween_property(entry, "modulate:a", 0.0, duration)
	fade.tween_callback(entry.queue_free)


func _pulse_gold_label() -> void:
	if _gold_label_tween:
		_gold_label_tween.kill()
	resource_label.pivot_offset = resource_label.size * 0.5
	resource_label.scale = Vector2.ONE
	_gold_label_tween = create_tween()
	_gold_label_tween.tween_property(resource_label, "scale", Vector2.ONE * 1.18, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gold_label_tween.tween_property(resource_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_camera_shake(delta: float) -> void:
	_camera_shake_time += delta * 34.0
	_camera_trauma = maxf(_camera_trauma - delta * 1.7, 0.0)
	var strength := _camera_trauma * _camera_trauma
	var target_offset := Vector2(
		sin(_camera_shake_time * 1.73) * 30.0,
		cos(_camera_shake_time * 2.27) * 19.0
	) * strength
	camera.offset = camera.offset.lerp(target_offset, minf(delta * 18.0, 1.0))
	if _camera_trauma <= 0.0 and camera.offset.length_squared() < 0.05:
		camera.offset = Vector2.ZERO


func _on_revive_requested() -> void:
	if not stage_manager.progression_paused:
		return
	var cost := stage_manager.revival_cost()
	if not GameState.spend_gold(cost):
		_show_message("부활에 필요한 골드가 부족합니다. 필요 골드: %sG" % GameState.format_large_number(cost))
		return
	if stage_manager.restart_after_revival():
		retry_button.hide()


func _open_character_panel() -> void:
	skill_panel.hide()
	_rebuild_character_rows()
	character_panel.show()


func _rebuild_character_rows() -> void:
	for child in character_cards.get_children():
		character_cards.remove_child(child)
		child.queue_free()
	for character_index in CHARACTER_DATA.size():
		var data: Dictionary = CHARACTER_DATA[character_index]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(210.0, 274.0)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#132329")
		card_style.border_color = Color("#426268")
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(12)
		card.add_theme_stylebox_override("panel", card_style)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 12)
		card.add_child(margin)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 7)
		margin.add_child(content)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(180.0, 132.0)
		portrait.texture = CHARACTER_TEXTURES[character_index]
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		var name_text := Label.new()
		name_text.text = "%s · %s" % [data["name"], data["role_name"]]
		name_text.add_theme_color_override("font_color", Color("#ffd76b"))
		name_text.add_theme_font_size_override("font_size", 19)
		name_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(name_text)
		var level_text := Label.new()
		level_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		level_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var action := Button.new()
		action.custom_minimum_size = Vector2(0.0, 44.0)
		if GameState.character_purchased[character_index]:
			var character_level: int = GameState.character_levels[character_index]
			var total_bonus: float = (
				(pow(1.0 + float(data["percent"]) / 100.0, character_level - 1) - 1.0) * 100.0
			)
			level_text.text = "Lv.%d\n%s +%.1f%% · 레벨당 +%.1f%%" % [
				character_level,
				data["stat"], total_bonus, data["percent"],
			]
			var upgrade_cost: int = GameState.character_upgrade_cost(character_index)
			action.text = "레벨 강화  %sG" % GameState.format_large_number(upgrade_cost)
			action.disabled = GameState.gold < upgrade_cost
		else:
			portrait.modulate = Color(0.35, 0.35, 0.35, 0.8)
			var purchase_cost: int = GameState.character_purchase_cost(character_index)
			level_text.text = "미보유\n구매 후 %s 강화 가능" % data["stat"]
			action.text = "구매  %sG" % GameState.format_large_number(purchase_cost)
			action.disabled = GameState.gold < purchase_cost
		action.pressed.connect(_on_character_action.bind(character_index))
		content.add_child(level_text)
		content.add_child(action)
		character_cards.add_child(card)


func _on_character_action(character_index: int) -> void:
	var data: Dictionary = CHARACTER_DATA[character_index]
	if GameState.character_purchased[character_index]:
		if GameState.upgrade_character(character_index):
			_show_message("%s 강화 완료! %s +%.1f%%" % [
				data["name"], data["stat"], data["percent"],
			])
			_add_event_log("%s Lv.%d 강화 · %s +%.1f%%" % [
				data["name"],
				GameState.character_levels[character_index],
				data["stat"],
				data["percent"],
			], Color("#7de7ff"))
	else:
		if GameState.purchase_character(character_index):
			_show_message("%s가 원정대에 합류했습니다!" % data["name"])
			_add_event_log("새 동료 %s가 원정대에 합류" % data["name"], Color("#ffcf69"))


func _on_character_roster_changed(character_index: int) -> void:
	if GameState.character_purchased[character_index] and not party_by_index.has(character_index):
		_spawn_character(character_index)
	if party_by_index.has(character_index):
		var dog: DogActor = party_by_index[character_index]
		dog.apply_progression(GameState.player_level, GameState.character_levels[character_index])
	_rebuild_character_rows()


func _open_skill_panel() -> void:
	character_panel.hide()
	_rebuild_skill_rows()
	skill_panel.show()


func _rebuild_skill_rows() -> void:
	for child in skill_rows.get_children():
		skill_rows.remove_child(child)
		child.queue_free()
	for skill_index in 2:
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color("#132329")
		row_style.border_color = Color("#426268")
		row_style.set_border_width_all(2)
		row_style.set_corner_radius_all(10)
		row.add_theme_stylebox_override("panel", row_style)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_bottom", 12)
		row.add_child(margin)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 16)
		margin.add_child(content)
		var description := Label.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var level: int = GameState.account_skill_levels[skill_index]
		if skill_index == 0:
			description.text = "골드 증가  Lv.%d\n몬스터 처치 골드 +%.2f%%\n다음 레벨 증가폭 +%.3f%%" % [
				level,
				GameState.gold_skill_total_percent(),
				GameState.gold_skill_next_increment(),
			]
		else:
			description.text = "긴급 체력 회복  Lv.%d\nHP 5%% 이하 시 %.1f%% 회복 · 쿨타임 %.1f초\n다음: 회복 +%.2f%% · 쿨타임 -%.2f초" % [
				level,
				GameState.healing_skill_recovery_percent(),
				GameState.healing_skill_cooldown(),
				GameState.healing_skill_next_increment(),
				GameState.healing_skill_next_cooldown_reduction(),
			]
		var upgrade := Button.new()
		upgrade.custom_minimum_size = Vector2(160.0, 54.0)
		var cost: int = GameState.account_skill_upgrade_cost(skill_index)
		upgrade.text = "강화  %sG" % GameState.format_large_number(cost)
		upgrade.disabled = GameState.gold < cost
		upgrade.pressed.connect(_on_skill_upgrade.bind(skill_index))
		content.add_child(description)
		content.add_child(upgrade)
		skill_rows.add_child(row)


func _on_skill_upgrade(skill_index: int) -> void:
	if not GameState.upgrade_account_skill(skill_index):
		return
	var skill_name := "골드 증가" if skill_index == 0 else "긴급 체력 회복"
	_show_message("%s Lv.%d 강화 완료!" % [
		skill_name,
		GameState.account_skill_levels[skill_index],
	])
	_add_event_log("%s Lv.%d 강화 완료" % [
		skill_name,
		GameState.account_skill_levels[skill_index],
	], Color("#9effcb"))


func _on_account_skills_changed(_skill_index: int) -> void:
	_healing_skill_cooldown_remaining = minf(
		_healing_skill_cooldown_remaining,
		GameState.healing_skill_cooldown()
	)
	_rebuild_skill_rows()


func _update_healing_skill(delta: float) -> void:
	_healing_skill_cooldown_remaining = maxf(_healing_skill_cooldown_remaining - delta, 0.0)
	if _healing_skill_cooldown_remaining > 0.0:
		return
	var targets: Array[DogActor] = []
	for dog in party:
		if is_instance_valid(dog) and not dog.health.is_dead and dog.health.ratio() <= 0.05:
			targets.append(dog)
	if targets.is_empty():
		return
	var recovery_ratio: float = GameState.healing_skill_recovery_percent() / 100.0
	for dog in targets:
		dog.health.heal(dog.health.maximum_health * recovery_ratio)
		world.add_combat_line(dog.global_position, dog.global_position + Vector2(0.0, -70.0), Color("#72f1a4"))
	_healing_skill_cooldown_remaining = GameState.healing_skill_cooldown()
	_show_message("긴급 체력 회복 발동! 최대 체력의 %.1f%% 회복" % GameState.healing_skill_recovery_percent())
	_add_event_log("[긴급 회복] HP %.1f%% 회복 · 쿨타임 %.1f초" % [
		GameState.healing_skill_recovery_percent(),
		GameState.healing_skill_cooldown(),
	], Color("#72f1a4"))


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	message_label.show()
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(2.2)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


func _show_offline_reward(reward: Dictionary) -> void:
	var hours := float(reward.get("seconds", 0)) / 3600.0
	offline_label.text = "%.1f시간 원정 보상\n골드 +%s  식량 +%d  고철 +%d  EXP +%d" % [
		hours,
		GameState.format_large_number(int(reward.get("gold", 0))),
		int(reward.get("food", 0)),
		int(reward.get("scrap", 0)),
		int(reward.get("experience", 0)),
	]
	offline_panel.show()
