# CharacterScreen.gd
extends Control

# --- 노드 참조 (씬 트리 구조에 맞게 @onready var로 설정) ---
# 예시 경로임. 실제 씬 구조에 따라 정확히 수정해야 함.
@onready var party_member_list: ItemList = $PanelContainer/VBoxContainer/HSplitContainer/PartyListPanel/VBoxContainer/PartyMemberList if has_node("PanelContainer/VBoxContainer/HSplitContainer/PartyListPanel/VBoxContainer/PartyMemberList") else null
@onready var details_container: VBoxContainer = $PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer if has_node("PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer") else null
@onready var character_name_label: Label = $PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer/CharacterNameLabel if has_node("PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer/CharacterNameLabel") else null
@onready var character_sprite_display: TextureRect = $PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer/CharacterSprite if has_node("PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer/CharacterSprite") else null
@onready var stats_grid: GridContainer = $PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer/StatsGrid if has_node("PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer/StatsGrid") else null
@onready var skills_container: VBoxContainer = $PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer/SkillsContainer if has_node("PanelContainer/VBoxContainer/HSplitContainer/CharacterDetailsPanel/ScrollContainer/DetailsContainer/SkillsContainer") else null
@onready var back_button: Button = $PanelContainer/VBoxContainer/BackButton if has_node("PanelContainer/VBoxContainer/BackButton") else null

var player_party_characters: Array[CharacterData] = []
var selected_character_index: int = -1
var previous_scene_path: String = ""

func _ready():
    var all_nodes_found = true
    var required_nodes_map = {
        "PartyMemberList": party_member_list, "DetailsContainer": details_container,
        "CharacterNameLabel": character_name_label, "CharacterSprite": character_sprite_display,
        "StatsGrid": stats_grid, "SkillsContainer": skills_container, "BackButton": back_button
    }
    for node_name in required_nodes_map:
        if not is_instance_valid(required_nodes_map[node_name]):
            printerr("CharacterScreen: Node '%s' not found! Check scene paths." % node_name)
            all_nodes_found = false
    if not all_nodes_found:
        printerr("CharacterScreen: One or more essential UI nodes are missing. Functionality will be limited.")
        # 여기서 게임을 중단하거나, 사용자에게 알림을 표시할 수 있음.

    if is_instance_valid(details_container): details_container.visible = false

    if is_instance_valid(back_button):
        if not back_button.pressed.is_connected(Callable(self, "_on_back_button_pressed")):
            back_button.pressed.connect(Callable(self, "_on_back_button_pressed"))

    if is_instance_valid(party_member_list):
        if not party_member_list.item_selected.is_connected(Callable(self, "_on_party_member_selected")):
            party_member_list.item_selected.connect(Callable(self, "_on_party_member_selected"))

    if GameManager:
        previous_scene_path = GameManager.get_current_scene_path() # GameManager에 이 함수가 있다고 가정
        if GameManager.has_method("get_player_party_for_status_screen"):
             player_party_characters = GameManager.get_player_party_for_status_screen()
        else:
            printerr("CharacterScreen: GameManager missing 'get_player_party_for_status_screen' method. Using temp data.")
            _load_temp_player_data() # 임시 데이터 로드 함수 호출
        populate_party_list()
    else:
        printerr("CharacterScreen: GameManager not found in _ready! Cannot load party data.")
        _load_temp_player_data() # GameManager 없을 때도 임시 데이터 로드
        populate_party_list() # 임시 데이터로 목록 채우기 시도


func _load_temp_player_data():
    # GameManager 접근 불가 또는 함수 부재 시 사용할 임시 플레이어 데이터
    player_party_characters.clear() # 기존 임시 데이터가 있다면 초기화
    var p_char_temp = load("res://resources/characters/player_data_example.tres") as CharacterData
    if is_instance_valid(p_char_temp): player_party_characters.append(p_char_temp)
    # 필요하다면 두 번째 임시 캐릭터 추가
    # var p_char_temp2 = load("res://resources/characters/player_data_mage_example.tres") as CharacterData
    # if is_instance_valid(p_char_temp2): player_party_characters.append(p_char_temp2)


func populate_party_list():
    if not is_instance_valid(party_member_list): return
    party_member_list.clear()

    if player_party_characters.is_empty():
        party_member_list.add_item("플레이어 파티 정보 없음")
        return

    for i in range(player_party_characters.size()):
        var char_data: CharacterData = player_party_characters[i]
        if is_instance_valid(char_data) and is_instance_valid(char_data.base_stats): # base_stats 유효성도 확인
            party_member_list.add_item(char_data.character_name if not char_data.character_name.is_empty() else "이름 없는 캐릭터")
        else:
            party_member_list.add_item("캐릭터 데이터 오류 [%d]" % i)


func _on_party_member_selected(index: int):
    if not is_instance_valid(details_container): return
    if index >= 0 and index < player_party_characters.size():
        selected_character_index = index
        var selected_char_data: CharacterData = player_party_characters[selected_character_index]
        if is_instance_valid(selected_char_data):
            display_character_details(selected_char_data)
            details_container.visible = true
        else:
            details_container.visible = false # 유효하지 않은 데이터면 상세 정보 숨김
            printerr("CharacterScreen: Selected character data at index %d is invalid." % index)
    else:
        details_container.visible = false
        printerr("CharacterScreen: Invalid index %d for party member selection." % index)


func display_character_details(char_data: CharacterData):
    if not is_instance_valid(char_data) or \
       not is_instance_valid(details_container) or \
       not is_instance_valid(character_name_label) or \
       not is_instance_valid(character_sprite_display) or \
       not is_instance_valid(stats_grid) or \
       not is_instance_valid(skills_container):
        printerr("CharacterScreen: One or more UI elements for details panel are missing.")
        return

    character_name_label.text = char_data.character_name if not char_data.character_name.is_empty() else "이름 없음"

    # 캐릭터 스프라이트 (CharacterData에 sprite_texture_preview 필드가 Texture2D 타입으로 있다고 가정)
    var preview_texture = char_data.get("sprite_texture_preview") as Texture2D
    if is_instance_valid(preview_texture):
         character_sprite_display.texture = preview_texture
         character_sprite_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
         character_sprite_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    else: # PackedScene을 로드하여 Sprite2D에서 텍스처를 가져오는 방식 (더 복잡)
        if char_data.sprite_scene and char_data.sprite_scene is PackedScene:
            var sprite_scene_instance = char_data.sprite_scene.instantiate()
            var sprite_node_in_scene = sprite_scene_instance.get_node_or_null("Sprite2D") # 가정: PackedScene 내에 Sprite2D 노드가 있음
            if sprite_node_in_scene and sprite_node_in_scene is Sprite2D:
                character_sprite_display.texture = sprite_node_in_scene.texture
            else:
                character_sprite_display.texture = null
            sprite_scene_instance.queue_free() # 인스턴스 사용 후 바로 해제
        else:
            character_sprite_display.texture = null

    # 스탯 표시
    for child in stats_grid.get_children(): child.queue_free()
    if is_instance_valid(char_data.base_stats):
        var stats_ref = char_data.base_stats
        var display_order = ["max_health", "attack_power", "defense", "speed", "max_skill_points", "max_ultimate_energy"]
        var display_names = {"max_health":"최대HP", "attack_power":"공격력", "defense":"방어력", "speed":"속도", "max_skill_points":"최대SP", "max_ultimate_energy":"최대ULT"}

        for stat_key in display_order:
            if stats_ref.has(stat_key):
                var name_lbl = Label.new()
                name_lbl.text = display_names.get(stat_key, stat_key.capitalize()) + ":"
                var val_lbl = Label.new()
                val_lbl.text = str(stats_ref.get(stat_key))
                stats_grid.add_child(name_lbl)
                stats_grid.add_child(val_lbl)
    else:
        var no_stats_lbl = Label.new(); no_stats_lbl.text = "스탯 정보 없음"; stats_grid.add_child(no_stats_lbl)

    # 스킬 목록 표시
    for child in skills_container.get_children(): child.queue_free()
    var all_skills: Array[SkillData] = []
    if is_instance_valid(char_data.basic_attack_skill): all_skills.append(char_data.basic_attack_skill)
    if is_instance_valid(char_data.combat_skills): all_skills.append_array(char_data.combat_skills)
    if is_instance_valid(char_data.ultimate_skill): all_skills.append(char_data.ultimate_skill)

    if all_skills.is_empty():
        var no_skills_lbl = Label.new(); no_skills_lbl.text = "보유 스킬 없음"; skills_container.add_child(no_skills_lbl)
    else:
        for skill_data in all_skills:
            if is_instance_valid(skill_data):
                var skill_type_str = SkillData.SkillType.find_key(skill_data.skill_type)
                if skill_type_str: skill_type_str = skill_type_str.replace("SKILL","").replace("ATTACK","").capitalize()
                else: skill_type_str = "알수없음"

                var skill_entry_text = "%s (%s): %s" % [
                    skill_data.skill_name if not skill_data.skill_name.is_empty() else "이름없는 스킬",
                    skill_type_str,
                    skill_data.description if not skill_data.description.is_empty() else "설명 없음"
                ]
                var skill_label = Label.new()
                skill_label.text = skill_entry_text
                skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD
                skills_container.add_child(skill_label)


func _on_back_button_pressed():
    print("CharacterScreen: BackButton pressed.")
    if GameManager:
        var path_to_return = previous_scene_path
        if path_to_return.is_empty() or not ResourceLoader.exists(path_to_return): # 돌아갈 경로가 없거나 유효하지 않으면 메인 메뉴로
            printerr("CharacterScreen: Invalid or empty previous_scene_path ('%s'). Returning to Main Menu." % previous_scene_path)
            path_to_return = GameManager.MAIN_MENU_SCENE
        GameManager.change_scene_to_path(path_to_return)
    else:
        printerr("CharacterScreen: GameManager not found. Cannot go back.")

```
