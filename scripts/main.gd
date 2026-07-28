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
@onready var character_rows: VBoxContainer = $UI/CharacterPanel/Margin/VBox/CharacterRows
@onready var offline_panel: PanelContainer = $UI/OfflinePanel
@onready var offline_label: Label = $UI/OfflinePanel/Margin/VBox/Reward
@onready var gold_effects: Node2D = $GoldEffects/Coins

const CHARACTER_DATA := [
	{"name": "보리", "role": DogActor.Role.ASSAULT, "role_name": "돌격형", "stat": "최대 체력", "percent": 12},
	{"name": "탄이", "role": DogActor.Role.DAMAGE, "role_name": "공격형", "stat": "공격력", "percent": 10},
	{"name": "모카", "role": DogActor.Role.TECH, "role_name": "기술형", "stat": "스킬 피해", "percent": 12},
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
var _camera_trauma: float = 0.0
var _camera_shake_time: float = 0.0
var _gold_label_tween: Tween


func _ready() -> void:
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
	stage_manager.party_defeated.connect(_on_party_defeated)
	stage_manager.combat_message.connect(_show_message)
	GameState.resources_changed.connect(_refresh_resources)
	GameState.level_changed.connect(_on_account_level_changed)
	GameState.offline_reward_ready.connect(_show_offline_reward)
	GameState.character_roster_changed.connect(_on_character_roster_changed)
	retry_button.pressed.connect(_on_revive_requested)
	character_button.pressed.connect(_open_character_panel)
	$UI/CharacterPanel/Margin/VBox/Close.pressed.connect(character_panel.hide)
	$UI/OfflinePanel/Margin/VBox/Close.pressed.connect(offline_panel.hide)
	_refresh_resources()
	_on_stage_changed(stage_manager.current_stage)
	_on_progress_changed(0, stage_manager.enemies_before_boss, false)
	var pending_reward := GameState.consume_offline_reward()
	if not pending_reward.is_empty():
		_show_offline_reward(pending_reward)


func _process(delta: float) -> void:
	if is_instance_valid(leader):
		camera.global_position.x = lerpf(camera.global_position.x, leader.global_position.x + 180.0, 0.06)
	_update_camera_shake(delta)
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


func _on_boss_battle_ended() -> void:
	_camera_trauma = 0.0
	if _camera_zoom_tween:
		_camera_zoom_tween.kill()
	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_camera_zoom_tween.tween_property(camera, "zoom", Vector2.ONE, 0.75)


func _on_boss_attacked() -> void:
	_camera_trauma = minf(_camera_trauma + 0.82, 1.0)


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
	_rebuild_character_rows()
	character_panel.show()


func _rebuild_character_rows() -> void:
	for child in character_rows.get_children():
		character_rows.remove_child(child)
		child.queue_free()
	for character_index in CHARACTER_DATA.size():
		var data: Dictionary = CHARACTER_DATA[character_index]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, 76.0)
		row.add_theme_constant_override("separation", 16)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var action := Button.new()
		action.custom_minimum_size = Vector2(170.0, 54.0)
		if GameState.character_purchased[character_index]:
			var character_level := GameState.character_levels[character_index]
			var total_bonus := int(round(
				(pow(1.0 + float(data["percent"]) / 100.0, character_level - 1) - 1.0) * 100.0
			))
			info.text = "%s · %s · Lv.%d\n%s +%d%% (강화당 +%d%%)" % [
				data["name"], data["role_name"], character_level,
				data["stat"], total_bonus, data["percent"],
			]
			var upgrade_cost := GameState.character_upgrade_cost(character_index)
			action.text = "레벨 강화  %sG" % GameState.format_large_number(upgrade_cost)
			action.disabled = GameState.gold < upgrade_cost
		else:
			var purchase_cost := GameState.character_purchase_cost(character_index)
			info.text = "%s · %s · 미보유\n구매 후 %s 강화 가능" % [
				data["name"], data["role_name"], data["stat"],
			]
			action.text = "구매  %sG" % GameState.format_large_number(purchase_cost)
			action.disabled = GameState.gold < purchase_cost
		action.pressed.connect(_on_character_action.bind(character_index))
		row.add_child(info)
		row.add_child(action)
		character_rows.add_child(row)


func _on_character_action(character_index: int) -> void:
	var data: Dictionary = CHARACTER_DATA[character_index]
	if GameState.character_purchased[character_index]:
		if GameState.upgrade_character(character_index):
			_show_message("%s 강화 완료! %s +%d%%" % [
				data["name"], data["stat"], data["percent"],
			])
	else:
		if GameState.purchase_character(character_index):
			_show_message("%s가 원정대에 합류했습니다!" % data["name"])


func _on_character_roster_changed(character_index: int) -> void:
	if GameState.character_purchased[character_index] and not party_by_index.has(character_index):
		_spawn_character(character_index)
	if party_by_index.has(character_index):
		var dog: DogActor = party_by_index[character_index]
		dog.apply_progression(GameState.player_level, GameState.character_levels[character_index])
	_rebuild_character_rows()


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
