class_name DogActor
extends CharacterBody2D

signal dog_defeated(dog: DogActor)
signal attack_visual(from: Vector2, to: Vector2, color: Color)
signal skill_visual(from: Vector2, to: Vector2, color: Color)

enum Role { ASSAULT, DAMAGE, TECH }

const UI_FONT := preload("res://fonts/AstaSans-SemiBold.ttf")

@export var role: Role = Role.ASSAULT
@export var display_name: String = "바둑이"
@export var move_speed: float = 105.0

@onready var health: HealthComponent = $HealthComponent
@onready var attack: AttackComponent = $AttackComponent
@onready var skill: AutoSkillComponent = $AutoSkillComponent
@onready var visual_pivot: Node2D = $VisualPivot
@onready var character_sprite: Sprite2D = $VisualPivot/Sprite2D

var target: Node2D
var definition: ActorDefinition
var formation_offset := Vector2.ZERO
var leader: DogActor
var character_level: int = 1
var _body_color := Color("#d8a45d")
var _animation_phase: float = 0.0
var _squash_amount: float = 0.0
var _rotation_amount: float = 0.0


func _ready() -> void:
	add_to_group("dogs")
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	attack.attack_performed.connect(_on_attack)
	skill.skill_used.connect(_on_skill)
	_apply_role_stats()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	target = _find_nearest_enemy()
	var is_attacking := false
	var destination_x := global_position.x + 100.0
	if leader != null and is_instance_valid(leader):
		destination_x = leader.global_position.x + formation_offset.x
	if target != null and is_instance_valid(target):
		var distance := global_position.distance_to(target.global_position)
		if distance <= attack.attack_range:
			velocity = Vector2.ZERO
			is_attacking = true
			attack.try_attack(self, target)
			skill.try_use(self, target, attack.damage)
		else:
			velocity = global_position.direction_to(target.global_position) * move_speed
	else:
		velocity = Vector2(move_speed, 0.0)
	if leader != null and is_instance_valid(leader):
		var formation_target := leader.global_position + formation_offset
		if global_position.distance_to(formation_target) > 55.0 and target == null:
			velocity = global_position.direction_to(formation_target) * move_speed * 1.2
	move_and_slide()
	global_position.y = lerpf(global_position.y, 320.0 + formation_offset.y, 0.12)
	_update_sprite_motion(delta, velocity.length() > 1.0, is_attacking)


func configure(new_definition: ActorDefinition, offset: Vector2, leader_dog: DogActor = null) -> void:
	definition = new_definition
	formation_offset = offset
	leader = leader_dog
	if is_node_ready():
		_apply_role_stats()


func _apply_definition_visual() -> void:
	if definition == null:
		return
	display_name = definition.display_name
	role = definition.role
	move_speed = definition.move_speed
	_body_color = definition.body_color
	if definition.texture == null:
		return
	character_sprite.texture = definition.texture
	var uniform_scale := definition.visual_height / maxf(definition.texture.get_height(), 1.0)
	character_sprite.scale = Vector2.ONE * uniform_scale
	character_sprite.position = definition.sprite_position


func apply_progression(account_level: int, upgrade_level: int) -> void:
	character_level = maxi(upgrade_level, 1)
	var multiplier := 1.0 + float(account_level - 1) * 0.02
	_apply_role_stats(multiplier, character_level, true)


func apply_defense_bonus(damage_reduction_percent: float) -> void:
	health.damage_reduction_percent = clampf(damage_reduction_percent, 0.0, 45.0)


func revive(at_position: Vector2) -> void:
	global_position = at_position
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	health.restore_full()
	skill.reset()
	visual_pivot.scale = Vector2.ONE
	visual_pivot.rotation = 0.0
	queue_redraw()


func _apply_role_stats(multiplier: float = 1.0, upgrade_level: int = 1, preserve_health: bool = false) -> void:
	if definition == null:
		return
	_apply_definition_visual()
	var was_dead := health.is_dead
	var old_ratio := health.ratio()
	var upgrade_count := maxi(upgrade_level - 1, 0)
	var health_upgrade := pow(1.0 + definition.health_per_upgrade_percent / 100.0, upgrade_count)
	var attack_upgrade := pow(1.0 + definition.attack_per_upgrade_percent / 100.0, upgrade_count)
	var skill_upgrade := pow(1.0 + definition.skill_per_upgrade_percent / 100.0, upgrade_count)
	health.configure(definition.base_health * multiplier * health_upgrade)
	attack.configure(
		definition.base_attack * multiplier * attack_upgrade,
		definition.attack_cooldown,
		definition.attack_range
	)
	skill.skill_name = definition.skill_name
	skill.damage_multiplier = definition.skill_multiplier * skill_upgrade
	if preserve_health:
		if was_dead:
			health.current_health = 0.0
			health.is_dead = true
		else:
			health.current_health = health.maximum_health * old_ratio
		health.health_changed.emit(health.current_health, health.maximum_health)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or not enemy.visible:
			continue
		var enemy_health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if enemy_health == null or enemy_health.is_dead:
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _on_died() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	dog_defeated.emit(self)


func _on_attack(hit_target: Node, _damage: float) -> void:
	attack_visual.emit(global_position, (hit_target as Node2D).global_position, _body_color)


func _on_skill(_skill_name: String, hit_target: Node) -> void:
	skill_visual.emit(global_position, (hit_target as Node2D).global_position, Color("#fff0a8"))


func _on_health_changed(_current: float, _maximum: float) -> void:
	queue_redraw()


func _update_sprite_motion(delta: float, is_moving: bool, is_attacking: bool) -> void:
	var target_squash := 0.01
	var target_rotation := 0.006
	var animation_speed := 2.5
	if is_attacking:
		target_squash = 0.13
		target_rotation = 0.085
		animation_speed = 13.0
	elif is_moving:
		target_squash = 0.045
		target_rotation = 0.025
		animation_speed = 7.0
	_squash_amount = lerpf(_squash_amount, target_squash, minf(delta * 12.0, 1.0))
	_rotation_amount = lerpf(_rotation_amount, target_rotation, minf(delta * 12.0, 1.0))
	_animation_phase += delta * animation_speed
	visual_pivot.scale = Vector2(1.0, 1.0 + sin(_animation_phase) * _squash_amount)
	visual_pivot.rotation = sin(_animation_phase * 0.82) * _rotation_amount


func _draw() -> void:
	draw_string(UI_FONT, Vector2(-37, -113), display_name, HORIZONTAL_ALIGNMENT_CENTER, 74, 14, Color.WHITE)
	var bar_width := 68.0
	draw_rect(Rect2(-bar_width / 2.0, -106.0, bar_width, 5.0), Color("#452e35"))
	draw_rect(Rect2(-bar_width / 2.0, -106.0, bar_width * health.ratio(), 5.0), Color("#68d391"))
