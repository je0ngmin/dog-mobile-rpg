class_name StageBackground
extends Sprite2D

const AREA_BACKGROUND_PATHS := [
	"res://sprites/backgrounds/BG001.png",
	"res://sprites/backgrounds/BG002.png",
	"res://sprites/backgrounds/BG003.png",
]

@export_range(1, 100, 1) var stages_per_area: int = 5
@export var target_size: Vector2 = Vector2(1200.0, 675.0)

var _loaded_area_index: int = -1


func set_stage(stage_number: int) -> void:
	var area_index := maxi(stage_number - 1, 0) / stages_per_area
	area_index = clampi(area_index, 0, AREA_BACKGROUND_PATHS.size() - 1)
	if area_index == _loaded_area_index and texture != null:
		return
	var loaded_resource: Resource = ResourceLoader.load(
		AREA_BACKGROUND_PATHS[area_index],
		"Texture2D",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if not loaded_resource is Texture2D:
		push_warning("배경 Texture2D를 불러오지 못했습니다: %s" % AREA_BACKGROUND_PATHS[area_index])
		return
	var loaded_texture: Texture2D = loaded_resource as Texture2D
	texture = loaded_texture
	_loaded_area_index = area_index
	_fit_texture_to_view()


func _fit_texture_to_view() -> void:
	if texture == null:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var cover_scale := maxf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	scale = Vector2.ONE * cover_scale
