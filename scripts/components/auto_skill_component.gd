class_name AutoSkillComponent
extends Node

signal skill_used(skill_name: String, target: Node)

@export var skill_name: String = "필살기"
@export var cooldown_seconds: float = 6.0
@export var damage_multiplier: float = 2.5
@export var effect_range: float = 160.0

var _remaining: float = 2.0


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)


func try_use(owner_actor: Node2D, target: Node2D, base_damage: float) -> bool:
	if _remaining > 0.0 or not is_instance_valid(target):
		return false
	if owner_actor.global_position.distance_to(target.global_position) > effect_range:
		return false
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health == null or health.is_dead:
		return false
	health.take_damage(base_damage * damage_multiplier, owner_actor)
	_remaining = cooldown_seconds
	skill_used.emit(skill_name, target)
	return true


func reset() -> void:
	_remaining = 1.0
