# scripts/data/Effect.gd
extends Resource
class_name Effect

enum EffectType { DAMAGE, HEAL, BUFF, DEBUFF, SUMMON, SPECIAL }
enum TargetType { SELF, SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, RANDOM_ENEMY, RANDOM_ALLY }
enum DamageElement { PHYSICAL, FIRE, ICE, LIGHTNING, DARK, HOLY } # 붕괴 스타레일 참고

@export var effect_type: EffectType = EffectType.DAMAGE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY # 스킬 레벨에서 정의될 수도 있음

# 데미지/힐 관련
@export var base_value: float = 1.0 # 계수 또는 고정값
@export var based_on_stat: String = "attack_power" # 데미지 계산 시 참조할 시전자 스탯
@export var damage_element: DamageElement = DamageElement.PHYSICAL

# 버프/디버프 관련
@export var buff_stat_modifier: String = "" # 예: "attack_power", "defense"
@export var buff_value_is_percentage: bool = true # true면 % 증가/감소, false면 고정값
@export var buff_duration: int = 1 # 턴 단위

# 기타
@export var chance: float = 1.0 # 발동 확률 (0.0 ~ 1.0)
@export_multiline var effect_description: String = "" # 효과 설명
# @export var sfx_path: String = "" # 효과음 경로
# @export var vfx_name: String = "" # 시각효과 이름
