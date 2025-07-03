# scripts/ai/AIController.gd
extends Node # 또는 Object. 캐릭터의 자식 노드로 추가되거나 BattleManager에서 관리될 수 있음.
class_name AIController

var controlled_character: BaseCharacter # AI가 제어할 캐릭터 (주입 필요)

func _init(character: BaseCharacter = null): # 생성자에서 캐릭터를 받을 수도 있음
	controlled_character = character

# 간단한 AI: 사용 가능한 스킬 중 무작위로 하나 선택, 무작위 적 타겟팅
func decide_action(battle_manager: BattleManager) -> Dictionary:
	if not controlled_character or controlled_character.is_dead():
		return {} # 제어할 캐릭터가 없거나 죽었으면 행동 불가

	var available_skills_map: Dictionary = controlled_character.get_all_available_skills()
	if available_skills_map.is_empty():
		battle_manager.add_battle_log("%s(은)는 사용할 수 있는 스킬이 없습니다." % controlled_character.name)
		return {} # 행동 불가

	# 스킬 사용 우선순위 (예: 궁극기 > 전투 스킬 > 기본 공격)
	var chosen_skill: SkillData = null

	# 1. 궁극기 시도
	var ultimate_skill_key = "ultimate_skill" # BaseCharacter._setup_skills()에서 설정한 키
	if available_skills_map.has(ultimate_skill_key):
		chosen_skill = available_skills_map[ultimate_skill_key]

	# 2. 궁극기 없으면 전투 스킬 시도 (여러 개 중 무작위 또는 특정 조건)
	if not chosen_skill:
		var combat_skills_available: Array[SkillData] = []
		for skill_key in available_skills_map:
			var skill: SkillData = available_skills_map[skill_key]
			if skill.skill_type == SkillData.SkillType.COMBAT_SKILL:
				combat_skills_available.append(skill)
		if not combat_skills_available.is_empty():
			chosen_skill = combat_skills_available.pick_random() # 일단 무작위

	# 3. 전투 스킬도 없으면 기본 공격 시도
	if not chosen_skill:
		var basic_attack_key = "basic_attack"
		if available_skills_map.has(basic_attack_key):
			chosen_skill = available_skills_map[basic_attack_key]

    # 3. 전투 스킬도 없으면 기본 공격 시도
    if not chosen_skill:
        var basic_attack_skill_data = controlled_character.get_skill_by_type_name("basic_attack")
        if basic_attack_skill_data and controlled_character.can_use_skill(basic_attack_skill_data):
            chosen_skill = basic_attack_skill_data

    if not chosen_skill:
        battle_manager.add_battle_log("%s(은)는 사용할 스킬을 찾지 못했습니다. (기본 공격 포함)" % controlled_character.name)
		return {}


	# 타겟 결정
	var potential_targets: Array[BaseCharacter] = []
	var targets_for_skill: Array[BaseCharacter] = []

	# 스킬의 주 타겟 타입에 따라 대상 목록 가져오기
	# ALL_ENEMIES, ALL_ALLIES, SELF 등은 타겟 선택이 필요 없을 수 있음
	match chosen_skill.target_type:
		Effect.TargetType.SELF:
			targets_for_skill.append(controlled_character)
		Effect.TargetType.SINGLE_ENEMY, Effect.TargetType.RANDOM_ENEMY:
			potential_targets = battle_manager.get_all_enemy_characters_of(controlled_character)
			if not potential_targets.is_empty():
				targets_for_skill.append(potential_targets.pick_random()) # 일단 무작위 단일 적
		Effect.TargetType.ALL_ENEMIES:
			targets_for_skill = battle_manager.get_all_enemy_characters_of(controlled_character)
		Effect.TargetType.SINGLE_ALLY, Effect.TargetType.RANDOM_ALLY: # 아군 대상 스킬 (예: 힐, 버프)
			potential_targets = battle_manager.get_all_ally_characters_of(controlled_character)
			# 자신을 제외한 아군 또는 체력이 가장 낮은 아군 등 좀 더 똑똑한 로직 필요
			var allies_excluding_self = potential_targets.filter(func(ally): return ally != controlled_character and not ally.is_dead())
			if not allies_excluding_self.is_empty():
				targets_for_skill.append(allies_excluding_self.pick_random())
			elif not potential_targets.is_empty() and chosen_skill.target_type != Effect.TargetType.SELF : # 자신이라도 타겟팅 (만약 아군 대상 스킬인데 아군이 자기뿐)
				var self_if_no_other_ally = potential_targets.filter(func(ally): return ally == controlled_character and not ally.is_dead())
				if not self_if_no_other_ally.is_empty(): targets_for_skill.append(self_if_no_other_ally[0])

		Effect.TargetType.ALL_ALLIES:
			targets_for_skill = battle_manager.get_all_ally_characters_of(controlled_character)
		_: # 기타 경우 (예: 스킬 데이터에 타겟 타입 명시 안됨 - 기본적으로 단일 적)
			potential_targets = battle_manager.get_all_enemy_characters_of(controlled_character)
			if not potential_targets.is_empty():
				targets_for_skill.append(potential_targets.pick_random())


	if targets_for_skill.is_empty() and chosen_skill.target_type != Effect.TargetType.SELF:
		# SELF가 아닌데 타겟이 없으면 행동 불가 (예: 모든 적이 죽었는데 공격 스킬 사용 시도)
		battle_manager.add_battle_log("%s(은)는 %s 스킬의 대상을 찾지 못했습니다." % [controlled_character.name, chosen_skill.skill_name])
		return {}


	battle_manager.add_battle_log("AI (%s) 결정: %s 사용 (대상: %s)" % [controlled_character.name, chosen_skill.skill_name, str(targets_for_skill.map(func(t): return t.name))])
	return {"skill": chosen_skill, "targets": targets_for_skill}
