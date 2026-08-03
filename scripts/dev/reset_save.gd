extends SceneTree

## Development helper:
## godot --headless --path <project> --script res://scripts/dev/reset_save.gd


func _initialize() -> void:
	var save_path := ProjectSettings.globalize_path("user://dog_rpg_save.json")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"gold": 0,
			"parts": 0,
			"player_level": 1,
			"experience": 0,
			"highest_stage": 1,
			"last_saved_unix": int(Time.get_unix_time_from_system()),
			"character_purchased": [true, false, false],
			"character_levels": [1, 1, 1],
			"account_skill_levels": [1, 1, 1],
			"bgm_volume_db": -8.0,
			"sfx_volume_db": -5.0,
		}))
	quit()
