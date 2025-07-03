# scripts/data/SkillData.gd
extends Resource
class_name SkillData

enum SkillType { BASIC_ATTACK, COMBAT_SKILL, ULTIMATE_SKILL, PASSIVE }

@export var skill_id: String = "unique_skill_id"
@export var skill_name: String = "스킬 이름"
@export_multiline var description: String = "스킬 설명"
@export var icon: Texture2D = null

@export var skill_type: SkillType = SkillType.COMBAT_SKILL
@export var target_type: Effect.TargetType = Effect.TargetType.SINGLE_ENEMY # 주 타겟 타입

@export var skill_point_cost: int = 1
@export var ultimate_energy_cost: int = 0
# @export var cooldown: int = 0 # 쿨타임 (필요시)

@export var effects: Array[Effect] = [] # 이 스킬이 가진 모든 효과들

# @export var animation_name: String = "" # 시전자 애니메이션
