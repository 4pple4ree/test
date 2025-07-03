# scripts/ui/BattleUI.gd
extends Control
class_name BattleUI

# --- 노드 연결 (에디터에서 할당) ---
@export var character_info_container_player: Container # 플레이어 캐릭터 UI 들어갈 곳
@export var character_info_container_enemy: Container  # 적 캐릭터 UI 들어갈 곳
@export var player_action_panel: PanelContainer        # 플레이어 행동 버튼 패널
@export var skill_buttons_container: HBoxContainer     # 스킬 버튼들 들어갈 곳
@export var target_selection_panel: PanelContainer     # 타겟 선택 UI (필요시)
@export var battle_log_scroll: ScrollContainer
@export var battle_log_label: Label
@export var current_turn_label: Label
@export var battle_result_label: Label

# --- 프리팹 (씬) ---
const CHARACTER_STATUS_UI_SCENE = preload("res://scenes/ui/CharacterStatusUI.tscn") # 개별 캐릭터 정보 UI 씬
const SKILL_BUTTON_SCENE = preload("res://scenes/ui/SkillButton.tscn") # 스킬 버튼 UI 씬

var character_ui_map: Dictionary = {} # key: unique_id_ingame, value: CharacterStatusUI instance
var current_player_character_for_input: BaseCharacter = null
var current_selected_skill: SkillData = null
var battle_manager_node: BattleManager # BattleManager 참조 (주입 필요)


func _ready():
    if Engine.is_editor_hint():
        return

    player_action_panel.hide()
    target_selection_panel.hide()
    battle_result_label.hide()
    battle_log_label.text = ""


func set_battle_manager(manager: BattleManager):
    battle_manager_node = manager
    # 테스트 전투 시작 버튼 (임시)
    var test_battle_button = Button.new()
    test_battle_button.text = "Start Test Battle"
    add_child(test_battle_button) # UI 최상단에 임시로 추가
    test_battle_button.pressed.connect(Callable(battle_manager_node, "start_test_battle_from_external"))


func initialize_battle_ui(player_party: Array[BaseCharacter], enemy_party: Array[BaseCharacter]):
    # 이전 UI 요소들 제거
    for child in character_info_container_player.get_children():
        child.queue_free()
    for child in character_info_container_enemy.get_children():
        child.queue_free()
    character_ui_map.clear()
    battle_log_label.text = ""
    battle_result_label.hide()

    for p_char in player_party:
        _add_character_status_ui(p_char, character_info_container_player)
    for e_char in enemy_party:
        _add_character_status_ui(e_char, character_info_container_enemy)

func _add_character_status_ui(character: BaseCharacter, container: Container):
    if not CHARACTER_STATUS_UI_SCENE:
        printerr("CHARACTER_STATUS_UI_SCENE not loaded!")
        return

    var char_status_ui = CHARACTER_STATUS_UI_SCENE.instantiate() as Control # CharacterStatusUI 스크립트가 있다고 가정
    container.add_child(char_status_ui)
    character_ui_map[character.unique_id_ingame] = char_status_ui

    # CharacterStatusUI 스크립트에 캐릭터 정보 초기화 함수 호출
    if char_status_ui.has_method("initialize_status"):
        char_status_ui.initialize_status(character)

    # 시그널 연결
    character.health_changed.connect(Callable(self, "_on_character_health_changed").bind(character.unique_id_ingame))
    character.energy_changed.connect(Callable(self, "_on_character_energy_changed").bind(character.unique_id_ingame))
    character.buff_applied.connect(Callable(self, "_on_character_buff_event").bind(character.unique_id_ingame, true)) # true for applied
    character.buff_expired.connect(Callable(self, "_on_character_buff_event").bind(character.unique_id_ingame, false))# false for expired
    character.character_died.connect(Callable(self, "_on_character_died_ui_update").bind(character.unique_id_ingame))


func _on_character_health_changed(new_hp, max_hp, char_id_ingame):
    if character_ui_map.has(char_id_ingame):
        var ui_node = character_ui_map[char_id_ingame]
        if ui_node and ui_node.has_method("update_health"):
            ui_node.update_health(new_hp, max_hp)

func _on_character_energy_changed(current_ep, max_ep, char_id_ingame, energy_type: String):
    if character_ui_map.has(char_id_ingame):
        var ui_node = character_ui_map[char_id_ingame]
        if ui_node and ui_node.has_method("update_energy"):
            ui_node.update_energy(current_ep, max_ep, energy_type)

func _on_character_buff_event(buff_effect: Effect, char_id_ingame: String, is_applied: bool):
    if character_ui_map.has(char_id_ingame):
        var ui_node = character_ui_map[char_id_ingame]
        if ui_node and ui_node.has_method("update_buffs_display"):
            # CharacterStatusUI에서 해당 캐릭터의 active_buffs를 직접 참조하거나,
            # buff_effect와 is_applied 정보를 넘겨서 처리하도록 함.
            # 여기서는 간단히 전체 업데이트 요청.
            var character_node = _get_character_node_by_id(char_id_ingame) # 실제 캐릭터 노드 찾기
            if character_node:
                 ui_node.update_buffs_display(character_node.active_buffs)


func _on_character_died_ui_update(char_id_ingame: String):
    if character_ui_map.has(char_id_ingame):
        var ui_node = character_ui_map[char_id_ingame]
        if ui_node and ui_node.has_method("set_defeated_state"):
            ui_node.set_defeated_state(true)


func enable_player_input(player_character: BaseCharacter):
    current_player_character_for_input = player_character
    player_action_panel.show()
    _populate_skill_buttons(player_character)
    target_selection_panel.hide() # 이전 타겟 선택 UI 숨김

func disable_player_input():
    current_player_character_for_input = null
    current_selected_skill = null
    player_action_panel.hide()
    target_selection_panel.hide()

func _populate_skill_buttons(character: BaseCharacter):
    for child in skill_buttons_container.get_children():
        child.queue_free() # 이전 버튼들 제거

    var skills = character.get_all_skills() # 모든 스킬 가져오기 (사용 가능 여부는 버튼에서 체크)
    for skill_key_name in skills: # "basic_attack", "combat_skill_0" 등
        var skill_data: SkillData = skills[skill_key_name]

        if not SKILL_BUTTON_SCENE:
            printerr("SKILL_BUTTON_SCENE not loaded!")
            continue

        var skill_button_instance = SKILL_BUTTON_SCENE.instantiate() # SkillButton 스크립트가 있다고 가정
        skill_buttons_container.add_child(skill_button_instance)

        if skill_button_instance.has_method("set_skill_data"):
            skill_button_instance.set_skill_data(skill_data, character) # 버튼에 스킬 정보와 시전자 정보 전달

        # 버튼 클릭 시그널 연결
        if skill_button_instance.has_signal("skill_selected"): # SkillButton에서 정의한 시그널
            skill_button_instance.skill_selected.connect(Callable(self, "_on_skill_button_pressed").bind(skill_data))


func _on_skill_button_pressed(skill: SkillData):
    if not current_player_character_for_input or not battle_manager_node: return

    if not current_player_character_for_input.can_use_skill(skill):
        add_log_message("%s 사용 불가: 자원 부족 또는 조건 미충족" % skill.skill_name)
        return

    current_selected_skill = skill
    add_log_message("%s 선택됨. 대상을 선택하세요." % skill.skill_name)
    _show_target_selection_for_skill(skill)


func _show_target_selection_for_skill(skill: SkillData):
    target_selection_panel.show()
    # 이전 타겟 버튼들 제거
    for child in target_selection_panel.get_children(): # 실제 타겟 버튼 컨테이너 경로로 수정해야 함
        if child.has_meta("target_button"): # 임시 메타데이터로 구분
             child.queue_free()

    var potential_targets: Array[BaseCharacter] = []
    match skill.target_type:
        Effect.TargetType.SELF:
            potential_targets.append(current_player_character_for_input)
        Effect.TargetType.SINGLE_ENEMY:
            potential_targets.assign(battle_manager_node.get_all_enemy_characters_of(current_player_character_for_input))
        Effect.TargetType.ALL_ENEMIES: # 이 경우 타겟 선택 UI 없이 바로 실행 가능
            _confirm_action_with_targets(battle_manager_node.get_all_enemy_characters_of(current_player_character_for_input))
            return
        Effect.TargetType.SINGLE_ALLY:
            potential_targets.assign(battle_manager_node.get_all_ally_characters_of(current_player_character_for_input))
        Effect.TargetType.ALL_ALLIES:
            _confirm_action_with_targets(battle_manager_node.get_all_ally_characters_of(current_player_character_for_input))
            return
        # TODO: RANDOM_ENEMY, RANDOM_ALLY는 타겟 선택 없이 바로 실행

    if potential_targets.is_empty() and \
       skill.target_type != Effect.TargetType.ALL_ENEMIES and \
       skill.target_type != Effect.TargetType.ALL_ALLIES and \
       skill.target_type != Effect.TargetType.SELF: # SELF는 항상 자신이 타겟
        add_log_message("선택 가능한 대상이 없습니다.")
        target_selection_panel.hide()
        return

    # 타겟 버튼 생성 (target_selection_panel 내의 특정 컨테이너에)
    var target_button_container = target_selection_panel # 임시로 패널 자체를 컨테이너로 사용
    for target_char in potential_targets:
        if target_char.is_dead(): continue # 죽은 대상은 선택 불가

        var target_button = Button.new()
        target_button.text = target_char.name
        target_button.set_meta("target_button", true) # 임시 메타
        target_button_container.add_child(target_button)
        target_button.pressed.connect(Callable(self, "_on_target_selected").bind([target_char])) # 배열로 전달


func _on_target_selected(selected_targets: Array[BaseCharacter]):
    if not current_selected_skill or not current_player_character_for_input: return
    _confirm_action_with_targets(selected_targets)

func _confirm_action_with_targets(targets: Array[BaseCharacter]):
    if not battle_manager_node or not current_player_character_for_input or not current_selected_skill:
        printerr("UI: Cannot confirm action, missing context.")
        return

    battle_manager_node.on_player_action_confirmed(current_player_character_for_input, current_selected_skill, targets)
    target_selection_panel.hide()
    # player_action_panel.hide() # BattleManager에서 처리 후 disable_player_input 호출


func update_current_turn_indicator(actor: BaseCharacter):
    current_turn_label.text = actor.name + "의 턴"

func add_log_message(message: String):
    battle_log_label.text += message + "\n"
    # ScrollContainer를 맨 아래로 스크롤 (다음 프레임에 적용되도록)
    battle_log_scroll.call_deferred("set_v_scroll", battle_log_scroll.get_v_scroll_bar().max_value)


func show_battle_result(result_text: String):
    battle_result_label.text = result_text
    battle_result_label.show()
    disable_player_input() # 전투 종료 시 입력 비활성화

func highlight_active_character(char_id_ingame: String):
    for id in character_ui_map:
        var ui_node = character_ui_map[id]
        if ui_node and ui_node.has_method("set_highlight"):
            ui_node.set_highlight(id == char_id_ingame)


func _get_character_node_by_id(char_id_ingame: String) -> BaseCharacter:
    # BattleManager를 통해 실제 캐릭터 노드를 찾아야 함 (UI가 직접 캐릭터 노드를 알 필요는 없음)
    if battle_manager_node:
        for p_char in battle_manager_node.get_player_party():
            if p_char.unique_id_ingame == char_id_ingame: return p_char
        for e_char in battle_manager_node.get_enemy_party():
            if e_char.unique_id_ingame == char_id_ingame: return e_char
    return null

# --- 임시 캐릭터 상태 UI 씬 (CharacterStatusUI.tscn) 스크립트 예시 ---
# 이 스크립트는 CharacterStatusUI.tscn의 루트 노드에 붙어있다고 가정
# 캐릭터 체력바, 에너지바, 버프 아이콘 등을 관리
# func initialize_status(character_node: BaseCharacter): pass
# func update_health(new_hp, max_hp): pass
# func update_energy(current_ep, max_ep, energy_type): pass
# func update_buffs_display(active_buffs_array): pass
# func set_defeated_state(is_defeated: bool): pass
# func set_highlight(is_active: bool): pass

# --- 임시 스킬 버튼 UI 씬 (SkillButton.tscn) 스크립트 예시 ---
# 이 스크립트는 SkillButton.tscn의 루트 노드(Button)에 붙어있다고 가정
# signal skill_selected(skill_data: SkillData)
# var skill: SkillData
# var caster_char: BaseCharacter
# func set_skill_data(s_data: SkillData, caster: BaseCharacter):
#    skill = s_data
#    caster_char = caster
#    get_node("Label").text = skill.skill_name # 버튼 내부에 Label이 있다고 가정
#    disabled = not caster_char.can_use_skill(skill)
# func _on_pressed():
#    if not disabled: emit_signal("skill_selected", skill)
