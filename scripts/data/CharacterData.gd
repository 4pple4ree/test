# scripts/data/CharacterData.gd
extends Resource
class_name CharacterData

@export var character_id: String = "unique_character_id"
@export var character_name: String = "캐릭터 이름"
@export_multiline var description: String = "캐릭터 설명"
@export var sprite_scene: PackedScene = null # 캐릭터 외형을 위한 PackedScene (Sprite2D, AnimationPlayer 등 포함)
# 또는 @export var sprite_texture: Texture2D = null (단순 스프라이트 시)

@export var base_stats: Stats = null # Stats 리소스 참조
@export var basic_attack_skill: SkillData = null # 기본 공격 스킬 리소스 참조
@export var combat_skills: Array[SkillData] = [] # 전투 스킬 리소스 목록 참조
@export var ultimate_skill: SkillData = null # 궁극기 스킬 리소스 참조
# @export var passive_skills: Array[SkillData] = [] # 패시브 스킬
