extends Node

signal resources_changed
signal level_changed(level: int)
signal offline_reward_ready(reward: Dictionary)
signal character_roster_changed(character_index: int)

const SAVE_PATH := "user://dog_rpg_save.json"
const OFFLINE_CAP_SECONDS := 8 * 60 * 60
const MAX_GOLD := 8_000_000_000_000_000_000
const LARGE_NUMBER_UNITS := ["", "만", "억", "조", "경"]

var gold: int = 0
var food: int = 0
var scrap: int = 0
var parts: int = 0
var player_level: int = 1
var experience: int = 0
var highest_stage: int = 1
var last_saved_unix: int = 0
var pending_offline_reward: Dictionary = {}
var character_purchased: Array[bool] = [true, false, false]
var character_levels: Array[int] = [1, 1, 1]


func _ready() -> void:
	load_game()
	_grant_offline_reward()


func experience_to_next_level() -> int:
	return 40 + (player_level - 1) * 25


func add_experience(amount: int) -> void:
	experience += maxi(amount, 0)
	while experience >= experience_to_next_level():
		experience -= experience_to_next_level()
		player_level += 1
		level_changed.emit(player_level)
	resources_changed.emit()


func add_loot(loot: Dictionary) -> void:
	gold = mini(gold + int(loot.get("gold", 0)), MAX_GOLD)
	food += int(loot.get("food", 0))
	scrap += int(loot.get("scrap", 0))
	parts += int(loot.get("parts", 0))
	add_experience(int(loot.get("experience", 0)))
	resources_changed.emit()


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	resources_changed.emit()
	save_game()
	return true


func character_purchase_cost(character_index: int) -> int:
	var costs := [0, 1500, 5000]
	return costs[character_index] if character_index >= 0 and character_index < costs.size() else 0


func character_upgrade_cost(character_index: int) -> int:
	if character_index < 0 or character_index >= character_levels.size():
		return 0
	var base_costs := [500, 650, 800]
	var cost := float(base_costs[character_index]) * pow(1.55, character_levels[character_index] - 1)
	cost = minf(cost, float(MAX_GOLD))
	return int(round(cost))


func gold_reward_for_stage(stage_number: int, boss: bool = false) -> int:
	var reward := 120.0 * pow(1.32, maxi(stage_number - 1, 0))
	if boss:
		reward *= 12.0
	reward = minf(reward, 500_000_000_000_000_000.0)
	return int(round(reward))


func format_large_number(value: int) -> String:
	var negative := value < 0
	var absolute_value := absi(value)
	if absolute_value < 10_000:
		var digits := str(absolute_value)
		var formatted := ""
		while digits.length() > 3:
			formatted = "," + digits.substr(digits.length() - 3, 3) + formatted
			digits = digits.substr(0, digits.length() - 3)
		formatted = digits + formatted
		return "-" + formatted if negative else formatted
	var scaled := float(absolute_value)
	var unit_index := 0
	while scaled >= 10_000.0 and unit_index < LARGE_NUMBER_UNITS.size() - 1:
		scaled /= 10_000.0
		unit_index += 1
	var number_text: String
	if scaled >= 100.0:
		number_text = "%.0f" % scaled
	elif scaled >= 10.0:
		number_text = "%.1f" % scaled
	else:
		number_text = "%.2f" % scaled
	while number_text.ends_with("0") and number_text.contains("."):
		number_text = number_text.substr(0, number_text.length() - 1)
	if number_text.ends_with("."):
		number_text = number_text.substr(0, number_text.length() - 1)
	var result: String = number_text + String(LARGE_NUMBER_UNITS[unit_index])
	return "-" + result if negative else result


func purchase_character(character_index: int) -> bool:
	if character_index <= 0 or character_index >= character_purchased.size():
		return false
	if character_purchased[character_index]:
		return false
	if not spend_gold(character_purchase_cost(character_index)):
		return false
	character_purchased[character_index] = true
	character_levels[character_index] = 1
	character_roster_changed.emit(character_index)
	save_game()
	return true


func upgrade_character(character_index: int) -> bool:
	if character_index < 0 or character_index >= character_purchased.size():
		return false
	if not character_purchased[character_index]:
		return false
	if not spend_gold(character_upgrade_cost(character_index)):
		return false
	character_levels[character_index] += 1
	character_roster_changed.emit(character_index)
	save_game()
	return true


func unlock_stage(stage_number: int) -> void:
	highest_stage = maxi(highest_stage, stage_number)
	save_game()


func save_game() -> void:
	last_saved_unix = int(Time.get_unix_time_from_system())
	var data := {
		"gold": gold,
		"food": food,
		"scrap": scrap,
		"parts": parts,
		"player_level": player_level,
		"experience": experience,
		"highest_stage": highest_stage,
		"last_saved_unix": last_saved_unix,
		"character_purchased": character_purchased,
		"character_levels": character_levels,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		last_saved_unix = int(Time.get_unix_time_from_system())
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	gold = int(data.get("gold", 0))
	food = int(data.get("food", 0))
	scrap = int(data.get("scrap", 0))
	parts = int(data.get("parts", 0))
	player_level = int(data.get("player_level", 1))
	experience = int(data.get("experience", 0))
	highest_stage = int(data.get("highest_stage", 1))
	last_saved_unix = int(data.get("last_saved_unix", Time.get_unix_time_from_system()))
	var saved_purchased: Array = data.get("character_purchased", [true, false, false])
	var saved_levels: Array = data.get("character_levels", [1, 1, 1])
	for index in character_purchased.size():
		character_purchased[index] = bool(saved_purchased[index]) if index < saved_purchased.size() else index == 0
		character_levels[index] = maxi(int(saved_levels[index]), 1) if index < saved_levels.size() else 1
	character_purchased[0] = true


func _grant_offline_reward() -> void:
	var now := int(Time.get_unix_time_from_system())
	var elapsed := clampi(now - last_saved_unix, 0, OFFLINE_CAP_SECONDS)
	if elapsed < 60:
		return
	var minutes := elapsed / 60
	var stage_gold_reward := gold_reward_for_stage(highest_stage)
	var stage_multiplier := 1.0 + float(highest_stage - 1) * 0.12
	var offline_gold := minf(
		minutes * stage_gold_reward * 0.75,
		float(MAX_GOLD) * 0.5
	)
	var reward := {
		"seconds": elapsed,
		"gold": int(offline_gold),
		"food": int(minutes * 3 * stage_multiplier),
		"scrap": int(minutes * 2 * stage_multiplier),
		"experience": int(minutes * 4 * stage_multiplier),
	}
	add_loot(reward)
	pending_offline_reward = reward
	offline_reward_ready.emit(reward)


func consume_offline_reward() -> Dictionary:
	var reward := pending_offline_reward.duplicate()
	pending_offline_reward.clear()
	return reward


func reset_progress() -> void:
	gold = 0
	food = 0
	scrap = 0
	parts = 0
	player_level = 1
	experience = 0
	highest_stage = 1
	character_purchased = [true, false, false]
	character_levels = [1, 1, 1]
	save_game()
	resources_changed.emit()
