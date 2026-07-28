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
	main._on_reward_logged(121, 7, 1)
	_check(main.event_log_entries.get_child_count() == 2, "골드·경험치와 스킬 추가 골드가 기록창에 쌓여야 합니다.")
	var expiring_log := main.event_log_entries.get_child(0) as Label
	main._expire_event_log(expiring_log, 0.05)
	await get_tree().create_timer(0.1).timeout
	_check(not is_instance_valid(expiring_log), "오래된 기록은 페이드아웃 후 제거되어야 합니다.")

	GameState.gold = 10_000
	GameState.resources_changed.emit()
	_check(GameState.purchase_character(1), "두 번째 캐릭터를 구매할 수 있어야 합니다.")
	_check(main.party.size() == 2, "구매한 캐릭터가 즉시 편성되어야 합니다.")
	_check(GameState.upgrade_character(1), "구매한 캐릭터를 강화할 수 있어야 합니다.")
	_check(GameState.character_levels[1] == 2, "캐릭터 강화 레벨이 저장 상태에 반영되어야 합니다.")
	_check(GameState.format_large_number(1200) == "1,200", "천 단위 골드는 쉼표로 표시해야 합니다.")
	_check(GameState.format_large_number(12_000) == "1.2만", "만 단위 골드를 축약 표시해야 합니다.")
	_check(GameState.format_large_number(100_000_000) == "1억", "억 단위 골드를 축약 표시해야 합니다.")
	var gold_increment_before := GameState.gold_skill_next_increment()
	_check(GameState.upgrade_account_skill(0), "골드 증가 공용 스킬을 강화할 수 있어야 합니다.")
	_check(GameState.gold_skill_next_increment() < gold_increment_before, "골드 스킬의 레벨별 증가폭은 감소해야 합니다.")
	_check(GameState.gold_skill_next_increment() < 2.0, "골드 스킬 증가폭은 2% 미만이어야 합니다.")
	_check(GameState.apply_monster_gold_bonus(10_000) > 10_000, "골드 스킬이 몬스터 골드에 적용되어야 합니다.")
	var healing_cooldown_before := GameState.healing_skill_cooldown()
	_check(GameState.upgrade_account_skill(1), "긴급 회복 공용 스킬을 강화할 수 있어야 합니다.")
	_check(GameState.healing_skill_cooldown() < healing_cooldown_before, "회복 스킬 강화 시 쿨타임이 감소해야 합니다.")

	var survivor: DogActor = main.party[0]
	var defeated: DogActor = main.party[1]
	survivor.health.take_damage(survivor.health.maximum_health * 0.96)
	main._update_healing_skill(0.0)
	_check(survivor.health.ratio() > 0.04, "HP 5% 이하에서 긴급 회복이 자동 발동해야 합니다.")
	_check(main._healing_skill_cooldown_remaining > 0.0, "긴급 회복 발동 후 공용 쿨타임이 시작되어야 합니다.")
	survivor.health.restore_full()
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

	main.stage_manager._pending_stage = main.stage_manager.current_stage + 1
	main.stage_manager.progression_paused = true
	main._on_stage_transition_requested(main.stage_manager._pending_stage)
	await get_tree().create_timer(1.7).timeout
	_check(main.stage_manager.current_stage == 2, "화면이 가려진 뒤 다음 스테이지가 적용되어야 합니다.")
	_check(not main.stage_transition_overlay.visible, "스테이지 전환 후 검정 오버레이가 사라져야 합니다.")

	main._on_boss_battle_started()
	await get_tree().create_timer(0.65).timeout
	var atmosphere_material := main.boss_atmosphere_overlay.material as ShaderMaterial
	_check(main.boss_atmosphere_overlay.visible, "보스전에는 비네트 오버레이가 표시되어야 합니다.")
	_check(float(atmosphere_material.get_shader_parameter("intensity")) > 0.9, "보스 비네트 강도가 부드럽게 증가해야 합니다.")
	main._on_boss_battle_ended()
	await get_tree().create_timer(0.85).timeout
	_check(not main.boss_atmosphere_overlay.visible, "보스 종료 후 비네트 오버레이가 사라져야 합니다.")

	GameState.reset_progress()
	if not _failed:
		print("CORE_FLOW_TEST_OK")
	get_tree().quit(1 if _failed else 0)
