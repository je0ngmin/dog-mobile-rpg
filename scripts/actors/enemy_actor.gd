class_name EnemyActor
extends CharacterBody2D

signal defeated(enemy: EnemyActor, loot: Dictionary)
signal attack_visual(from: Vector2, to: Vector2, color: Color)

@onready var health: HealthComponent = $HealthComponent
@onready var attack: AttackComponent = $AttackComponent
@onready var visual_pivot: Node2D = $VisualPivot
@onready var enemy_sprite: Sprite2D = $VisualPivot/Sprite2D
@onready var name_label: Label = $NameLabel

var definition: ActorDefinition
var is_boss: bool = false
var stage_number: int = 1
var enemy_level: int = 1
var display_name: String = "폐허 슬라임"
var move_speed: float = 62.0
var _body_color := Color("#8b7d72")
var _animation_phase: float = 0.0
var _squash_amount: float = 0.0
var _rotation_amount: float = 0.0
var _health_bar_width: float = 55.0
var _health_bar_y: float = -86.0


func _ready() -> void:
	add_to_group("enemies")
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	attack.attack_performed.connect(_on_attack)
	_animation_phase = randf() * TAU


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	var target := _find_nearest_dog()
	if target == null:
		velocity = Vector2.ZERO
		_update_sprite_motion(delta, false, false)
		return
	var is_attacking := false
	if global_position.distance_to(target.global_position) <= attack.attack_range:
		velocity = Vector2.ZERO
		is_attacking = true
		attack.try_attack(self, target)
	else:
		var target_velocity_x := 0.0
		var target_body := target as CharacterBody2D
		if target_body:
			target_velocity_x = target_body.velocity.x
		velocity = (
			global_position.direction_to(target.global_position) * move_speed
			+ Vector2(target_velocity_x, 0.0)
		)
	move_and_slide()
	global_position.y = lerpf(global_position.y, 320.0, 0.1)
	_update_sprite_motion(delta, velocity.length() > 1.0, is_attacking)


func configure(new_stage: int, boss: bool, new_definition: ActorDefinition) -> void:
	definition = new_definition
	stage_number = new_stage
	enemy_level = maxi(stage_number, 1)
	is_boss = boss
	if definition == null:
		push_error("EnemyActor에 ActorDefinition이 지정되지 않았습니다.")
		return
	var health_factor := pow(definition.health_growth, stage_number - 1)
	var damage_factor := pow(definition.attack_growth, stage_number - 1)
	display_name = definition.display_name
	_body_color = definition.body_color
	name_label.position = definition.name_label_position
	name_label.size = definition.name_label_size
	enemy_sprite.texture = definition.texture
	if definition.texture != null:
		var uniform_scale := definition.visual_height / maxf(definition.texture.get_height(), 1.0)
		enemy_sprite.scale = Vector2.ONE * uniform_scale
	enemy_sprite.position = definition.sprite_position
	_health_bar_width = definition.health_bar_width
	_health_bar_y = definition.health_bar_y
	visual_pivot.show()
	scale = Vector2.ONE
	health.configure(definition.base_health * health_factor)
	attack.configure(
		definition.base_attack * damage_factor,
		definition.attack_cooldown,
		definition.attack_range
	)
	move_speed = definition.move_speed + minf(
		stage_number * definition.speed_per_stage,
		definition.speed_bonus_cap
	)
	name_label.text = "%s  Lv.%d" % [display_name, enemy_level]
	queue_redraw()


func _find_nearest_dog() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("dogs"):
		var dog := candidate as Node2D
		if dog == null or not dog.visible:
			continue
		var dog_health := dog.get_node_or_null("HealthComponent") as HealthComponent
		if dog_health == null or dog_health.is_dead:
			continue
		var distance := global_position.distance_squared_to(dog.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = dog
	return nearest


func _on_died() -> void:
	var base_gold := GameState.gold_reward_for_stage(stage_number, is_boss)
	var final_gold := GameState.apply_monster_gold_bonus(base_gold)
	var loot := {
		"gold": final_gold,
		"base_gold": base_gold,
		"gold_skill_bonus": final_gold - base_gold,
		"food": (2 + stage_number / 2) * (5 if is_boss else 1),
		"scrap": (1 + stage_number / 3) * (5 if is_boss else 1),
		"parts": 1 if is_boss else 0,
		"experience": (6 + stage_number) * (5 if is_boss else 1),
	}
	defeated.emit(self, loot)
	queue_free()


func _on_attack(hit_target: Node, _damage: float) -> void:
	attack_visual.emit(global_position, (hit_target as Node2D).global_position, Color("#ff6b6b"))


func _on_health_changed(_current: float, _maximum: float) -> void:
	queue_redraw()


func _update_sprite_motion(delta: float, is_moving: bool, is_attacking: bool) -> void:
	var target_squash := 0.015
	var target_rotation := 0.006
	var animation_speed := 2.8
	if is_boss and is_attacking:
		target_squash = 0.11
		target_rotation = 0.05
		animation_speed = 10.5
	elif is_boss and is_moving:
		target_squash = 0.038
		target_rotation = 0.016
		animation_speed = 5.8
	elif is_attacking:
		target_squash = 0.16
		target_rotation = 0.075
		animation_speed = 14.0
	elif is_moving:
		target_squash = 0.055
		target_rotation = 0.022
		animation_speed = 8.5
	_squash_amount = lerpf(_squash_amount, target_squash, minf(delta * 13.0, 1.0))
	_rotation_amount = lerpf(_rotation_amount, target_rotation, minf(delta * 13.0, 1.0))
	_animation_phase += delta * animation_speed
	visual_pivot.scale = Vector2(1.0, 1.0 + sin(_animation_phase) * _squash_amount)
	visual_pivot.rotation = sin(_animation_phase * 0.84) * _rotation_amount


func _draw() -> void:
	draw_rect(Rect2(-_health_bar_width / 2.0, _health_bar_y, _health_bar_width, 5), Color("#452e35"))
	draw_rect(
		Rect2(-_health_bar_width / 2.0, _health_bar_y, _health_bar_width * health.ratio(), 5),
		Color("#e05666")
	)
