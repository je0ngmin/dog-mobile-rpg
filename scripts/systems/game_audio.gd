class_name GameAudio
extends Node

const ATTACK_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/RPG Sound Pack/battle/swing.wav"),
	preload("res://sounds/RPG Sound Pack/battle/swing2.wav"),
	preload("res://sounds/RPG Sound Pack/battle/swing3.wav"),
]
const SKILL_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/RPG Sound Pack/battle/magic1.wav"),
	preload("res://sounds/RPG Sound Pack/battle/spell.wav"),
]
const ENEMY_ATTACK_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/RPG Sound Pack/NPC/beetle/bite-small.wav"),
	preload("res://sounds/RPG Sound Pack/NPC/beetle/bite-small2.wav"),
]
const SLIME_DEFEAT_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/RPG Sound Pack/NPC/slime/slime1.wav"),
	preload("res://sounds/RPG Sound Pack/NPC/slime/slime4.wav"),
	preload("res://sounds/RPG Sound Pack/NPC/slime/slime7.wav"),
]
const BOSS_WARNING_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/RPG Sound Pack/NPC/giant/giant1.wav"),
	preload("res://sounds/RPG Sound Pack/NPC/ogre/ogre1.wav"),
]
const COIN_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/RPG Sound Pack/inventory/coin.wav"),
	preload("res://sounds/RPG Sound Pack/inventory/coin2.wav"),
	preload("res://sounds/RPG Sound Pack/inventory/coin3.wav"),
]
const UI_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/RPG Sound Pack/interface/interface1.wav"),
	preload("res://sounds/RPG Sound Pack/interface/interface2.wav"),
]
const BOSS_DEFEAT_SOUND := preload("res://sounds/RPG Sound Pack/interface/interface6.wav")
const REVIVE_SOUND := preload("res://sounds/RPG Sound Pack/battle/magic1.wav")
const NORMAL_BGM_STREAM: AudioStreamMP3 = preload("res://sounds/bgms/dreamy_rabbit-8-bit-game-music-122259.mp3")
const BOSS_BGM_STREAM: AudioStreamMP3 = preload("res://sounds/bgms/blackbox-black-box-sudden-attack-edm-15551.mp3")

@export_range(-40.0, 0.0, 1.0) var master_sfx_volume_db: float = -5.0
@export_range(-40.0, -2.0, 1.0) var bgm_volume_db: float = -8.0
@export_range(4, 32, 1) var maximum_voices: int = 14

var _last_played_msec: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _bgm_transition_tween: Tween
var _boss_music_active: bool = false
var _current_bgm_mode: StringName = &"normal"


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGM"
	_bgm_player.stream = _make_looped_bgm(NORMAL_BGM_STREAM)
	_bgm_player.volume_db = bgm_volume_db
	add_child(_bgm_player)
	if OS.has_feature("web"):
		set_process_input(true)
	else:
		_start_bgm()


func _input(event: InputEvent) -> void:
	if _bgm_player == null or _bgm_player.playing:
		return
	if (
		event is InputEventMouseButton
		or event is InputEventScreenTouch
		or event is InputEventKey
	):
		_start_bgm()


func _start_bgm() -> void:
	if _bgm_player == null or _bgm_player.playing:
		return
	_bgm_player.play()
	set_process_input(false)


func set_bgm_volume(new_volume_db: float) -> void:
	bgm_volume_db = clampf(new_volume_db, -40.0, 0.0)
	if _bgm_player != null:
		_bgm_player.volume_db = bgm_volume_db


func set_sfx_volume(new_volume_db: float) -> void:
	master_sfx_volume_db = clampf(new_volume_db, -40.0, 0.0)


func enter_boss_music() -> void:
	_boss_music_active = true
	_transition_bgm(BOSS_BGM_STREAM)


func exit_boss_music() -> void:
	_boss_music_active = false
	_transition_bgm(NORMAL_BGM_STREAM)


func is_boss_music_active() -> bool:
	return _boss_music_active


func current_bgm_mode() -> StringName:
	return _current_bgm_mode


func _transition_bgm(next_stream: AudioStreamMP3) -> void:
	if _bgm_player == null:
		return
	if _bgm_transition_tween:
		_bgm_transition_tween.kill()
	if not _bgm_player.playing:
		_bgm_player.stream = _make_looped_bgm(next_stream)
		_current_bgm_mode = &"boss" if next_stream == BOSS_BGM_STREAM else &"normal"
		_bgm_player.volume_db = bgm_volume_db
		return
	_bgm_transition_tween = create_tween()
	_bgm_transition_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bgm_transition_tween.tween_property(_bgm_player, "volume_db", -40.0, 0.28)
	_bgm_transition_tween.tween_callback(
		func() -> void:
			_bgm_player.stream = _make_looped_bgm(next_stream)
			_current_bgm_mode = &"boss" if next_stream == BOSS_BGM_STREAM else &"normal"
			_bgm_player.play()
	)
	_bgm_transition_tween.tween_property(_bgm_player, "volume_db", bgm_volume_db, 0.38)


func _make_looped_bgm(source_stream: AudioStreamMP3) -> AudioStreamMP3:
	var looped_bgm := source_stream.duplicate() as AudioStreamMP3
	looped_bgm.loop = true
	return looped_bgm


func _exit_tree() -> void:
	for child in get_children():
		var player := child as AudioStreamPlayer
		if player != null:
			player.stop()


func play_attack() -> void:
	_play_random(ATTACK_SOUNDS, -13.0, 0.92, 1.08, &"attack", 70)


func play_skill() -> void:
	_play_random(SKILL_SOUNDS, -9.0, 0.96, 1.05, &"skill", 180)


func play_enemy_attack(boss_attack: bool = false) -> void:
	if boss_attack:
		_play_random(ATTACK_SOUNDS, -8.0, 0.68, 0.78, &"boss_attack", 150)
	else:
		_play_random(ENEMY_ATTACK_SOUNDS, -17.0, 0.94, 1.08, &"enemy_attack", 110)


func play_enemy_defeated(boss_defeat: bool = false) -> void:
	if boss_defeat:
		_play_stream(BOSS_DEFEAT_SOUND, -3.0, 0.92, &"boss_defeat", 500)
	else:
		_play_random(SLIME_DEFEAT_SOUNDS, -12.0, 0.92, 1.08, &"enemy_defeat", 100)


func play_coin(boss_reward: bool = false) -> void:
	_play_random(COIN_SOUNDS, -7.0 if boss_reward else -12.0, 0.96, 1.08, &"coin", 130)


func play_boss_warning() -> void:
	_play_random(BOSS_WARNING_SOUNDS, -4.0, 0.78, 0.9, &"boss_warning", 900)


func play_revive() -> void:
	_play_stream(REVIVE_SOUND, -5.0, 0.76, &"revive", 700)


func play_ui() -> void:
	_play_random(UI_SOUNDS, -12.0, 0.98, 1.04, &"ui", 65)


func _play_random(
	streams: Array[AudioStream],
	volume_db: float,
	minimum_pitch: float,
	maximum_pitch: float,
	cooldown_key: StringName,
	cooldown_msec: int
) -> void:
	if streams.is_empty():
		return
	_play_stream(
		streams[randi() % streams.size()],
		volume_db,
		randf_range(minimum_pitch, maximum_pitch),
		cooldown_key,
		cooldown_msec
	)


func _play_stream(
	stream: AudioStream,
	volume_db: float,
	pitch_scale: float,
	cooldown_key: StringName,
	cooldown_msec: int
) -> void:
	if stream == null or get_child_count() >= maximum_voices:
		return
	var now := Time.get_ticks_msec()
	var last_played := int(_last_played_msec.get(cooldown_key, -cooldown_msec))
	if now - last_played < cooldown_msec:
		return
	_last_played_msec[cooldown_key] = now
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = master_sfx_volume_db + volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
