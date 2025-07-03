# scripts/managers/SkillManager.gd
# Autoload (싱글톤)으로 사용될 것을 가정함. 이름: SkillManager
extends Node
# class_name SkillManager # Autoload 사용 시 class_name 불필요


func execute_skill(caster: BaseCharacter, targets: Array[BaseCharacter], skill: SkillData, battle_manager) -> bool:
    if not caster or not skill:
        printerr("SkillManager: Caster or Skill is null.")
        return false

    if not caster.can_use_skill(skill):
        # BattleManager를 통해 로그 전송
        battle_manager.add_battle_log("%s(은)는 %s(을)를 사용하기에 자원이 부족합니다." % [caster.name, skill.skill_name])
        return false

    caster.consume_skill_cost(skill)
    battle_manager.add_battle_log("%s(이)가 %s(을)를 사용!" % [caster.name, skill.skill_name])

    # 여기서 애니메이션 재생 요청 또는 시그널 발생 가능
    # caster.play_animation(skill.animation_name)

    var success = true
    for effect_data in skill.effects:
        # 확률 적용
        if randf() > effect_data.chance:
            battle_manager.add_battle_log("%s의 %s 효과가 확률로 인해 발동하지 않았습니다." % [skill.skill_name, effect_data.effect_description])
            continue

        var actual_targets = _get_actual_targets_for_effect(caster, targets, effect_data, battle_manager)
        if actual_targets.is_empty():
            # battle_manager.add_battle_log("%s 효과의 대상을 찾을 수 없습니다." % effect_data.effect_description) # 너무 많은 로그가 될 수 있음
            continue

        for target_character in actual_targets:
            if target_character and not target_character.is_dead(): # 살아있는 대상에게만
                if not _apply_single_effect(caster, target_character, effect_data, battle_manager):
                    success = false # 하나의 효과라도 실패하면 전체 실패로 간주할 수도 있음 (설계에 따라)
            # else:
                # battle_manager.add_battle_log("%s 효과: 대상 %s가 전투 불능 상태입니다." % [effect_data.effect_description, target_character.name if target_character else "N/A"])

    return success


func _get_actual_targets_for_effect(caster: BaseCharacter, initial_targets: Array[BaseCharacter], effect_data: Effect, battle_manager) -> Array[BaseCharacter]:
    var final_targets: Array[BaseCharacter] = []
    var effect_target_type = effect_data.target_type

    match effect_target_type:
        Effect.TargetType.SELF:
            final_targets.append(caster)
        Effect.TargetType.SINGLE_ENEMY:
            # initial_targets가 이미 단일 적을 가리키고 있어야 함 (UI나 AI가 선택)
            if initial_targets.size() > 0 and initial_targets[0] != caster and not initial_targets[0].is_player_character == caster.is_player_character:
                final_targets.append(initial_targets[0])
        Effect.TargetType.SINGLE_ALLY:
            if initial_targets.size() > 0 and initial_targets[0] != caster and initial_targets[0].is_player_character == caster.is_player_character:
                 final_targets.append(initial_targets[0])
        Effect.TargetType.ALL_ENEMIES:
            final_targets.assign(battle_manager.get_all_enemy_characters_of(caster))
        Effect.TargetType.ALL_ALLIES:
            final_targets.assign(battle_manager.get_all_ally_characters_of(caster))
        Effect.TargetType.RANDOM_ENEMY:
            var enemies = battle_manager.get_all_enemy_characters_of(caster)
            var alive_enemies = enemies.filter(func(e): return not e.is_dead())
            if not alive_enemies.is_empty():
                final_targets.append(alive_enemies.pick_random())
        Effect.TargetType.RANDOM_ALLY:
            var allies = battle_manager.get_all_ally_characters_of(caster)
            var alive_allies = allies.filter(func(a): return not a.is_dead())
            if not alive_allies.is_empty():
                final_targets.append(alive_allies.pick_random())
        _: # 기본값은 초기 타겟들 (보통 SINGLE_ENEMY 나 SINGLE_ALLY 일 것)
            if initial_targets.size() > 0:
                 final_targets.append(initial_targets[0])

    # 최종 타겟 목록에서 죽은 캐릭터는 제외
    return final_targets.filter(func(t): return t and not t.is_dead())


func _apply_single_effect(caster: BaseCharacter, target: BaseCharacter, effect: Effect, battle_manager) -> bool:
    var effect_applied = false
    match effect.effect_type:
        Effect.EffectType.DAMAGE:
            var base_damage_stat = caster.get_modified_stat(effect.based_on_stat)
            var damage_value = int(base_damage_stat * effect.base_value)
            target.take_damage(damage_value, effect.damage_element, caster)
            effect_applied = true
        Effect.EffectType.HEAL:
            var base_heal_stat = caster.get_modified_stat(effect.based_on_stat)
            var heal_value = int(base_heal_stat * effect.base_value)
            target.heal(heal_value, caster)
            effect_applied = true
        Effect.EffectType.BUFF, Effect.EffectType.DEBUFF:
            target.add_buff(effect, effect.buff_duration, caster)
            effect_applied = true
        Effect.EffectType.SUMMON:
            # battle_manager.summon_character(effect.character_to_summon_data, caster_team)
            battle_manager.add_battle_log("소환 효과는 아직 구현되지 않았습니다: " + effect.effect_description)
            pass # TODO
        Effect.EffectType.SPECIAL:
            # battle_manager.apply_special_effect(caster, target, effect.special_effect_id)
            battle_manager.add_battle_log("특수 효과는 아직 구현되지 않았습니다: " + effect.effect_description)
            pass # TODO

    # if effect_applied:
    #     battle_manager.add_battle_log("%s에게 %s 효과 적용됨." % [target.name, effect.effect_description]) # 너무 많은 로그가 될 수 있음

    return effect_applied
