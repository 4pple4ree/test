# scripts/characters/PlayerCharacter.gd
extends BaseCharacter
class_name PlayerCharacter

# 플레이어 전용 로직이 있다면 여기에 추가
# 예를 들어, 특정 아이템 사용 로직, 플레이어 고유 패시브 등

func _ready():
	is_player_character = true # BaseCharacter의 플래그 설정
	# 플레이어 캐릭터의 고유 ID는 어떻게 설정할지 고민 필요 (예: "player_0", "player_main")
	# initialize 함수에서 is_player 플래그를 이미 받고 있으므로 _ready에서 중복 설정 안해도 될 수 있음.
	pass
