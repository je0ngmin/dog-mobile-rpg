class_name HealthComponent
extends Node

signal damaged(amount: float, source: Node2D)
signal healed(amount: float)
signal died
signal health_changed(current: float, maximum: float)

@export var maximum_health: float = 100.0
@export_range(0.0, 90.0, 0.1) var damage_reduction_percent: float = 0.0
var current_health: float
var is_dead: bool = false


func _ready() -> void:
	current_health = maximum_health


func configure(value: float) -> void:
	maximum_health = maxf(value, 1.0)
	current_health = maximum_health
	is_dead = false
	health_changed.emit(current_health, maximum_health)


func take_damage(amount: float, source: Node2D = null) -> void:
	if is_dead:
		return
	var reduction_multiplier := 1.0 - clampf(damage_reduction_percent, 0.0, 90.0) / 100.0
	var applied := maxf(amount, 0.0) * reduction_multiplier
	current_health = maxf(current_health - applied, 0.0)
	damaged.emit(applied, source)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead:
		return
	var before := current_health
	current_health = minf(current_health + maxf(amount, 0.0), maximum_health)
	healed.emit(current_health - before)
	health_changed.emit(current_health, maximum_health)


func restore_full() -> void:
	current_health = maximum_health
	is_dead = false
	health_changed.emit(current_health, maximum_health)


func ratio() -> float:
	return current_health / maximum_health if maximum_health > 0.0 else 0.0
