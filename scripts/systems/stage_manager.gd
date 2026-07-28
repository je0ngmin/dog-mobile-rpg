class_name StageManager
extends Node

signal stage_changed(stage_number: int)
signal progress_changed(kills: int, required: int, boss_active: bool)
signal boss_warning
signal boss_battle_ended
signal boss_attacked
signal gold_dropped(world_position: Vector2, amount: int, is_boss_drop: bool)
signal reward_logged(gold_amount: int, experience_amount: int, skill_bonus_gold: int)
signal stage_transition_requested(next_stage: int)
signal party_defeated
signal party_member_defeated(dog: DogActor)
signal boss_defeated
signal combat_message(text: String)

@export var enemy_scene: PackedScene
@export var actor_catalog: ActorCatalog
@export var enemies_before_boss: int = 5
@export var spawn_interval: float = 1.25

var current_stage: int = 1
var kills: int = 0
var boss_active: bool = false
var progression_paused: bool = false
var _spawn_timer: float = 0.5
var _party: Array[DogActor] = []
var _leader: DogActor
var _world: Node2D
var _pending_stage: int = 0


func setup(world: Node2D, party: Array[DogActor], starting_stage: int) -> void:
	_world = world
	_party = party
	_leader = party[0]
	current_stage = maxi(starting_stage, 1)
	for dog in _party:
		if not dog.dog_defeated.is_connected(_on_dog_defeated):
			dog.dog_defeated.connect(_on_dog_defeated)
	stage_changed.emit(current_stage)
	progress_changed.emit(kills, enemies_before_boss, boss_active)


func _process(delta: float) -> void:
	if progression_paused:
		return
	if _world == null or _all_dogs_defeated():
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var active_enemy_limit := clampi(_party.size(), 1, 3)
	if boss_active or get_tree().get_nodes_in_group("enemies").size() >= active_enemy_limit:
		_spawn_timer = 0.4
		return
	if kills >= enemies_before_boss:
		_spawn_enemy(true)
		boss_active = true
		boss_warning.emit()
		combat_message.emit("돌연변이 우두머리 출현!")
	else:
		_spawn_enemy(false)
	_spawn_timer = spawn_interval
	progress_changed.emit(kills, enemies_before_boss, boss_active)


func add_party_member(dog: DogActor) -> void:
	if dog not in _party:
		_party.append(dog)
	if not dog.dog_defeated.is_connected(_on_dog_defeated):
		dog.dog_defeated.connect(_on_dog_defeated)


func restart_after_revival() -> bool:
	if not progression_paused:
		return false
	progression_paused = false
	kills = 0
	boss_active = false
	_revive_party()
	_clear_enemies()
	_spawn_timer = 0.7
	progress_changed.emit(kills, enemies_before_boss, boss_active)
	combat_message.emit("원정대 부활! 스테이지 %d을 처음부터 다시 시작합니다." % current_stage)
	return true


func complete_stage_transition() -> void:
	if _pending_stage <= current_stage:
		return
	current_stage = _pending_stage
	_pending_stage = 0
	kills = 0
	progression_paused = false
	_spawn_timer = 0.8
	GameState.unlock_stage(current_stage)
	stage_changed.emit(current_stage)
	progress_changed.emit(kills, enemies_before_boss, boss_active)
	## combat_message.emit("새로운 구역 진입! 스테이지 %d" % current_stage)


func _spawn_enemy(as_boss: bool) -> void:
	if enemy_scene == null or actor_catalog == null:
		return
	var definition := (
		actor_catalog.boss_for_stage(current_stage)
		if as_boss
		else actor_catalog.normal_enemy_for_stage(current_stage)
	)
	if definition == null:
		push_error("스테이지에 사용할 적 ActorDefinition이 없습니다.")
		return
	var enemy := enemy_scene.instantiate() as EnemyActor
	_world.add_child(enemy)
	var camera := get_viewport().get_camera_2d()
	var spawn_x: float
	if camera:
		var visible_half_width := get_viewport().get_visible_rect().size.x / (2.0 * maxf(camera.zoom.x, 0.001))
		var offscreen_padding := 120.0 if as_boss else randf_range(55.0, 135.0)
		spawn_x = camera.global_position.x + visible_half_width + offscreen_padding
	else:
		var leader_x := _leader.global_position.x if is_instance_valid(_leader) else 500.0
		spawn_x = leader_x + 700.0
	enemy.global_position = Vector2(spawn_x, 320.0)
	enemy.configure(current_stage, as_boss, definition)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.attack_visual.connect(_relay_attack_visual.bind(as_boss))
	enemy.damage_received.connect(_relay_damage_number)


func _on_enemy_defeated(enemy: EnemyActor, loot: Dictionary) -> void:
	var defeated_position := enemy.global_position
	GameState.add_loot(loot)
	gold_dropped.emit(defeated_position, int(loot.get("gold", 0)), enemy.is_boss)
	reward_logged.emit(
		int(loot.get("gold", 0)),
		int(loot.get("experience", 0)),
		int(loot.get("gold_skill_bonus", 0))
	)
	if enemy.is_boss:
		_heal_surviving_party()
		boss_defeated.emit()
		boss_active = false
		boss_battle_ended.emit()
		progression_paused = true
		_pending_stage = current_stage + 1
		stage_transition_requested.emit(_pending_stage)
		combat_message.emit("보스를 격파했다!")
	else:
		kills += 1
	progress_changed.emit(kills, enemies_before_boss, boss_active)


func _on_dog_defeated(_dog: DogActor) -> void:
	if not _all_dogs_defeated():
		party_member_defeated.emit(_dog)
		return
	var was_boss_battle := boss_active
	progression_paused = true
	boss_active = false
	if was_boss_battle:
		boss_battle_ended.emit()
	_clear_enemies()
	party_defeated.emit()
	combat_message.emit("원정대 전멸. 골드를 사용해 모두 부활할 수 있습니다.")


func _all_dogs_defeated() -> bool:
	if _party.is_empty():
		return true
	for dog in _party:
		if is_instance_valid(dog) and not dog.health.is_dead:
			return false
	return true


func _revive_party() -> void:
	if _party.is_empty():
		return
	var origin := Vector2(240.0, 320.0)
	for index in _party.size():
		_party[index].revive(origin + Vector2(-index * 52.0, (index - 1) * 42.0))


func _heal_surviving_party() -> void:
	for dog in _party:
		if is_instance_valid(dog) and not dog.health.is_dead:
			dog.health.heal(dog.health.maximum_health)


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		(enemy as Node).queue_free()


func _relay_attack_visual(from: Vector2, to: Vector2, color: Color, from_boss: bool = false) -> void:
	if _world.has_method("add_combat_line"):
		_world.call("add_combat_line", from, to, color)
	if from_boss:
		boss_attacked.emit()


func _relay_damage_number(world_position: Vector2, amount: float, boss_hit: bool) -> void:
	if _world.has_method("add_damage_number"):
		_world.call("add_damage_number", world_position, amount, boss_hit)
