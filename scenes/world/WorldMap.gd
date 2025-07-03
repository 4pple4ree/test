# WorldMap.gd
extends Node2D

@onready var player_node: Node2D = $Player # 씬 트리의 플레이어 노드 경로
# @onready var enemy_encounter_area: Area2D = $EnemyEncounterNode # 예시 적 인카운터 노드

# 플레이어 이동 속도
@export var player_speed: float = 200.0

# 전투에 필요한 정보 (인스펙터에서 설정하거나, 이 씬 로드 시 GameManager 등에서 전달받을 수 있음)
@export var enemy_group_for_encounter: String = "goblin_patrol" # 예시 적 그룹 ID
@export var map_data_for_battle: String = "res://resources/maps/map_data_example.tres" # 전투에 사용할 맵 데이터 경로

func _ready():
    # 초기 플레이어 위치 설정 (필요시)
    if is_instance_valid(player_node):
        # player_node.position = Vector2(100, 100) # 예시
        pass
    else:
        printerr("WorldMap: Player node not found. Check scene setup.")


    # Area2D를 사용한 인카운터 예시 (플레이어가 CharacterBody2D이고, Area2D가 EnemyEncounterNode 이름일 때)
    var enemy_node_example = get_node_or_null("EnemyEncounterNode") # 씬에 이 이름의 Area2D가 있다고 가정
    if is_instance_valid(enemy_node_example) and enemy_node_example is Area2D:
        var area2d_node = enemy_node_example as Area2D
        # body_entered는 CharacterBody2D 같은 물리 바디와 상호작용.
        # 플레이어가 단순 Node2D면 Area2D의 area_entered 시그널을 사용하고 플레이어도 Area2D여야 함.
        # 여기서는 플레이어가 CharacterBody2D라고 가정.
        if not area2d_node.body_entered.is_connected(Callable(self, "_on_enemy_encounter_triggered").bind(enemy_node_example)):
             area2d_node.body_entered.connect(Callable(self, "_on_enemy_encounter_triggered").bind(enemy_node_example))
    # else:
        # printerr("WorldMap: EnemyEncounterNode (Area2D) not found or not an Area2D.")


    # 임시: 간단한 버튼으로 전투 시작 (디버깅/테스트용)
    var temp_battle_trigger_button = Button.new()
    temp_battle_trigger_button.text = "Engage Enemy (Test Button)"
    add_child(temp_battle_trigger_button) # WorldMap 노드의 자식으로 추가
    temp_battle_trigger_button.global_position = Vector2(get_viewport_rect().size.x * 0.8, get_viewport_rect().size.y * 0.1) # 화면 우상단 근처
    if not temp_battle_trigger_button.pressed.is_connected(Callable(self, "_on_temp_battle_button_pressed")):
        temp_battle_trigger_button.pressed.connect(Callable(self, "_on_temp_battle_button_pressed"))

    print("WorldMap loaded. Player at: ", player_node.position if is_instance_valid(player_node) else "N/A")


func _physics_process(delta: float):
    if not is_instance_valid(player_node):
        return

    var velocity = Vector2.ZERO
    if Input.is_action_pressed("ui_right"):
        velocity.x += 1
    if Input.is_action_pressed("ui_left"):
        velocity.x -= 1
    if Input.is_action_pressed("ui_down"):
        velocity.y += 1
    if Input.is_action_pressed("ui_up"):
        velocity.y -= 1

    if velocity.length_squared() > 0: # length()보다 length_squared()가 약간 더 효율적
        velocity = velocity.normalized() * player_speed
        # CharacterBody2D를 사용한다면 move_and_slide() 또는 move_and_collide() 사용
        # player_node.velocity = velocity
        # player_node.move_and_slide()
        # 여기서는 Node2D이므로 직접 position 변경
        player_node.position += velocity * delta


# Area2D의 body_entered 시그널에 연결될 함수 (플레이어가 CharacterBody2D일 때)
func _on_enemy_encounter_triggered(body_or_area, encounter_node_ref: Node2D): # body 또는 area, 그리고 어떤 인카운터인지
   if body_or_area == player_node: # 또는 body_or_area.is_in_group("player")
       print("WorldMap: Player encountered enemy at: ", encounter_node_ref.name)
       # encounter_node_ref에서 전투 정보 가져오기 (예: encounter_node_ref.enemy_group_id)
       # 여기서는 클래스 변수 사용
       _initiate_battle(enemy_group_for_encounter, map_data_for_battle)
       # 전투 후 인카운터 비활성화 또는 제거 로직 필요
       if is_instance_valid(encounter_node_ref):
           encounter_node_ref.get_node("CollisionShape2D").disabled = true # 임시 비활성화
           encounter_node_ref.get_node("Sprite2D").modulate = Color(1,1,1,0.3) # 반투명


func _on_temp_battle_button_pressed():
    _initiate_battle(enemy_group_for_encounter, map_data_for_battle)


func _initiate_battle(enemy_group: String, map_path: String):
    print("WorldMap: Initiating battle with group '%s' on map '%s'" % [enemy_group, map_path])
    if GameManager: # GameManager Autoload 확인
        GameManager.set_next_battle_info(enemy_group, map_path)
        GameManager.change_scene_to_path(GameManager.BATTLE_SCENE)
    else:
        printerr("WorldMap: GameManager not found. Cannot start battle.")

```
