# scripts/characters/EnemyCharacter.gd
extends BaseCharacter
class_name EnemyCharacter

var ai_controller: AIController

func _ready():
	is_player_character = false # BaseCharacter의 플래그 설정
	# AIController는 BattleManager에서 EnemyCharacter를 생성할 때 주입하거나, 여기서 생성.
	# 여기서는 BattleManager에서 주입하는 것으로 가정.
	pass

func set_ai_controller(controller: AIController):
	ai_controller = controller
	if ai_controller:
		ai_controller.controlled_character = self # AI에게 자신을 알려줌

# BattleManager에서 호출
func decide_action(battle_manager) -> Dictionary:
	if ai_controller and not is_dead(): # 살아있을 때만 AI 작동
		return ai_controller.decide_action(battle_manager)
	return {} # AI가 없거나, 죽었거나, 결정할 수 없음 (빈 Dictionary는 행동 없음으로 처리)
