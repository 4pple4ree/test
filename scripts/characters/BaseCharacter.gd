# scripts/characters/BaseCharacter.gd
extends Node2D
class_name BaseCharacter

signal health_changed(current_hp, max_hp, character_id)
signal energy_changed(current_ep, max_ep, character_id, energy_type) # energy_type: "sp" or "ult"
signal character_died(character_id)
signal buff_applied(buff_effect, character_id)
signal buff_expired(buff_effect, character_id)
signal action_taken(character_id, action_description) # 로그용

var character_data: CharacterData
var current_stats: Stats # CharacterData의 base_stats를 복제해서 사용
var skills_map: Dictionary = {} # {"basic_attack": SkillData, "combat_skill_0": SkillData, "ultimate_skill": SkillData}

var active_buffs: Array[Dictionary] = [] # [{"effect": Effect, "duration": int, "source_id": String}]

var is_player_character: bool = false # 구분용
var unique_id_ingame: String # 전투 중 각 캐릭터를 구분하기 위한 ID (character_data.character_id와 다를 수 있음, 예: enemy_goblin_1)


func initialize(data: CharacterData, instance_id: String, is_player: bool = false):
    character_data = data
    is_player_character = is_player
    name = character_data.character_name + "_" + instance_id # 노드 이름 설정 (고유하게)
    unique_id_ingame = instance_id

    if character_data.base_stats:
        current_stats = character_data.base_stats.clone()
        # 전투 시작 시 현재 체력을 최대 체력으로 설정
        current_stats.current_health = current_stats.max_health
    else:
        printerr("CharacterData is missing base_stats: ", character_data.character_id)
        current_stats = Stats.new() # 기본값으로라도 생성

    _setup_skills()
    _setup_visuals()

    # 초기 상태 UI 업데이트를 위해 시그널 발생
    emit_signal("health_changed", current_stats.current_health, current_stats.max_health, unique_id_ingame)
    emit_signal("energy_changed", current_stats.skill_points, current_stats.max_skill_points, unique_id_ingame, "sp")
    emit_signal("energy_changed", current_stats.ultimate_energy, current_stats.max_ultimate_energy, unique_id_ingame, "ult")


func _setup_skills():
    if character_data.basic_attack_skill:
        skills_map["basic_attack"] = character_data.basic_attack_skill
    var i = 0
    for skill_data in character_data.combat_skills:
        skills_map["combat_skill_" + str(i)] = skill_data
        i += 1
    if character_data.ultimate_skill:
        skills_map["ultimate_skill"] = character_data.ultimate_skill

func _setup_visuals():
    # 기존 자식 노드(스프라이트 등)가 있다면 제거 (재초기화 시)
    for child in get_children():
        if child.is_in_group("visual_representation"): # 스프라이트 노드에 그룹 추가 가정
            child.queue_free()

    if character_data.sprite_scene:
        var sprite_instance = character_data.sprite_scene.instantiate()
        sprite_instance.add_to_group("visual_representation")
        add_child(sprite_instance)
    # else if character_data.sprite_texture: # 단순 텍스처 사용 시
    #     var sprite = Sprite2D.new()
    #     sprite.texture = character_data.sprite_texture
    #     sprite.add_to_group("visual_representation")
    #     add_child(sprite)

func take_damage(amount: int, damage_element: Effect.DamageElement, source_character: BaseCharacter):
    # TODO: 방어력, 속성 저항, 버프/디버프에 따른 최종 데미지 계산
    var calculated_defense = get_modified_stat("defense")
    var final_damage = max(1, amount - calculated_defense) # 최소 1 데미지 (임시 방어력 계산)

    current_stats.current_health = max(0, current_stats.current_health - final_damage)
    emit_signal("health_changed", current_stats.current_health, current_stats.max_health, unique_id_ingame)

    var log_message = "%s(이)가 %s에게 %d의 %s 피해를 입혔습니다." % [source_character.name, name, final_damage, Effect.DamageElement.find_key(damage_element)]
    # BattleManager를 통해 로그 전송 (BattleManager.add_battle_log(log_message))
    if get_tree().get_root().has_node("Main/BattleManager"): # 임시 접근
        get_node("/root/Main/BattleManager").add_battle_log(log_message)

    # 피격 시 궁극기 에너지 획득 (스타레일 방식 - 간단히 구현)
    current_stats.ultimate_energy = min(current_stats.max_ultimate_energy, current_stats.ultimate_energy + 5) # 예시: 5씩 획득
    emit_signal("energy_changed", current_stats.ultimate_energy, current_stats.max_ultimate_energy, unique_id_ingame, "ult")

    if current_stats.current_health <= 0:
        die()

func heal(amount: int, source_character: BaseCharacter):
    current_stats.current_health = min(current_stats.max_health, current_stats.current_health + amount)
    emit_signal("health_changed", current_stats.current_health, current_stats.max_health, unique_id_ingame)
    var log_message = "%s(이)가 %s(을)를 %d만큼 치유했습니다." % [source_character.name, name, amount]
    if get_tree().get_root().has_node("Main/BattleManager"):
        get_node("/root/Main/BattleManager").add_battle_log(log_message)


func add_buff(buff_effect_data: Effect, duration: int, source_character: BaseCharacter):
    # TODO: 중복 버프 처리 (스택, 덮어쓰기, 지속시간 갱신 등)
    # 동일한 buff_stat_modifier를 가진 버프가 이미 있는지 확인
    for existing_buff_entry in active_buffs:
        if existing_buff_entry.effect.buff_stat_modifier == buff_effect_data.buff_stat_modifier and \
           existing_buff_entry.effect.effect_type == buff_effect_data.effect_type:
            # 예시: 동일한 스탯 버프는 지속시간 갱신 및 더 강한 효과로 덮어쓰기 (간단히는 지속시간만 갱신)
            existing_buff_entry.duration = max(existing_buff_entry.duration, duration) # 더 긴 지속시간으로
            print("Buff Refreshed/Overwritten: %s on %s" % [buff_effect_data.effect_description, name])
            emit_signal("buff_applied", buff_effect_data, unique_id_ingame) # UI 갱신용
            return

    active_buffs.append({"effect": buff_effect_data, "duration": duration, "source_id": source_character.unique_id_ingame})
    emit_signal("buff_applied", buff_effect_data, unique_id_ingame)
    var log_message = "%s에게 %s 효과 적용 (%d턴 지속)." % [name, buff_effect_data.effect_description, duration]
    if get_tree().get_root().has_node("Main/BattleManager"):
        get_node("/root/Main/BattleManager").add_battle_log(log_message)


func process_turn_start_effects():
    # 버프/디버프 지속시간 감소
    var new_buffs = []
    for buff_entry in active_buffs:
        buff_entry.duration -= 1
        if buff_entry.duration > 0:
            new_buffs.append(buff_entry)
        else:
            emit_signal("buff_expired", buff_entry.effect, unique_id_ingame)
            var log_message = "%s의 %s 효과가 만료되었습니다." % [name, buff_entry.effect.effect_description]
            if get_tree().get_root().has_node("Main/BattleManager"):
                get_node("/root/Main/BattleManager").add_battle_log(log_message)
    active_buffs = new_buffs

    # 스킬 포인트 회복 (스타레일식: 턴 시작 시 1개, 최대치까지) - 플레이어만 또는 특정 조건
    if is_player_character:
        if current_stats.skill_points < current_stats.max_skill_points:
            current_stats.skill_points = min(current_stats.max_skill_points, current_stats.skill_points + 1)
            emit_signal("energy_changed", current_stats.skill_points, current_stats.max_skill_points, unique_id_ingame, "sp")


func get_modified_stat(stat_name: String) -> float:
    var base_value: float = current_stats.get(stat_name) if current_stats and stat_name in current_stats else 0.0
    var percentage_increase: float = 0.0
    var flat_increase: float = 0.0

    for buff_entry in active_buffs:
        var effect: Effect = buff_entry.effect
        if effect.buff_stat_modifier == stat_name:
            if effect.buff_value_is_percentage:
                percentage_increase += effect.base_value # base_value가 0.2면 20% 증가
            else:
                flat_increase += effect.base_value

    var final_value = base_value * (1.0 + percentage_increase) + flat_increase
    return final_value


func can_use_skill(skill: SkillData) -> bool:
    if skill.skill_point_cost > current_stats.skill_points:
        print("%s: 스킬 포인트 부족 (%s 필요, %s 보유)" % [name, skill.skill_point_cost, current_stats.skill_points])
        return false
    if skill.ultimate_energy_cost > current_stats.ultimate_energy:
        print("%s: 궁극기 에너지 부족 (%s 필요, %s 보유)" % [name, skill.ultimate_energy_cost, current_stats.ultimate_energy])
        return false
    # TODO: 쿨타임, 특정 상태 조건 등 추가 검사
    return true

func consume_skill_cost(skill: SkillData):
    current_stats.skill_points -= skill.skill_point_cost
    current_stats.ultimate_energy -= skill.ultimate_energy_cost
    emit_signal("energy_changed", current_stats.skill_points, current_stats.max_skill_points, unique_id_ingame, "sp")
    emit_signal("energy_changed", current_stats.ultimate_energy, current_stats.max_ultimate_energy, unique_id_ingame, "ult")

    # 스킬 사용 시 궁극기 에너지 획득 (스타레일 방식 - 간단히 구현)
    if skill.skill_type != SkillData.SkillType.ULTIMATE_SKILL: # 궁극기 사용 시에는 획득 안함
        current_stats.ultimate_energy = min(current_stats.max_ultimate_energy, current_stats.ultimate_energy + 10) # 예시: 10씩 획득
        emit_signal("energy_changed", current_stats.ultimate_energy, current_stats.max_ultimate_energy, unique_id_ingame, "ult")

# 캐릭터 이동 (논리적 위치 변경 및 화면 위치 업데이트)
func move_character_to_position(new_world_position: Vector2, new_grid_pos: Vector2i = Vector2i.MAX): # Vector2i.MAX는 그리드 위치 미지정 의미
    # TODO: 실제 이동 애니메이션 또는 부드러운 이동은 추후 구현
    global_position = new_world_position
    if new_grid_pos != Vector2i.MAX:
        current_grid_position = new_grid_pos

    # 이동 로그 (필요시)
    # if get_tree().get_root().has_node("Main/BattleManager"):
    #     get_node("/root/Main/BattleManager").add_battle_log("%s가 위치 (%s)로 이동." % [name, str(new_world_position)])

func perform_basic_attack(targets: Array[BaseCharacter], battle_manager: BattleManager):
    var basic_attack_skill_data = get_skill_by_type_name("basic_attack")
    if basic_attack_skill_data:
        if can_use_skill(basic_attack_skill_data): # 기본 공격도 코스트가 있을 수 있으므로 확인
            # SkillManager는 Autoload로 가정
            SkillManager.execute_skill(self, targets, basic_attack_skill_data, battle_manager)
            emit_signal("action_taken", unique_id_ingame, basic_attack_skill_data.skill_name + " 사용 (대상: " + str(targets.map(func(t): return t.name)) + ")")
        else:
            battle_manager.add_battle_log("%s: 기본 공격 사용 불가 (자원 부족 등)" % name)
    else:
        battle_manager.add_battle_log("%s: 기본 공격 스킬이 정의되지 않았습니다." % name)

func perform_combat_skill(skill_slot_index: int, targets: Array[BaseCharacter], battle_manager: BattleManager):
    var skill_key = "combat_skill_" + str(skill_slot_index)
    var combat_skill_data = get_skill_by_type_name(skill_key)

    if combat_skill_data:
        if can_use_skill(combat_skill_data):
            SkillManager.execute_skill(self, targets, combat_skill_data, battle_manager)
            emit_signal("action_taken", unique_id_ingame, combat_skill_data.skill_name + " 사용 (대상: " + str(targets.map(func(t): return t.name)) + ")")
        else:
            battle_manager.add_battle_log("%s: %s 사용 불가 (자원 부족 등)" % [name, combat_skill_data.skill_name])
    else:
        battle_manager.add_battle_log("%s: 해당 슬롯(%d)에 전투 스킬이 없습니다." % [name, skill_slot_index])

func perform_ultimate_skill(targets: Array[BaseCharacter], battle_manager: BattleManager):
    var ultimate_skill_data = get_skill_by_type_name("ultimate_skill")
    if ultimate_skill_data:
        if can_use_skill(ultimate_skill_data):
            SkillManager.execute_skill(self, targets, ultimate_skill_data, battle_manager)
            emit_signal("action_taken", unique_id_ingame, ultimate_skill_data.skill_name + " 사용 (대상: " + str(targets.map(func(t): return t.name)) + ")")
        else:
            battle_manager.add_battle_log("%s: 궁극기 사용 불가 (자원 부족 등)" % name)
    else:
        battle_manager.add_battle_log("%s: 궁극기 스킬이 정의되지 않았습니다." % name)

func die():
    print(name + " is defeated!")
    emit_signal("character_died", unique_id_ingame)
    # 캐릭터 비활성화 또는 숨김 처리
    hide() # 간단히 숨김 처리
    set_process(false) # 더 이상 처리하지 않음


func get_skill_by_type_name(type_str: String) -> SkillData: # "basic_attack", "combat_skill_0", "ultimate_skill"
    return skills_map.get(type_str, null)

func get_all_available_skills() -> Dictionary: # UI에서 사용 가능 스킬 목록 표시용
    var available_skills = {}
    for skill_key in skills_map:
        var skill_data = skills_map[skill_key]
        if can_use_skill(skill_data):
            available_skills[skill_key] = skill_data
    return available_skills

func get_all_skills() -> Dictionary:
    return skills_map

func is_dead() -> bool:
    return current_stats.current_health <= 0

# 전투 종료 후 또는 재사용을 위해 상태 초기화
func reset_state():
    if character_data and character_data.base_stats:
        current_stats = character_data.base_stats.clone()
        current_stats.current_health = current_stats.max_health # 체력 완전 회복
    active_buffs.clear()
    show()
    set_process(true)
    # UI 업데이트 시그널들 다시 발생
    emit_signal("health_changed", current_stats.current_health, current_stats.max_health, unique_id_ingame)
    emit_signal("energy_changed", current_stats.skill_points, current_stats.max_skill_points, unique_id_ingame, "sp")
    emit_signal("energy_changed", current_stats.ultimate_energy, current_stats.max_ultimate_energy, unique_id_ingame, "ult")
    # 모든 버프 제거 UI 업데이트
    # ...
