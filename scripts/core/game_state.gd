extends Node

signal resources_changed
signal level_changed(level: int)
signal offline_reward_ready(reward: Dictionary)
signal character_roster_changed(character_index: int)
signal account_skills_changed(skill_index: int)

const SAVE_PATH := "user://dog_rpg_save.json"
const FINAL_STAGE := 15
const OFFLINE_CAP_SECONDS := 8 * 60 * 60
const MAX_GOLD := 8_000_000_000_000_000_000
const LARGE_NUMBER_UNITS := ["", "만", "억", "조", "경"]
const DEFAULT_BGM_VOLUME_DB := -8.0
const DEFAULT_SFX_VOLUME_DB := -5.0
const ATTACK_COOLDOWN_REDUCTION_PER_CHARACTER_LEVEL := 0.3
const MAX_CHARACTER_ATTACK_COOLDOWN_REDUCTION := 15.0
const DEBUG_FINAL_STAGE_GOLD := 1_000_000_000
const DEBUG_CHARACTER_LEVEL := 50

var gold: int = 0
var parts: int = 0
var player_level: int = 1
var experience: int = 0
var highest_stage: int = 1
var last_saved_unix: int = 0
var pending_offline_reward: Dictionary = {}
var character_purchased: Array[bool] = [true, false, false]
var character_levels: Array[int] = [1, 1, 1]
var account_skill_levels: Array[int] = [1, 1, 1]
var bgm_volume_db: float = DEFAULT_BGM_VOLUME_DB
var sfx_volume_db: float = DEFAULT_SFX_VOLUME_DB


func _ready() -> void:
	load_game()
	_grant_offline_reward()


func experience_to_next_level() -> int:
	return 40 + (player_level - 1) * 25


func account_level_stat_multiplier(level: int) -> float:
	var upgrade_steps := maxi(level - 1, 0)
	var early_steps := mini(upgrade_steps, 20)
	var middle_steps := mini(maxi(upgrade_steps - 20, 0), 30)
	var late_steps := maxi(upgrade_steps - 50, 0)
	return pow(1.03, early_steps) * pow(1.02, middle_steps) * pow(1.01, late_steps)


func account_level_gain_percent(level: int) -> float:
	if level <= 21:
		return 3.0
	if level <= 51:
		return 2.0
	return 1.0


func character_attack_cooldown_reduction_percent(level: int) -> float:
	return minf(
		float(maxi(level - 1, 0)) * ATTACK_COOLDOWN_REDUCTION_PER_CHARACTER_LEVEL,
		MAX_CHARACTER_ATTACK_COOLDOWN_REDUCTION
	)


func character_attack_cooldown_multiplier(level: int) -> float:
	return 1.0 - character_attack_cooldown_reduction_percent(level) / 100.0


func apply_debug_final_stage_loadout() -> void:
	gold = DEBUG_FINAL_STAGE_GOLD
	for character_index in character_purchased.size():
		character_purchased[character_index] = true
		character_levels[character_index] = DEBUG_CHARACTER_LEVEL
	resources_changed.emit()
	for character_index in character_purchased.size():
		character_roster_changed.emit(character_index)


func add_experience(amount: int) -> void:
	experience += maxi(amount, 0)
	while experience >= experience_to_next_level():
		experience -= experience_to_next_level()
		player_level += 1
		level_changed.emit(player_level)
	resources_changed.emit()


func add_loot(loot: Dictionary) -> void:
	gold = mini(gold + int(loot.get("gold", 0)), MAX_GOLD)
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
	var costs := [0, 1_500_000, 5_000_000]
	return costs[character_index] if character_index >= 0 and character_index < costs.size() else 0


func character_upgrade_cost(character_index: int) -> int:
	if character_index < 0 or character_index >= character_levels.size():
		return 0
	var base_costs := [500_000, 650_000, 800_000]
	var cost := float(base_costs[character_index]) * pow(1.34, character_levels[character_index] - 1)
	cost = minf(cost, float(MAX_GOLD))
	return int(round(cost))


func gold_reward_for_stage(stage_number: int, boss: bool = false) -> int:
	var reward := 120_000.0 * pow(1.32, maxi(stage_number - 1, 0))
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


func account_skill_upgrade_cost(skill_index: int) -> int:
	if skill_index < 0 or skill_index >= account_skill_levels.size():
		return 0
	var base_costs := [2_000_000, 2_600_000, 3_200_000]
	var cost := float(base_costs[skill_index]) * pow(1.65, account_skill_levels[skill_index] - 1)
	return int(round(minf(cost, float(MAX_GOLD))))


func upgrade_account_skill(skill_index: int) -> bool:
	if skill_index < 0 or skill_index >= account_skill_levels.size():
		return false
	if not spend_gold(account_skill_upgrade_cost(skill_index)):
		return false
	account_skill_levels[skill_index] += 1
	account_skills_changed.emit(skill_index)
	save_game()
	return true


func gold_skill_total_percent() -> float:
	var total := 0.0
	for level in range(1, account_skill_levels[0] + 1):
		total += 0.25 / sqrt(float(level))
	return total


func gold_skill_next_increment() -> float:
	return 0.25 / sqrt(float(account_skill_levels[0] + 1))


func apply_monster_gold_bonus(base_gold: int) -> int:
	if base_gold <= 0:
		return 0
	var bonus := maxi(int(round(base_gold * gold_skill_total_percent() / 100.0)), 1)
	return mini(base_gold + bonus, MAX_GOLD)


func healing_skill_recovery_percent() -> float:
	var recovery := 6.0
	for level in range(2, account_skill_levels[1] + 1):
		recovery += 0.8 / sqrt(float(level - 1))
	return recovery


func healing_skill_next_increment() -> float:
	return 0.8 / sqrt(float(account_skill_levels[1]))


func healing_skill_cooldown() -> float:
	var cooldown := 60.0
	for level in range(2, account_skill_levels[1] + 1):
		cooldown -= 1.5 / sqrt(float(level - 1))
	return maxf(cooldown, 25.0)


func healing_skill_next_cooldown_reduction() -> float:
	if healing_skill_cooldown() <= 25.0:
		return 0.0
	return 1.5 / sqrt(float(account_skill_levels[1]))


func defense_skill_total_percent() -> float:
	var total := 0.0
	for level in range(1, account_skill_levels[2] + 1):
		total += 0.8 / sqrt(float(level))
	return minf(total, 45.0)


func defense_skill_next_increment() -> float:
	if defense_skill_total_percent() >= 45.0:
		return 0.0
	return minf(0.8 / sqrt(float(account_skill_levels[2] + 1)), 45.0 - defense_skill_total_percent())


func unlock_stage(stage_number: int) -> void:
	highest_stage = clampi(maxi(highest_stage, stage_number), 1, FINAL_STAGE)
	save_game()


func save_game() -> void:
	last_saved_unix = int(Time.get_unix_time_from_system())
	var data := {
		"gold": gold,
		"parts": parts,
		"player_level": player_level,
		"experience": experience,
		"highest_stage": highest_stage,
		"last_saved_unix": last_saved_unix,
		"character_purchased": character_purchased,
		"character_levels": character_levels,
		"account_skill_levels": account_skill_levels,
		"bgm_volume_db": bgm_volume_db,
		"sfx_volume_db": sfx_volume_db,
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
	parts = int(data.get("parts", 0))
	player_level = int(data.get("player_level", 1))
	experience = int(data.get("experience", 0))
	highest_stage = clampi(int(data.get("highest_stage", 1)), 1, FINAL_STAGE)
	last_saved_unix = int(data.get("last_saved_unix", Time.get_unix_time_from_system()))
	bgm_volume_db = clampf(float(data.get("bgm_volume_db", DEFAULT_BGM_VOLUME_DB)), -40.0, 0.0)
	sfx_volume_db = clampf(float(data.get("sfx_volume_db", DEFAULT_SFX_VOLUME_DB)), -40.0, 0.0)
	var saved_purchased: Array = data.get("character_purchased", [true, false, false])
	var saved_levels: Array = data.get("character_levels", [1, 1, 1])
	for index in character_purchased.size():
		character_purchased[index] = bool(saved_purchased[index]) if index < saved_purchased.size() else index == 0
		character_levels[index] = maxi(int(saved_levels[index]), 1) if index < saved_levels.size() else 1
	character_purchased[0] = true
	var saved_skill_levels: Array = data.get("account_skill_levels", [1, 1, 1])
	for index in account_skill_levels.size():
		account_skill_levels[index] = maxi(int(saved_skill_levels[index]), 1) if index < saved_skill_levels.size() else 1


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
	parts = 0
	player_level = 1
	experience = 0
	highest_stage = 1
	character_purchased = [true, false, false]
	character_levels = [1, 1, 1]
	account_skill_levels = [1, 1, 1]
	bgm_volume_db = DEFAULT_BGM_VOLUME_DB
	sfx_volume_db = DEFAULT_SFX_VOLUME_DB
	save_game()
	resources_changed.emit()


func delete_save_data() -> bool:
	reset_progress()
	var absolute_save_path := ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	return DirAccess.remove_absolute(absolute_save_path) == OK
