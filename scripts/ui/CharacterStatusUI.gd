# scripts/ui/CharacterStatusUI.gd
# 이 스크립트는 CharacterStatusUI.tscn의 루트 노드에 붙어있다고 가정
# 예시 루트 노드: PanelContainer
extends PanelContainer
class_name CharacterStatusUI

# --- 노드 참조 (씬 트리 구조에 맞게 @onready var로 설정) ---
@onready var name_label: Label = $VBoxContainer/NameLabel # 예시 경로
@onready var hp_progress: ProgressBar = $VBoxContainer/HPProgress # 예시 경로
@onready var hp_label: Label = $VBoxContainer/HPProgress/HPLabel # 예시 경로 (ProgressBar의 자식)
@onready var sp_label: Label = $VBoxContainer/SPLabel # 예시 경로
@onready var ult_progress: ProgressBar = $VBoxContainer/ULTProgress # 예시 경로
@onready var buff_container: HBoxContainer = $VBoxContainer/BuffContainer # 예시 경로

# @export var buff_icon_scene: PackedScene # 버프 아이콘 표시용 씬 (예: TextureRect + Label)

var associated_character: BaseCharacter # 이 UI가 표시하는 캐릭터의 참조

# BattleUI에서 캐릭터 UI 생성 시 호출
func initialize_status(character: BaseCharacter):
    associated_character = character
    if not is_instance_valid(associated_character):
        printerr("CharacterStatusUI: Associated character is not valid.")
        return

    name_label.text = associated_character.name # BaseCharacter의 name (unique_id_ingame 포함 가능)
    update_health()
    update_energy("sp")
    update_energy("ult")
    update_buffs_display()
    set_defeated_state(associated_character.is_dead())
    set_highlight(false) # 초기에는 하이라이트 없음

    # 캐릭터의 시그널에 연결하여 자동 업데이트
    if not associated_character.health_changed.is_connected(Callable(self, "update_health")):
        associated_character.health_changed.connect(Callable(self, "update_health"))

    # 에너지 시그널은 타입 정보를 넘겨줘야 하므로, bind 또는 람다 사용
    if not associated_character.energy_changed.is_connected(Callable(self, "_on_energy_changed_forwarder")):
        associated_character.energy_changed.connect(Callable(self, "_on_energy_changed_forwarder"))

    if not associated_character.buff_applied.is_connected(Callable(self, "update_buffs_display")):
        associated_character.buff_applied.connect(Callable(self, "update_buffs_display"))

    if not associated_character.buff_expired.is_connected(Callable(self, "update_buffs_display")):
        associated_character.buff_expired.connect(Callable(self, "update_buffs_display"))

    if not associated_character.character_died.is_connected(Callable(self, "_on_character_died_ui")):
        associated_character.character_died.connect(Callable(self, "_on_character_died_ui"))

# energy_changed 시그널의 인자 순서와 update_energy 함수의 인자 순서를 맞추기 위한 전달 함수
func _on_energy_changed_forwarder(current_val, max_val, _char_id, energy_type_str):
    update_energy(energy_type_str, current_val, max_val)


func update_health(_current_hp = -1, _max_hp = -1, _char_id = ""): # 시그널 인자들은 사용 안해도 됨
    if not is_instance_valid(associated_character): return
    hp_progress.max_value = associated_character.current_stats.max_health
    hp_progress.value = associated_character.current_stats.current_health
    hp_label.text = "HP: %d/%d" % [associated_character.current_stats.current_health, associated_character.current_stats.max_health]

func update_energy(energy_type: String, _current_val = -1, _max_val = -1): # char_id는 여기서 불필요
    if not is_instance_valid(associated_character): return
    if energy_type == "sp":
        sp_label.text = "SP: %d/%d" % [associated_character.current_stats.skill_points, associated_character.current_stats.max_skill_points]
    elif energy_type == "ult":
        ult_progress.max_value = associated_character.current_stats.max_ultimate_energy
        ult_progress.value = associated_character.current_stats.ultimate_energy
        # ult_progress 자식으로 Label이 있다면 그것도 업데이트

func update_buffs_display(_buff_effect = null, _char_id = ""): # 시그널 인자들은 사용 안해도 됨
    if not is_instance_valid(associated_character): return

    for child in buff_container.get_children():
        child.queue_free()

    for buff_entry in associated_character.active_buffs:
        var effect: Effect = buff_entry.effect
        var duration: int = buff_entry.duration

        var buff_display_node # = buff_icon_scene.instantiate() if buff_icon_scene else Label.new()
        # 임시로 Label 사용, 실제로는 아이콘 + 툴팁 (buff_icon_scene 활용)
        if not buff_display_node:
            buff_display_node = Label.new()
            buff_display_node.tooltip_text = "%s\n%d턴 남음" % [effect.effect_description, duration]

        if buff_display_node is Label:
            var buff_text = effect.effect_description if effect.effect_description else "효과"
            buff_display_node.text = "%s(%d)" % [buff_text.left(min(buff_text.length(), 4)), duration] # 설명 앞 최대 4글자와 지속시간
        # elif buff_display_node.has_method("set_buff_info"):
        #    buff_display_node.set_buff_info(effect, duration)

        buff_container.add_child(buff_display_node)

func _on_character_died_ui(_char_id = ""):
     if not is_instance_valid(associated_character): return
     set_defeated_state(true)

func set_defeated_state(is_defeated: bool):
    modulate = Color(0.5, 0.5, 0.5, 0.7) if is_defeated else Color.WHITE
    # 더 복잡한 처리 가능 (예: 흑백 처리, 특정 오버레이 추가)

func set_highlight(is_active: bool):
    # 현재 턴인 캐릭터를 시각적으로 강조 (예: 테두리, 배경색 변경)
    var style_box_to_use = get("theme_override_styles/panel_normal") # 기존 스타일 가져오기 (없으면 null)
    if not style_box_to_use or not style_box_to_use is StyleBoxFlat: # 없거나 타입이 다르면 새로 생성
        style_box_to_use = StyleBoxFlat.new()
        style_box_to_use.bg_color = Color(0.2, 0.2, 0.25, 0.5) # 기본 배경색 (어둡게)
    else: # 기존 스타일 복제해서 수정 (원본 테마 스타일을 건드리지 않기 위해)
        style_box_to_use = style_box_to_use.duplicate() as StyleBoxFlat


    if is_active:
        style_box_to_use.bg_color = Color(0.4, 0.5, 0.3, 0.6) # 활성 시 배경색 변경
        style_box_to_use.border_width_left = 2
        style_box_to_use.border_width_top = 2
        style_box_to_use.border_width_right = 2
        style_box_to_use.border_width_bottom = 2
        style_box_to_use.border_color = Color.YELLOW_GREEN # 테두리 색
    else: # 비활성 시 기본 스타일 또는 테두리 없는 스타일
        style_box_to_use.border_width_left = 0 # 테두리 제거 (또는 기본값)
        style_box_to_use.border_width_top = 0
        style_box_to_use.border_width_right = 0
        style_box_to_use.border_width_bottom = 0
        # style_box_to_use.bg_color = Color(0.2, 0.2, 0.25, 0.5) # 기본 배경색 다시 설정

    set("theme_override_styles/panel", style_box_to_use)

func _notification(what):
    if what == NOTIFICATION_PREDELETE:
        if is_instance_valid(associated_character):
            if associated_character.health_changed.is_connected(Callable(self, "update_health")):
                associated_character.health_changed.disconnect(Callable(self, "update_health"))
            if associated_character.energy_changed.is_connected(Callable(self, "_on_energy_changed_forwarder")):
                associated_character.energy_changed.disconnect(Callable(self, "_on_energy_changed_forwarder"))
            if associated_character.buff_applied.is_connected(Callable(self, "update_buffs_display")):
                associated_character.buff_applied.disconnect(Callable(self, "update_buffs_display"))
            if associated_character.buff_expired.is_connected(Callable(self, "update_buffs_display")):
                associated_character.buff_expired.disconnect(Callable(self, "update_buffs_display"))
            if associated_character.character_died.is_connected(Callable(self, "_on_character_died_ui")):
                associated_character.character_died.disconnect(Callable(self, "_on_character_died_ui"))
        associated_character = null
```
