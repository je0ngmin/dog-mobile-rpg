class_name PartyDialogueMessages
extends Resource

@export_group("평상시")
@export var normal_messages: PackedStringArray = [
	"오늘도 힘차게 달려보자!",
	"간식 냄새가 나는 것 같아.",
	"마을을 위해 조금만 더!",
	"이 길 끝에는 뭐가 있을까?",
	"발바닥은 멀쩡해. 계속 가자!",
	"폐허 속에도 쓸 만한 건 많아.",
	"우리라면 어디든 갈 수 있어!",
	"오늘 수확도 기대되는걸?",
]

@export_group("팀원 사망")
@export var teammate_down_messages: PackedStringArray = [
	"{name}! 괜찮아? 내가 버틸게!",
	"{name}, 조금만 버텨!",
	"동료가 쓰러졌어! 조심해!",
	"내가 앞을 막을게!",
	"아직 끝난 게 아니야!",
	"모두 정신 바짝 차려!",
]

@export_group("보스 등장")
@export var boss_arrived_messages: PackedStringArray = [
	"큰 녀석이 온다! 모두 준비해!",
	"보스다! 절대 물러서지 마!",
	"엄청 큰 발소리가 들려...",
	"대형 적 발견! 전투 준비!",
	"모두 내 뒤로 모여!",
	"이번 녀석, 만만치 않아 보여.",
]

@export_group("보스 처치")
@export var boss_defeated_messages: PackedStringArray = [
	"해냈다! 다음 스테이지로 가자!",
	"우리 원정대가 또 해냈어!",
	"별거 아니었네! 멍!",
	"마을에 돌아가서 자랑하자!",
	"다들 무사하지? 정말 다행이야.",
	"다음 구역도 이 기세로 돌파하자!",
]

@export_group("표시 시간")
@export_range(2.0, 15.0, 0.5) var normal_change_interval: float = 6.0
@export_range(1.0, 10.0, 0.5) var event_message_duration: float = 4.0
