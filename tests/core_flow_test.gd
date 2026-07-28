extends Node

var _failed: bool = false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("CORE FLOW TEST: " + message)


func _ready() -> void:
	GameState.reset_progress()
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(main.party.size() == 1, "새 저장 데이터에서는 캐릭터가 한 명이어야 합니다.")

	GameState.gold = 10_000
	GameState.resources_changed.emit()
	_check(GameState.purchase_character(1), "두 번째 캐릭터를 구매할 수 있어야 합니다.")
	_check(main.party.size() == 2, "구매한 캐릭터가 즉시 편성되어야 합니다.")
	_check(GameState.upgrade_character(1), "구매한 캐릭터를 강화할 수 있어야 합니다.")
	_check(GameState.character_levels[1] == 2, "캐릭터 강화 레벨이 저장 상태에 반영되어야 합니다.")
	_check(GameState.format_large_number(1200) == "1,200", "천 단위 골드는 쉼표로 표시해야 합니다.")
	_check(GameState.format_large_number(12_000) == "1.2만", "만 단위 골드를 축약 표시해야 합니다.")
	_check(GameState.format_large_number(100_000_000) == "1억", "억 단위 골드를 축약 표시해야 합니다.")

	var survivor: DogActor = main.party[0]
	var defeated: DogActor = main.party[1]
	survivor.health.take_damage(30.0)
	defeated.health.take_damage(defeated.health.maximum_health)
	main.stage_manager._heal_surviving_party()
	_check(is_equal_approx(survivor.health.current_health, survivor.health.maximum_health), "보스 처치 후 생존자는 완전 회복해야 합니다.")
	_check(defeated.health.is_dead and defeated.health.current_health == 0.0, "보스 처치 후 사망자는 회복하면 안 됩니다.")

	survivor.health.take_damage(survivor.health.maximum_health)
	_check(main.stage_manager.progression_paused, "전멸 시 전투 진행이 멈춰야 합니다.")
	var gold_before_revival: int = GameState.gold
	var revival_cost: int = main.stage_manager.revival_cost()
	main._on_revive_requested()
	_check(GameState.gold == gold_before_revival - revival_cost, "부활 비용만큼 골드가 차감되어야 합니다.")
	_check(not survivor.health.is_dead and not defeated.health.is_dead, "골드 부활 시 모든 캐릭터가 살아나야 합니다.")
	_check(main.stage_manager.kills == 0, "부활 시 현재 스테이지 진행도를 처음으로 되돌려야 합니다.")

	GameState.reset_progress()
	if not _failed:
		print("CORE_FLOW_TEST_OK")
	get_tree().quit(1 if _failed else 0)
