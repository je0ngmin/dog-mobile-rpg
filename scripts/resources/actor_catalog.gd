class_name ActorCatalog
extends Resource

@export var characters: Array[Resource] = []
@export var normal_enemies: Array[Resource] = []
@export var bosses: Array[Resource] = []


func character_at(index: int) -> ActorDefinition:
	return _definition_at(characters, index)


func normal_enemy_for_stage(stage_number: int) -> ActorDefinition:
	return _definition_at(normal_enemies, stage_number - 1)


func boss_for_stage(stage_number: int) -> ActorDefinition:
	return _definition_at(bosses, stage_number - 1)


func _definition_at(definitions: Array[Resource], index: int) -> ActorDefinition:
	if definitions.is_empty():
		return null
	return definitions[posmod(index, definitions.size())] as ActorDefinition
