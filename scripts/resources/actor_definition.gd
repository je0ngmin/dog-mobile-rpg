class_name ActorDefinition
extends Resource

@export_group("기본 정보")
@export var actor_id: StringName
@export var display_name: String = "이름 없음"
@export var role: int = 0
@export var role_name: String = ""
@export var texture: Texture2D
@export var body_color: Color = Color.WHITE

@export_group("전투 능력치")
@export var base_health: float = 100.0
@export var base_attack: float = 10.0
@export var attack_cooldown: float = 1.0
@export var attack_range: float = 90.0
@export var move_speed: float = 100.0

@export_group("스테이지 성장")
@export var health_growth: float = 1.0
@export var attack_growth: float = 1.0
@export var speed_per_stage: float = 0.0
@export var speed_bonus_cap: float = 0.0

@export_group("캐릭터 강화")
@export var upgrade_stat_name: String = ""
@export_range(0.0, 1.5, 0.1) var upgrade_percent: float = 0.0
@export_range(0.0, 1.5, 0.1) var health_per_upgrade_percent: float = 0.0
@export_range(0.0, 1.5, 0.1) var attack_per_upgrade_percent: float = 0.0
@export_range(0.0, 1.5, 0.1) var skill_per_upgrade_percent: float = 0.0
@export var skill_name: String = ""
@export var skill_multiplier: float = 1.0

@export_group("화면 표시")
@export var visual_height: float = 100.0
@export var sprite_position: Vector2 = Vector2(0.0, -50.0)
@export var name_label_position: Vector2 = Vector2(-70.0, -112.0)
@export var name_label_size: Vector2 = Vector2(140.0, 22.0)
@export var health_bar_width: float = 55.0
@export var health_bar_y: float = -86.0
