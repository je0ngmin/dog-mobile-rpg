extends Node

@export var dog_scene: PackedScene
@export var enemy_scene: PackedScene
@export var actor_catalog: ActorCatalog

@onready var world: WorldView = $World
@onready var stage_manager: StageManager = $StageManager
@onready var camera: Camera2D = $World/Camera2D
@onready var stage_label: Label = $UI/BossProgress/Stage
@onready var resource_label: Label = $UI/TopBar/Margin/VBox/HBoxContainer/Resources
@onready var level_label: Label = $UI/TopBar/Margin/VBox/LevelContainer/Level
@onready var progress_bar: ProgressBar = $UI/BossProgress
@onready var progress_label: Label = $UI/BossProgress/Label
@onready var message_label: Label = $UI/Message
@onready var character_button: Button = $UI/CharacterButton
@onready var character_panel: PanelContainer = $UI/CharacterPanel
@onready var character_cards: HBoxContainer = $UI/CharacterPanel/Margin/VBox/CharacterScroll/CharacterCards
@onready var skill_button: Button = $UI/SkillButton
@onready var skill_panel: PanelContainer = $UI/SkillPanel
@onready var skill_rows: VBoxContainer = $UI/SkillPanel/Margin/VBox/SkillRows
@onready var offline_panel: PanelContainer = $UI/OfflinePanel
@onready var offline_label: Label = $UI/OfflinePanel/Margin/VBox/Reward
@onready var settings_button: Button = $UI/SettingsButton
@onready var debug_stage_button: Button = $UI/DebugStageButton
@onready var settings_panel: PanelContainer = $UI/SettingsPanel
@onready var bgm_slider: HSlider = $UI/SettingsPanel/Margin/VBox/BGMSlider
@onready var sfx_slider: HSlider = $UI/SettingsPanel/Margin/VBox/SFXSlider
@onready var bgm_value_label: Label = $UI/SettingsPanel/Margin/VBox/BGMValue
@onready var sfx_value_label: Label = $UI/SettingsPanel/Margin/VBox/SFXValue
@onready var delete_data_button: Button = $UI/SettingsPanel/Margin/VBox/DeleteData
@onready var delete_data_confirmation: ConfirmationDialog = $UI/DeleteDataConfirmation
@onready var stage_background: Sprite2D = $World/Camera2D/Background
@onready var game_clear_overlay: ColorRect = $UI/GameClearOverlay
@onready var game_clear_replay_button: Button = $UI/GameClearOverlay/ClearPanel/Margin/VBox/Replay
@onready var gold_effects: Node2D = $GoldEffects/Coins
@onready var stage_transition_overlay: ColorRect = $StageTransition/Overlay
@onready var boss_atmosphere_overlay: ColorRect = $BossAtmosphere/Overlay
@onready var party_speech_bubble: Control = $World/PartySpeechBubble
@onready var game_audio: Node = $GameAudio
var event_log_entries: VBoxContainer

const FORMATION_OFFSETS := [Vector2.ZERO, Vector2(-60.0, -42.0), Vector2(-112.0, 38.0)]
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
var _boss_text_effect: HBoxContainer
var _boss_text_tweens: Array[Tween] = []
var _boss_progress_active: bool = false
var _boss_progress_pulse_tween: Tween
var _previous_boss_progress_value: float = -1.0
var _message_text_effect: HBoxContainer
var _message_text_tweens: Array[Tween] = []
var _auto_revive_active: bool = false


func _ready() -> void:
	debug_stage_button.visible = OS.is_debug_build()
	game_audio.set_bgm_volume(GameState.bgm_volume_db)
	game_audio.set_sfx_volume(GameState.sfx_volume_db)
	bgm_slider.set_value_no_signal(GameState.bgm_volume_db)
	sfx_slider.set_value_no_signal(GameState.sfx_volume_db)
	_update_audio_setting_labels()
	_create_event_log()
	_create_party()
	stage_manager.enemy_scene = enemy_scene
	stage_manager.actor_catalog = actor_catalog
	stage_manager.setup(world, party, GameState.highest_stage)
	_stage_manager_ready = true
	stage_manager.stage_changed.connect(_on_stage_changed)
	stage_manager.progress_changed.connect(_on_progress_changed)
	stage_manager.boss_warning.connect(_on_boss_battle_started)
	stage_manager.boss_battle_ended.connect(_on_boss_battle_ended)
	stage_manager.boss_attacked.connect(_on_boss_attacked)
	stage_manager.enemy_attacked.connect(game_audio.play_enemy_attack)
	stage_manager.enemy_defeated_audio.connect(game_audio.play_enemy_defeated)
	stage_manager.gold_dropped.connect(_on_gold_dropped)
	stage_manager.reward_logged.connect(_on_reward_logged)
	stage_manager.stage_transition_requested.connect(_on_stage_transition_requested)
	stage_manager.party_defeated.connect(_on_party_defeated)
	stage_manager.party_member_defeated.connect(_on_party_member_defeated)
	stage_manager.boss_defeated.connect(_on_boss_defeated_dialogue)
	stage_manager.game_cleared.connect(_on_game_cleared)
	stage_manager.combat_message.connect(_show_message)
	stage_manager.combat_message.connect(_add_event_log)
	GameState.resources_changed.connect(_refresh_resources)
	GameState.level_changed.connect(_on_account_level_changed)
	GameState.offline_reward_ready.connect(_show_offline_reward)
	GameState.character_roster_changed.connect(_on_character_roster_changed)
	GameState.account_skills_changed.connect(_on_account_skills_changed)
	character_button.pressed.connect(_open_character_panel)
	skill_button.pressed.connect(_open_skill_panel)
	settings_button.pressed.connect(_open_settings_panel)
	debug_stage_button.pressed.connect(_on_debug_stage_button_pressed)
	$UI/CharacterPanel/Margin/VBox/Close.pressed.connect(character_panel.hide)
	$UI/SkillPanel/Margin/VBox/Close.pressed.connect(skill_panel.hide)
	$UI/OfflinePanel/Margin/VBox/Close.pressed.connect(offline_panel.hide)
	$UI/SettingsPanel/Margin/VBox/Close.pressed.connect(settings_panel.hide)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	bgm_slider.drag_ended.connect(_on_audio_slider_drag_ended)
	sfx_slider.drag_ended.connect(_on_audio_slider_drag_ended)
	delete_data_button.pressed.connect(_on_delete_data_requested)
	delete_data_confirmation.confirmed.connect(_delete_data_and_restart)
	game_clear_replay_button.pressed.connect(_on_game_clear_replay_pressed)
	for ui_button: Button in [
		character_button,
		skill_button,
		settings_button,
		debug_stage_button,
		$UI/CharacterPanel/Margin/VBox/Close,
		$UI/SkillPanel/Margin/VBox/Close,
		$UI/OfflinePanel/Margin/VBox/Close,
		$UI/SettingsPanel/Margin/VBox/Close,
		delete_data_button,
		game_clear_replay_button,
	]:
		ui_button.pressed.connect(game_audio.play_ui)
	_refresh_resources()
	_on_stage_changed(stage_manager.current_stage)
	_on_progress_changed(0, stage_manager.enemies_before_boss, false)
	var pending_reward: Dictionary = GameState.consume_offline_reward()
	if not pending_reward.is_empty():
		_show_offline_reward(pending_reward)


func _create_event_log() -> void:
	var panel := PanelContainer.new()
	panel.name = "EventLog"
	panel.z_index = -1
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
	panel_style.border_color = Color(0.55, 0.43, 0.22, 0.72)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", panel_style)
	$UI.add_child(panel)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 5)
	panel.add_child(contents)

	event_log_entries = VBoxContainer.new()
	event_log_entries.name = "Entries"
	event_log_entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_log_entries.add_theme_constant_override("separation", 3)
	event_log_entries.alignment = BoxContainer.ALIGNMENT_END
	contents.add_child(event_log_entries)


func _process(delta: float) -> void:
	if is_instance_valid(leader):
		camera.global_position.x = lerpf(camera.global_position.x, leader.global_position.x + 180.0, 0.06)
	_update_party_speech_bubble_position()
	_update_camera_shake(delta)
	_update_healing_skill(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		GameState.save_game()


func _create_party() -> void:
	for index in mini(GameState.character_purchased.size(), actor_catalog.characters.size()):
		if GameState.character_purchased[index]:
			_spawn_character(index)
	camera.global_position = Vector2(leader.global_position.x + 180.0, 324.0)


func _spawn_character(character_index: int) -> void:
	if party_by_index.has(character_index):
		return
	var definition := actor_catalog.character_at(character_index)
	if definition == null or character_index >= FORMATION_OFFSETS.size():
		push_error("캐릭터 ActorDefinition 또는 편성 위치가 없습니다: %d" % character_index)
		return
	var dog := dog_scene.instantiate() as DogActor
	dog.configure(definition, FORMATION_OFFSETS[character_index], leader)
	world.add_child(dog)
	var spawn_origin := Vector2(250.0, 320.0)
	if is_instance_valid(leader):
		spawn_origin = leader.global_position
	dog.global_position = spawn_origin + FORMATION_OFFSETS[character_index]
	dog.apply_progression(GameState.player_level, GameState.character_levels[character_index])
	dog.apply_defense_bonus(GameState.defense_skill_total_percent())
	dog.attack_visual.connect(_on_dog_attack_visual)
	dog.skill_visual.connect(_on_dog_skill_visual)
	party.append(dog)
	party_by_index[character_index] = dog
	if character_index == 0:
		leader = dog
		dog.leader = null
	if _stage_manager_ready:
		stage_manager.add_party_member(dog)


func _on_dog_attack_visual(from: Vector2, to: Vector2, color: Color) -> void:
	world.add_combat_line(from, to, color)
	game_audio.play_attack()


func _on_dog_skill_visual(from: Vector2, to: Vector2, color: Color) -> void:
	world.add_combat_line(from, to, color)
	game_audio.play_skill()


func _refresh_resources() -> void:
	resource_label.text = "%sG" % GameState.format_large_number(GameState.gold)
	level_label.text = "원정대 Lv.%d  EXP %d/%d" % [
		GameState.player_level, GameState.experience, GameState.experience_to_next_level()
	]
	if character_panel.visible:
		_rebuild_character_rows()
	if skill_panel.visible:
		_rebuild_skill_rows()


func _on_stage_changed(stage_number: int) -> void:
	var area := ((stage_number - 1) / 5) + 1
	var local_stage := ((stage_number - 1) % 5) + 1
	stage_background.set_stage(stage_number)
	stage_label.text = "버려진 주택가  %d-%d" % [area, local_stage]
	for character_index in party_by_index:
		var dog: DogActor = party_by_index[character_index]
		dog.apply_progression(GameState.player_level, GameState.character_levels[character_index])


func _on_progress_changed(kills: int, required: int, boss_active: bool) -> void:
	progress_bar.max_value = required
	var next_progress_value := float(required if boss_active else kills)
	var progress_increased := (
		_previous_boss_progress_value >= 0.0
		and next_progress_value > _previous_boss_progress_value
	)
	progress_bar.value = next_progress_value
	_previous_boss_progress_value = next_progress_value
	if progress_increased:
		_play_boss_progress_pulse()
	if boss_active:
		progress_label.hide()
		if not _boss_progress_active:
			_play_boss_progress_text()
	else:
		_stop_boss_progress_text()
		progress_label.text = "보스 출현까지  %d / %d" % [kills, required]
		progress_label.show()
	_boss_progress_active = boss_active


func _play_boss_progress_pulse() -> void:
	if _boss_progress_pulse_tween:
		_boss_progress_pulse_tween.kill()
	progress_bar.pivot_offset = progress_bar.size * 0.5
	progress_bar.scale = Vector2.ONE
	_boss_progress_pulse_tween = create_tween()
	_boss_progress_pulse_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_boss_progress_pulse_tween.tween_property(
		progress_bar,
		"scale",
		Vector2(1.045, 1.13),
		0.11
	).set_trans(Tween.TRANS_BACK)
	_boss_progress_pulse_tween.tween_property(
		progress_bar,
		"scale",
		Vector2(0.99, 0.965),
		0.09
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_boss_progress_pulse_tween.tween_property(
		progress_bar,
		"scale",
		Vector2.ONE,
		0.2
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _play_boss_progress_text() -> void:
	_stop_boss_progress_text()
	var boss_text := "BOSS 전투 중"
	_boss_text_effect = HBoxContainer.new()
	_boss_text_effect.name = "BossTextEffect"
	_boss_text_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_text_effect.offset_top = 17.0
	_boss_text_effect.offset_bottom = 17.0
	_boss_text_effect.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_text_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_text_effect.z_index = 0
	progress_bar.add_child(_boss_text_effect)
	_populate_wave_text(
		_boss_text_effect,
		boss_text,
		Color("#ffca58"),
		15,
		18.0,
		34.0,
		progress_label.label_settings,
		_boss_text_tweens
	)


func _populate_wave_text(
	container: HBoxContainer,
	text: String,
	color: Color,
	font_size: int,
	character_width: float,
	character_height: float,
	settings: LabelSettings,
	tweens: Array[Tween]
) -> void:
	for index in text.length():
		var character := text.substr(index, 1)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(character_width * 0.5 if character == " " else character_width, character_height)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(slot)
		var letter := Label.new()
		letter.text = character
		letter.size = slot.custom_minimum_size
		letter.pivot_offset = letter.size * 0.5
		letter.label_settings = settings
		letter.add_theme_font_size_override("font_size", font_size)
		letter.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.01, 0.9))
		letter.add_theme_constant_override("shadow_offset_x", 2)
		letter.add_theme_constant_override("shadow_offset_y", 2)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.modulate = color
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(letter)
		var wave := letter.create_tween().set_loops()
		tweens.append(wave)
		wave.tween_interval(index * 0.055)
		wave.tween_property(letter, "position:y", -8.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		wave.parallel().tween_property(letter, "scale:y", 1.2, 0.14)
		wave.parallel().tween_property(letter, "rotation", -0.055, 0.14)
		wave.tween_property(letter, "position:y", 3.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		wave.parallel().tween_property(letter, "scale:y", 0.9, 0.12)
		wave.parallel().tween_property(letter, "rotation", 0.04, 0.12)
		wave.tween_property(letter, "position:y", 0.0, 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		wave.parallel().tween_property(letter, "scale:y", 1.0, 0.17)
		wave.parallel().tween_property(letter, "rotation", 0.0, 0.17)
		wave.tween_interval((text.length() - index - 1) * 0.055 + 0.25)


func _stop_boss_progress_text() -> void:
	for tween in _boss_text_tweens:
		if tween:
			tween.kill()
	_boss_text_tweens.clear()
	if is_instance_valid(_boss_text_effect):
		_boss_text_effect.queue_free()
	_boss_text_effect = null


func _on_account_level_changed(new_level: int) -> void:
	for character_index in party_by_index:
		var dog: DogActor = party_by_index[character_index]
		dog.apply_progression(new_level, GameState.character_levels[character_index])
	var gain_percent := GameState.account_level_gain_percent(new_level)
	_show_message("원정대 레벨 %d! 전체 체력·공격력 +%.1f%%" % [new_level, gain_percent])
	_add_event_log(
		"원정대 Lv.%d 달성 · 전체 체력·공격력 +%.1f%%" % [new_level, gain_percent],
		Color("#7de7ff")
	)


func _on_party_defeated() -> void:
	if _auto_revive_active:
		return
	_auto_revive_active = true
	var gold_before := GameState.gold
	var penalty := ceili(float(gold_before) * 0.3)
	GameState.spend_gold(penalty)
	_add_event_log(
		"원정대 전멸 · 골드 30%% 감소 (-%sG)" % GameState.format_large_number(penalty),
		Color("#ff8d8d")
	)
	game_audio.play_revive()
	await _play_screen_transition(stage_manager.restart_after_revival)
	party_speech_bubble.show_normal(true)
	_auto_revive_active = false


func _on_party_member_defeated(dog: DogActor) -> void:
	party_speech_bubble.show_teammate_down(dog.display_name)


func _on_boss_defeated_dialogue() -> void:
	party_speech_bubble.show_boss_defeated()


func _on_game_cleared(_stage_number: int) -> void:
	character_panel.hide()
	skill_panel.hide()
	settings_panel.hide()
	offline_panel.hide()
	game_clear_overlay.show()
	_add_event_log("3-5 최종 보스 격파 · 게임 클리어!", Color("#ffe06a"))


func _on_game_clear_replay_pressed() -> void:
	game_clear_overlay.hide()
	stage_manager.replay_cleared_stage()
	party_speech_bubble.show_normal(true)
	_show_message("3-5 반복 원정을 시작합니다!")


func _on_debug_stage_button_pressed() -> void:
	game_clear_overlay.hide()
	GameState.apply_debug_final_stage_loadout()
	stage_manager.debug_jump_to_stage(StageManager.MAX_STAGE)
	_show_message("디버그: 3-5 · 전원 Lv.50 · 골드 10억G")


func _on_boss_battle_started() -> void:
	game_audio.enter_boss_music()
	game_audio.play_boss_warning()
	party_speech_bubble.show_boss_arrived()
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
	game_audio.exit_boss_music()
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
	await _play_screen_transition(stage_manager.complete_stage_transition)


func _play_screen_transition(midpoint_action: Callable) -> void:
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
	midpoint_action.call()
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
	game_audio.play_coin(is_boss_drop)
	var start_position := _world_to_gold_effects_position(world_position)
	var coin_count := 8 if is_boss_drop else 4
	for index in coin_count:
		var coin := Sprite2D.new()
		coin.texture = GOLD_TEXTURE
		coin.position = start_position + Vector2(randf_range(-18.0, 18.0), randf_range(-10.0, 12.0))
		var coin_scale := 0.2 if is_boss_drop else 0.3
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
		var home_coin := func(progress: float) -> void:
			if is_instance_valid(coin):
				var live_target := _control_center_to_gold_effects_position(resource_label)
				coin.position = scatter_position.lerp(live_target, progress)
		tween.tween_method(
			home_coin,
			0.0,
			1.0,
			0.72
		).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(coin, "scale", Vector2.ONE * 0.2, 0.72)
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


func _world_to_gold_effects_position(world_position: Vector2) -> Vector2:
	var canvas_position := get_viewport().get_canvas_transform() * world_position
	return gold_effects.get_global_transform_with_canvas().affine_inverse() * canvas_position


func _control_center_to_gold_effects_position(control: Control) -> Vector2:
	var canvas_position := control.get_global_transform_with_canvas() * (control.size * 0.5)
	return gold_effects.get_global_transform_with_canvas().affine_inverse() * canvas_position


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
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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


func _update_party_speech_bubble_position() -> void:
	var anchor_dog: DogActor
	if is_instance_valid(leader) and not leader.health.is_dead:
		anchor_dog = leader
	for dog in party:
		if anchor_dog == null and is_instance_valid(dog) and not dog.health.is_dead:
			anchor_dog = dog
	if anchor_dog == null:
		party_speech_bubble.hide()
		return
	party_speech_bubble.show()
	party_speech_bubble.global_position = anchor_dog.global_position + Vector2(
		-party_speech_bubble.size.x * 0.5,
		28.0
	)


func _open_settings_panel() -> void:
	character_panel.hide()
	skill_panel.hide()
	offline_panel.hide()
	settings_panel.show()


func _on_bgm_volume_changed(value: float) -> void:
	GameState.bgm_volume_db = value
	game_audio.set_bgm_volume(value)
	_update_audio_setting_labels()


func _on_sfx_volume_changed(value: float) -> void:
	GameState.sfx_volume_db = value
	game_audio.set_sfx_volume(value)
	_update_audio_setting_labels()


func _on_audio_slider_drag_ended(_value_changed: bool) -> void:
	GameState.save_game()


func _update_audio_setting_labels() -> void:
	bgm_value_label.text = "BGM  %d dB" % int(round(GameState.bgm_volume_db))
	sfx_value_label.text = "FX 사운드  %d dB" % int(round(GameState.sfx_volume_db))


func _on_delete_data_requested() -> void:
	delete_data_confirmation.popup_centered()


func _delete_data_and_restart() -> void:
	delete_data_button.disabled = true
	if not GameState.delete_save_data():
		delete_data_button.disabled = false
		_show_message("저장 데이터를 삭제하지 못했습니다.")
		return
	await get_tree().process_frame
	var reload_error := get_tree().reload_current_scene()
	if reload_error != OK:
		get_tree().quit()


func _open_character_panel() -> void:
	skill_panel.hide()
	settings_panel.hide()
	_rebuild_character_rows()
	character_panel.show()


func _rebuild_character_rows() -> void:
	for child in character_cards.get_children():
		character_cards.remove_child(child)
		child.queue_free()
	for character_index in actor_catalog.characters.size():
		var definition := actor_catalog.character_at(character_index)
		if definition == null:
			continue
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(210.0, 286.0)
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
		portrait.custom_minimum_size = Vector2(180.0, 112.0)
		portrait.texture = definition.texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		var name_text := Label.new()
		name_text.text = "%s · %s" % [definition.display_name, definition.role_name]
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
			var combat_values := _character_combat_values(definition, character_level)
			var cooldown_reduction := GameState.character_attack_cooldown_reduction_percent(character_level)
			var total_bonus: float = (
				(pow(1.0 + definition.upgrade_percent / 100.0, character_level - 1) - 1.0) * 100.0
			)
			level_text.text = "Lv.%d\nHP %s · 공격력 %s\n%s +%.1f%% · 레벨당 +%.1f%%\n공격 쿨타임 -%.1f%%" % [
				character_level,
				GameState.format_large_number(int(round(combat_values.x))),
				GameState.format_large_number(int(round(combat_values.y))),
				definition.upgrade_stat_name, total_bonus, definition.upgrade_percent, cooldown_reduction,
			]
			var upgrade_cost: int = GameState.character_upgrade_cost(character_index)
			action.text = "레벨 강화  %sG" % GameState.format_large_number(upgrade_cost)
			action.disabled = GameState.gold < upgrade_cost
		else:
			portrait.modulate = Color(0.35, 0.35, 0.35, 0.8)
			var purchase_cost: int = GameState.character_purchase_cost(character_index)
			var base_values := _character_combat_values(definition, 1)
			level_text.text = "미보유\n기본 HP %s · 공격력 %s\n구매 후 %s 강화 가능" % [
				GameState.format_large_number(int(round(base_values.x))),
				GameState.format_large_number(int(round(base_values.y))),
				definition.upgrade_stat_name,
			]
			action.text = "구매  %sG" % GameState.format_large_number(purchase_cost)
			action.disabled = GameState.gold < purchase_cost
		action.pressed.connect(_on_character_action.bind(character_index))
		content.add_child(level_text)
		content.add_child(action)
		character_cards.add_child(card)


func _character_combat_values(definition: ActorDefinition, character_level: int) -> Vector2:
	var account_multiplier := GameState.account_level_stat_multiplier(GameState.player_level)
	var upgrade_count := maxi(character_level - 1, 0)
	var health := (
		definition.base_health
		* account_multiplier
		* pow(1.0 + definition.health_per_upgrade_percent / 100.0, upgrade_count)
	)
	var attack_value := (
		definition.base_attack
		* account_multiplier
		* pow(1.0 + definition.attack_per_upgrade_percent / 100.0, upgrade_count)
	)
	return Vector2(health, attack_value)


func _on_character_action(character_index: int) -> void:
	game_audio.play_ui()
	var definition := actor_catalog.character_at(character_index)
	if definition == null:
		return
	if GameState.character_purchased[character_index]:
		if GameState.upgrade_character(character_index):
			_show_message("%s 강화! %s +%.1f%% · 공격 쿨타임 -%.1f%%" % [
				definition.display_name,
				definition.upgrade_stat_name,
				definition.upgrade_percent,
				GameState.ATTACK_COOLDOWN_REDUCTION_PER_CHARACTER_LEVEL,
			])
			_add_event_log("%s Lv.%d · %s +%.1f%% · 공격 쿨타임 -%.1f%%" % [
				definition.display_name,
				GameState.character_levels[character_index],
				definition.upgrade_stat_name,
				definition.upgrade_percent,
				GameState.ATTACK_COOLDOWN_REDUCTION_PER_CHARACTER_LEVEL,
			], Color("#7de7ff"))
	else:
		if GameState.purchase_character(character_index):
			_show_message("%s가 원정대에 합류했습니다!" % definition.display_name)
			_add_event_log(
				"새 동료 %s가 원정대에 합류" % definition.display_name,
				Color("#ffcf69")
			)


func _on_character_roster_changed(character_index: int) -> void:
	if GameState.character_purchased[character_index] and not party_by_index.has(character_index):
		_spawn_character(character_index)
	if party_by_index.has(character_index):
		var dog: DogActor = party_by_index[character_index]
		dog.apply_progression(GameState.player_level, GameState.character_levels[character_index])
	_rebuild_character_rows()


func _open_skill_panel() -> void:
	character_panel.hide()
	settings_panel.hide()
	_rebuild_skill_rows()
	skill_panel.show()


func _rebuild_skill_rows() -> void:
	for child in skill_rows.get_children():
		skill_rows.remove_child(child)
		child.queue_free()
	for skill_index in GameState.account_skill_levels.size():
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
		match skill_index:
			0:
				description.text = "골드 증가  Lv.%d\n몬스터 처치 골드 +%.2f%%\n다음 레벨 증가폭 +%.3f%%" % [
					level,
					GameState.gold_skill_total_percent(),
					GameState.gold_skill_next_increment(),
				]
			1:
				description.text = "긴급 체력 회복  Lv.%d\nHP 5%% 이하 시 %.1f%% 회복 · 쿨타임 %.1f초\n다음: 회복 +%.2f%% · 쿨타임 -%.2f초" % [
					level,
					GameState.healing_skill_recovery_percent(),
					GameState.healing_skill_cooldown(),
					GameState.healing_skill_next_increment(),
					GameState.healing_skill_next_cooldown_reduction(),
				]
			2:
				description.text = "방어력 증가  Lv.%d\n모든 캐릭터가 받는 피해 -%.2f%%\n다음 레벨 피해 감소 +%.3f%%" % [
					level,
					GameState.defense_skill_total_percent(),
					GameState.defense_skill_next_increment(),
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
	game_audio.play_ui()
	if not GameState.upgrade_account_skill(skill_index):
		return
	var skill_names := ["골드 증가", "긴급 체력 회복", "방어력 증가"]
	var skill_name: String = skill_names[skill_index]
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
	for dog in party:
		if is_instance_valid(dog):
			dog.apply_defense_bonus(GameState.defense_skill_total_percent())
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
	if text.begins_with("보스를 격파했다!"):
		_play_boss_defeat_message(text)
		return
	_stop_message_text_effect()
	message_label.text = text
	message_label.modulate.a = 1.0
	message_label.show()
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(2.2)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


func _play_boss_defeat_message(text: String) -> void:
	if _message_tween:
		_message_tween.kill()
	_stop_message_text_effect()
	message_label.hide()
	_message_text_effect = HBoxContainer.new()
	_message_text_effect.name = "BossDefeatTextEffect"
	_message_text_effect.position = message_label.position
	_message_text_effect.size = message_label.size
	_message_text_effect.alignment = BoxContainer.ALIGNMENT_CENTER
	_message_text_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_text_effect.z_index = message_label.z_index + 1
	$UI.add_child(_message_text_effect)
	_populate_wave_text(
		_message_text_effect,
		text,
		Color("#ffd05a"),
		22,
		22.0,
		message_label.size.y,
		message_label.label_settings,
		_message_text_tweens
	)
	_message_tween = create_tween()
	_message_tween.tween_interval(2.2)
	_message_tween.tween_property(_message_text_effect, "modulate:a", 0.0, 0.5)
	_message_tween.tween_callback(_finish_message_text_effect)


func _finish_message_text_effect() -> void:
	for tween in _message_text_tweens:
		if tween:
			tween.kill()
	_message_text_tweens.clear()
	if is_instance_valid(_message_text_effect):
		_message_text_effect.queue_free()
	_message_text_effect = null
	_message_tween = null


func _stop_message_text_effect() -> void:
	for tween in _message_text_tweens:
		if tween:
			tween.kill()
	_message_text_tweens.clear()
	if is_instance_valid(_message_text_effect):
		_message_text_effect.queue_free()
	_message_text_effect = null


func _show_offline_reward(reward: Dictionary) -> void:
	settings_panel.hide()
	var hours := float(reward.get("seconds", 0)) / 3600.0
	offline_label.text = "%.1f시간 원정 보상\n골드 +%s  EXP +%d" % [
		hours,
		GameState.format_large_number(int(reward.get("gold", 0))),
		int(reward.get("experience", 0)),
	]
	offline_panel.show()
