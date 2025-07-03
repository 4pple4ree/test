# scripts/ui/SkillButton.gd
extends Button
class_name SkillButton

signal skill_selected(skill_data: SkillData)

var skill: SkillData
var caster_character: BaseCharacter

# 씬 트리에서 SkillNameLabel과 CostLabel이 이 버튼의 자식으로 있다고 가정
@onready var skill_name_label: Label = get_node_or_null("SkillNameLabel") if has_node("SkillNameLabel") else self
# self를 fallback으로 하면 버튼의 text 속성이 사용됨
@onready var cost_label: Label = get_node_or_null("CostLabel")


func set_skill_data(s_data: SkillData, caster: BaseCharacter):
    skill = s_data
    caster_character = caster

    if skill_name_label == self: # Button 자체를 Label로 사용
        text = skill.skill_name
    elif skill_name_label: # 별도의 Label 자식 노드가 있다면
        skill_name_label.text = skill.skill_name
    else: # 둘 다 없으면 버튼 텍스트에 스킬 이름 설정 (안전장치)
        text = skill.skill_name

    var cost_text_parts = []
    if skill.skill_point_cost > 0:
        cost_text_parts.append("SP:%d" % skill.skill_point_cost)
    if skill.ultimate_energy_cost > 0:
        cost_text_parts.append("ULT:%d" % skill.ultimate_energy_cost)

    if cost_label:
        if cost_text_parts.is_empty():
            cost_label.text = "소모 없음"
            cost_label.hide() # 소모 없으면 숨길 수도 있음
        else:
            cost_label.text = " / ".join(cost_text_parts)
            cost_label.show()

    # 사용 가능 여부에 따라 버튼 활성화/비활성화
    update_usability()

    # 툴팁으로 스킬 설명 추가
    tooltip_text = "%s\n%s\n%s" % [skill.skill_name, cost_label.text if cost_label and cost_label.visible else "소모 없음", skill.description]


func _on_pressed(): # 버튼 자체의 pressed 시그널에 이 함수를 연결해야 함 (에디터에서 또는 코드로)
    if not disabled and skill:
        emit_signal("skill_selected", skill)

# BattleUI에서 플레이어 턴 변경 시 또는 캐릭터 상태 변경 시 이 함수를 호출하여 버튼 상태 업데이트 가능
func update_usability():
    if caster_character and skill:
        disabled = not caster_character.can_use_skill(skill)
    else: # 정보가 없으면 비활성화
        disabled = true

func _ready():
    # self의 pressed 시그널에 _on_pressed 함수를 연결 (코드에서 명시적으로 연결)
    if not pressed.is_connected(Callable(self, "_on_pressed")):
        pressed.connect(Callable(self, "_on_pressed"))

    # 초기 상태 업데이트 (혹시 set_skill_data가 _ready보다 늦게 호출될 경우 대비)
    if caster_character and skill:
        update_usability()
    else: # 정보 없으면 비활성화
        disabled = true
```
