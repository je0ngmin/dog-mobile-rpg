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

	_check(main.actor_catalog != null, "캐릭터·몬스터·보스 카탈로그가 Main에 연결되어야 합니다.")
	_check(main.actor_catalog.characters.size() == 3, "플레이어 캐릭터 3종이 Resource로 등록되어야 합니다.")
	_check(main.actor_catalog.normal_enemies.size() == 2, "일반 몬스터 2종이 Resource로 등록되어야 합니다.")
	_check(main.actor_catalog.bosses.size() == 2, "보스 2종이 Resource로 등록되어야 합니다.")
	_check(main.party.size() == 1, "새 저장 데이터에서는 캐릭터가 한 명이어야 합니다.")
	_check(
		main.party[0].definition == main.actor_catalog.character_at(0),
		"플레이어 능력치와 이미지는 ActorDefinition에서 읽어야 합니다."
	)
	var bori_definition: ActorDefinition = main.actor_catalog.character_at(0)
	var bori_values: Vector2 = main._character_combat_values(bori_definition, 1)
	_check(
		bori_definition.base_health == 180_000.0
		and bori_definition.base_attack == 14_000.0,
		"초기 캐릭터부터 HP와 공격력이 만 단위 이상이어야 합니다."
	)
	_check(
		GameState.format_large_number(int(bori_values.x)) == "18만"
		and GameState.format_large_number(int(bori_values.y)) == "1.4만",
		"캐릭터 카드에서 대형 전투 수치를 한글 단위로 표시할 수 있어야 합니다."
	)
	var resource_enemy := main.enemy_scene.instantiate() as EnemyActor
	main.world.add_child(resource_enemy)
	resource_enemy.configure(2, false, main.actor_catalog.normal_enemy_for_stage(2))
	var damage_events: Array[float] = []
	resource_enemy.damage_received.connect(
		func(_position: Vector2, amount: float, _boss_hit: bool) -> void:
			damage_events.append(amount)
	)
	resource_enemy.health.take_damage(12.0)
	_check(
		resource_enemy.definition == main.actor_catalog.normal_enemy_for_stage(2)
		and resource_enemy.display_name == "화염 슬라임",
		"일반 몬스터가 스테이지별 ActorDefinition을 사용해야 합니다."
	)
	_check(
		resource_enemy.definition.base_health >= 30_000.0
		and resource_enemy.definition.base_attack >= 4_000.0,
		"몬스터 체력과 공격력도 확대된 전투 수치를 사용해야 합니다."
	)
	_check(damage_events.size() == 1 and is_equal_approx(damage_events[0], 12.0), "몬스터 피격 시 데미지 표시 신호가 발생해야 합니다.")
	resource_enemy.configure(2, true, main.actor_catalog.boss_for_stage(2))
	_check(
		resource_enemy.definition == main.actor_catalog.boss_for_stage(2)
		and resource_enemy.display_name == "화염 까마귀",
		"보스가 스테이지별 ActorDefinition을 사용해야 합니다."
	)
	var enemy_loot_events: Array[Dictionary] = []
	resource_enemy.defeated.connect(
		func(_enemy: EnemyActor, loot: Dictionary) -> void:
			enemy_loot_events.append(loot)
	)
	resource_enemy.health.take_damage(resource_enemy.health.maximum_health * 2.0)
	_check(
		enemy_loot_events.size() == 1
		and not enemy_loot_events[0].has("food")
		and not enemy_loot_events[0].has("scrap"),
		"몬스터 보상에서 식량과 고철이 제거되어야 합니다."
	)
	_check(main.world.format_damage_number(9999.0) == "9,999", "1만 미만 데미지는 천 단위 쉼표로 표시해야 합니다.")
	_check(main.world.format_damage_number(12_000.0) == "1.2만", "큰 데미지는 만 단위로 축약해야 합니다.")
	_check(main.world.format_damage_number(100_000_000.0) == "1억", "더 큰 데미지는 억 단위로 축약해야 합니다.")
	var damage_label: Label = main.world.add_damage_number(Vector2(500.0, 320.0), 12_000.0)
	var damage_start_y: float = damage_label.position.y
	_check(damage_label.text == "1.2만", "데미지 텍스트에 축약된 수치가 표시되어야 합니다.")
	await get_tree().create_timer(0.2).timeout
	_check(damage_label.position.y < damage_start_y, "데미지 텍스트는 아래에서 위로 올라가야 합니다.")
	await get_tree().create_timer(0.75).timeout
	_check(not is_instance_valid(damage_label), "데미지 텍스트는 상승 후 페이드아웃되어 제거되어야 합니다.")
	_check(get_tree().get_nodes_in_group("party_speech_bubble").size() == 1, "원정대 말풍선은 동료 수와 관계없이 하나만 있어야 합니다.")
	_check(main.party_speech_bubble.messages != null, "원정대 대사는 편집 가능한 Resource로 연결되어야 합니다.")
	_check(main.party_speech_bubble.messages.normal_messages.size() >= 8, "평상시 원정대 대사가 충분히 구성되어야 합니다.")
	_check(main.party_speech_bubble.messages.teammate_down_messages.size() >= 6, "팀원 사망 대사가 충분히 구성되어야 합니다.")
	_check(main.party_speech_bubble.messages.boss_arrived_messages.size() >= 6, "보스 등장 대사가 충분히 구성되어야 합니다.")
	_check(main.party_speech_bubble.messages.boss_defeated_messages.size() >= 6, "보스 처치 대사가 충분히 구성되어야 합니다.")
	_check(main.party_speech_bubble.current_state == 0, "기본 상태에서는 평상시 대사를 표시해야 합니다.")
	_check(main.party_speech_bubble.global_position.y > main.party[0].global_position.y, "말풍선은 플레이어 무리 아래에 있어야 합니다.")
	var bubble_background := main.party_speech_bubble.get_child(0) as TextureRect
	_check(
		bubble_background != null
		and bubble_background.texture.resource_path == "res://sprites/bubble.png",
		"원정대 말풍선은 bubble.png 스프라이트를 사용해야 합니다."
	)
	main._update_party_speech_bubble_position()
	var bubble_offset_before: Vector2 = main.party_speech_bubble.global_position - main.party[0].global_position
	main.party[0].global_position.x += 10.0
	main._update_party_speech_bubble_position()
	var bubble_offset_after: Vector2 = main.party_speech_bubble.global_position - main.party[0].global_position
	_check(
		bubble_offset_before.distance_to(bubble_offset_after) < 0.01,
		"말풍선은 보간 떨림 없이 대표 캐릭터에 고정되어야 합니다. 이전 %s, 이후 %s" % [
			bubble_offset_before,
			bubble_offset_after,
		]
	)
	main.party_speech_bubble.show_boss_arrived()
	_check(
		main.party_speech_bubble._letters.get_child_count() == main.party_speech_bubble.current_text.length(),
		"대사는 문자열에서 글자 Label을 자동 생성해야 합니다."
	)
	_check(
		main.party_speech_bubble._typing_tweens.size() == main.party_speech_bubble.current_text.length(),
		"각 글자에는 순차 투명도 애니메이션이 있어야 합니다."
	)
	var final_letter := main.party_speech_bubble._letters.get_child(
		main.party_speech_bubble._letters.get_child_count() - 1
	) as Label
	_check(final_letter.modulate.a < 0.01, "뒤쪽 글자는 자신의 딜레이 전까지 투명해야 합니다.")
	main.party_speech_bubble.show_normal(true)
	main._on_reward_logged(121, 7, 1)
	_check(main.event_log_entries.get_child_count() == 2, "골드·경험치와 스킬 추가 골드가 기록창에 쌓여야 합니다.")
	var expiring_log := main.event_log_entries.get_child(0) as Label
	var event_log_panel := main.event_log_entries.get_parent().get_parent() as PanelContainer
	_check(event_log_panel != null and event_log_panel.z_index < 0, "원정 기록창은 다이얼로그보다 낮은 z-index여야 합니다.")
	_check(main.event_log_entries.get_parent().get_child_count() == 1, "원정 기록창에는 별도 타이틀이 없어야 합니다.")
	_check(expiring_log.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "원정 기록 텍스트는 오른쪽 정렬되어야 합니다.")
	main._expire_event_log(expiring_log, 0.05)
	await get_tree().create_timer(0.1).timeout
	_check(not is_instance_valid(expiring_log), "오래된 기록은 페이드아웃 후 제거되어야 합니다.")
	var gold_target: Vector2 = main._control_center_to_gold_effects_position(main.resource_label)
	var gold_target_canvas: Vector2 = main.gold_effects.get_global_transform_with_canvas() * gold_target
	var resource_center_canvas: Vector2 = (
		main.resource_label.get_global_transform_with_canvas()
		* (main.resource_label.size * 0.5)
	)
	_check(gold_target_canvas.distance_to(resource_center_canvas) < 0.01, "골드 이펙트의 도착점은 실제 골드 UI 중앙이어야 합니다.")
	_check(main.resource_label.size.x < 240.0, "VBox 안의 골드 Label이 상단바 전체 폭으로 늘어나면 안 됩니다.")
	main._on_progress_changed(5, 5, true)
	await get_tree().process_frame
	_check(not main.progress_label.visible, "보스 전투 중에는 고정 진행 문구를 숨겨야 합니다.")
	_check(
		is_instance_valid(main._boss_text_effect)
		and main._boss_text_effect.get_child_count() == "BOSS 전투 중".length(),
		"보스 출현 문구는 글자별 애니메이션 노드로 구성되어야 합니다."
	)
	_check(main._boss_text_effect.z_index <= 0, "BOSS 전투 중 문구가 다른 UI보다 과하게 앞에 나오면 안 됩니다.")
	_check(main._boss_text_tweens.size() == "BOSS 전투 중".length(), "보스 문구의 각 글자에 지연 애니메이션이 있어야 합니다.")
	main._on_progress_changed(0, 5, false)
	_check(main.progress_label.visible and main._boss_text_effect == null, "보스전 종료 시 일반 진행 문구로 돌아와야 합니다.")
	var defeat_message := "보스를 격파했다!"
	main._show_message(defeat_message)
	await get_tree().process_frame
	_check(not main.message_label.visible, "보스 격파 시 고정 메시지 Label을 숨겨야 합니다.")
	_check(
		is_instance_valid(main._message_text_effect)
		and main._message_text_effect.get_child_count() == defeat_message.length(),
		"보스 격파 메시지도 글자별 애니메이션 노드로 구성되어야 합니다."
	)
	_check(main._message_text_tweens.size() == defeat_message.length(), "보스 격파 메시지의 모든 글자에 파동 애니메이션이 있어야 합니다.")
	main._show_message("일반 메시지")
	_check(main.message_label.visible and main._message_text_effect == null, "다음 일반 메시지에서는 기본 Label로 복귀해야 합니다.")

	GameState.gold = 10_000_000
	GameState.resources_changed.emit()
	_check(GameState.purchase_character(1), "두 번째 캐릭터를 구매할 수 있어야 합니다.")
	_check(main.party.size() == 2, "구매한 캐릭터가 즉시 편성되어야 합니다.")
	_check(GameState.upgrade_character(1), "구매한 캐릭터를 강화할 수 있어야 합니다.")
	_check(GameState.character_levels[1] == 2, "캐릭터 강화 레벨이 저장 상태에 반영되어야 합니다.")
	_check(GameState.format_large_number(1200) == "1,200", "천 단위 골드는 쉼표로 표시해야 합니다.")
	_check(GameState.format_large_number(12_000) == "1.2만", "만 단위 골드를 축약 표시해야 합니다.")
	_check(GameState.format_large_number(100_000_000) == "1억", "억 단위 골드를 축약 표시해야 합니다.")
	_check(GameState.gold_reward_for_stage(1) == 120_000, "1-1 일반 골드 보상은 12만G부터 시작해야 합니다.")
	_check(GameState.gold_reward_for_stage(1, true) == 1_440_000, "1-1 보스 골드 보상은 144만G부터 시작해야 합니다.")
	_check(GameState.character_upgrade_cost(0) >= 500_000, "캐릭터 강화 비용도 확대된 골드 경제에 맞아야 합니다.")
	var gold_increment_before := GameState.gold_skill_next_increment()
	_check(GameState.upgrade_account_skill(0), "골드 증가 스킬을 강화할 수 있어야 합니다.")
	_check(GameState.gold_skill_next_increment() < gold_increment_before, "골드 스킬의 레벨별 증가폭은 감소해야 합니다.")
	_check(GameState.gold_skill_next_increment() < 2.0, "골드 스킬 증가폭은 2% 미만이어야 합니다.")
	_check(GameState.apply_monster_gold_bonus(10_000) > 10_000, "골드 스킬이 몬스터 골드에 적용되어야 합니다.")
	var healing_cooldown_before := GameState.healing_skill_cooldown()
	_check(GameState.upgrade_account_skill(1), "긴급 회복 스킬을 강화할 수 있어야 합니다.")
	_check(GameState.healing_skill_cooldown() < healing_cooldown_before, "회복 스킬 강화 시 쿨타임이 감소해야 합니다.")
	var defense_increment_before := GameState.defense_skill_next_increment()
	_check(GameState.upgrade_account_skill(2), "방어력 증가 스킬을 강화할 수 있어야 합니다.")
	_check(GameState.defense_skill_next_increment() < defense_increment_before, "방어력 스킬의 레벨별 증가폭은 감소해야 합니다.")
	main._rebuild_skill_rows()
	_check(main.skill_rows.get_child_count() == 3, "공용 스킬 화면에 방어력 증가를 포함한 스킬 3개가 표시되어야 합니다.")
	var defense_row_text := str(main.skill_rows.get_child(2).get_child(0).get_child(0).get_child(0).text)
	_check(defense_row_text.contains("방어력 증가"), "세 번째 스킬 카드에 방어력 증가 정보가 표시되어야 합니다.")
	main._show_offline_reward({
		"seconds": 3600,
		"gold": 120_000,
		"experience": 10,
		"food": 999,
		"scrap": 999,
	})
	_check(
		not main.offline_label.text.contains("식량")
		and not main.offline_label.text.contains("고철"),
		"오프라인 보상 UI에서 식량과 고철이 제거되어야 합니다."
	)
	main.offline_panel.hide()

	var survivor: DogActor = main.party[0]
	var defeated: DogActor = main.party[1]
	var defense_percent := GameState.defense_skill_total_percent()
	var health_before_defense_test := survivor.health.current_health
	survivor.health.take_damage(10_000.0)
	_check(
		is_equal_approx(
			health_before_defense_test - survivor.health.current_health,
			10_000.0 * (1.0 - defense_percent / 100.0)
		),
		"방어력 증가 수치만큼 플레이어가 받는 실제 피해가 감소해야 합니다."
	)
	survivor.health.restore_full()
	survivor.health.take_damage(survivor.health.maximum_health * 0.97)
	main._update_healing_skill(0.0)
	_check(survivor.health.ratio() > 0.04, "HP 5% 이하에서 긴급 회복이 자동 발동해야 합니다.")
	_check(main._healing_skill_cooldown_remaining > 0.0, "긴급 회복 발동 후 공용 쿨타임이 시작되어야 합니다.")
	survivor.health.restore_full()
	survivor.health.take_damage(30.0)
	defeated.health.take_damage(defeated.health.maximum_health * 2.0)
	_check(
		main.party_speech_bubble.current_state == 1,
		"동료 한 명이 쓰러지면 팀원 사망 대사를 표시해야 합니다. 현재 상태: %s" % main.party_speech_bubble.current_state
	)
	main.stage_manager._heal_surviving_party()
	_check(is_equal_approx(survivor.health.current_health, survivor.health.maximum_health), "보스 처치 후 생존자는 완전 회복해야 합니다.")
	_check(defeated.health.is_dead and defeated.health.current_health == 0.0, "보스 처치 후 사망자는 회복하면 안 됩니다.")

	var gold_before_revival: int = GameState.gold
	var expected_penalty := ceili(float(gold_before_revival) * 0.3)
	survivor.health.take_damage(survivor.health.maximum_health * 2.0)
	_check(main.stage_manager.progression_paused, "전멸 시 전투 진행이 멈춰야 합니다.")
	_check(main.get_node_or_null("UI/RetryButton") == null, "전멸 시 수동 부활 버튼이 존재하면 안 됩니다.")
	_check(GameState.gold == gold_before_revival - expected_penalty, "전멸 즉시 현재 골드의 30%가 차감되어야 합니다.")
	_check(main.stage_transition_overlay.visible, "자동 부활을 시작하면 스테이지 전환 페이드가 표시되어야 합니다.")
	await get_tree().create_timer(1.7).timeout
	_check(not survivor.health.is_dead and not defeated.health.is_dead, "골드 부활 시 모든 캐릭터가 살아나야 합니다.")
	_check(main.stage_manager.kills == 0, "부활 시 현재 스테이지 진행도를 처음으로 되돌려야 합니다.")
	_check(not main.stage_transition_overlay.visible, "자동 부활이 끝나면 페이드 오버레이가 사라져야 합니다.")

	main.stage_manager._pending_stage = main.stage_manager.current_stage + 1
	main.stage_manager.progression_paused = true
	main._on_stage_transition_requested(main.stage_manager._pending_stage)
	await get_tree().create_timer(1.7).timeout
	_check(main.stage_manager.current_stage == 2, "화면이 가려진 뒤 다음 스테이지가 적용되어야 합니다.")
	_check(not main.stage_transition_overlay.visible, "스테이지 전환 후 검정 오버레이가 사라져야 합니다.")

	main._on_boss_battle_started()
	await get_tree().create_timer(0.65).timeout
	var atmosphere_material := main.boss_atmosphere_overlay.material as ShaderMaterial
	_check(main.party_speech_bubble.current_state == 3, "보스 등장 시 보스 등장 대사를 표시해야 합니다.")
	_check(main.boss_atmosphere_overlay.visible, "보스전에는 비네트 오버레이가 표시되어야 합니다.")
	_check(float(atmosphere_material.get_shader_parameter("intensity")) > 0.9, "보스 비네트 강도가 부드럽게 증가해야 합니다.")
	main._on_boss_battle_ended()
	await get_tree().create_timer(0.85).timeout
	_check(not main.boss_atmosphere_overlay.visible, "보스 종료 후 비네트 오버레이가 사라져야 합니다.")
	main._on_boss_defeated_dialogue()
	_check(main.party_speech_bubble.current_state == 2, "보스 처치 시 보스 처치 대사를 표시해야 합니다.")

	GameState.reset_progress()
	if not _failed:
		print("CORE_FLOW_TEST_OK")
	get_tree().quit(1 if _failed else 0)
