class_name AttackComponent
extends Node

signal attack_performed(target: Node, damage: float)

@export var damage: float = 10.0
@export var attacks_per_second: float = 1.0
@export var attack_range: float = 110.0

var _cooldown: float = 0.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func can_attack(attacker: Node2D, target: Node2D) -> bool:
	return (
		_cooldown <= 0.0
		and is_instance_valid(target)
		and attacker.global_position.distance_to(target.global_position) <= attack_range
	)


func try_attack(attacker: Node2D, target: Node2D) -> bool:
	if not can_attack(attacker, target):
		return false
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health == null or health.is_dead:
		return false
	health.take_damage(damage, attacker)
	_cooldown = 1.0 / maxf(attacks_per_second, 0.05)
	attack_performed.emit(target, damage)
	return true


func configure(new_damage: float, speed: float, new_range: float) -> void:
	damage = new_damage
	attacks_per_second = speed
	attack_range = new_range
