# GameManager.gd
extends Node

# 씬 경로 상수 (실제 경로에 맞게 수정 필요)
const MAIN_MENU_SCENE = "res://scenes/ui/MainMenu.tscn"
const BATTLE_SCENE = "res://scenes/battle/Battle.tscn" # 전투 씬 경로 변경 가정
const WORLD_MAP_SCENE = "res://scenes/world/WorldMap.tscn"
const CHARACTER_SCREEN_SCENE = "res://scenes/ui/CharacterScreen.tscn"

var current_scene_node: Node = null # 현재 활성화된 씬의 루트 노드 참조

# 게임 시작 시 초기 씬 로드 (예: _ready 함수에서 메인 메뉴 로드)
func _ready():
    # 현재 씬이 없는 경우 (게임 첫 시작 시) 메인 메뉴로 시작
    # 루트 뷰포트에 직접 씬을 추가하는 방식이 아니라면,
    # get_tree().current_scene은 초기에는 null일 수 있음.
    var root = get_tree().get_root()
    current_scene_node = root.get_child(root.get_child_count() -1) # 마지막에 추가된 씬을 현재 씬으로 가정

    if not is_instance_valid(get_tree().current_scene) or get_tree().current_scene.scene_file_path.is_empty():
        call_deferred("change_scene_to_path", MAIN_MENU_SCENE)
    else:
        # 이미 씬이 로드되어 있다면 (예: 에디터에서 특정 씬 실행) 해당 씬을 현재 씬으로 설정
        current_scene_node = get_tree().current_scene


# 지정된 경로의 씬으로 전환하는 함수
func change_scene_to_path(scene_path: String):
    # 이전 current_scene_node가 유효하고 GameManager의 자식이 아닌 경우,
    # get_tree().change_scene_to_file()이 자동으로 이전 씬을 queue_free() 하므로
    # GameManager에서 직접 current_scene_node를 queue_free() 할 필요는 보통 없음.
    # current_scene_node는 단순히 참조용.

    var result = get_tree().change_scene_to_file(scene_path)
    if result == OK:
        # 새 씬 로드 후 current_scene_node 업데이트 (다음 프레임에 하는 것이 안전)
        call_deferred("_on_scene_changed") # _update_current_scene_node 대신 시그널 핸들러 같은 이름 사용
        print("GameManager: Attempting to change scene to ", scene_path)
    else:
        printerr("GameManager: Failed to change scene to ", scene_path, " with error code: ", result)

func _on_scene_changed():
    # get_tree().current_scene이 새 씬의 루트 노드가 됨
    current_scene_node = get_tree().current_scene
    if is_instance_valid(current_scene_node):
        var scene_name_to_print = current_scene_node.scene_file_path if current_scene_node.scene_file_path else current_scene_node.name
        print("GameManager: Successfully changed and current scene node updated to: ", scene_name_to_print)
    else:
        printerr("GameManager: Failed to get current scene node after change.")

# 게임 종료 함수
func quit_game():
    get_tree().quit()

# --- 게임 상태 및 데이터 관리 변수 (추후 확장) ---
# var player_party_data: Array[CharacterData] = [] # 실제 CharacterData 리소스 배열
# var current_player_location: String = ""
# var game_progress_flags: Dictionary = {}

# 전투 시작 시 필요한 데이터 (예시)
var next_battle_enemy_group_id: String = "" # 실제로는 적 CharacterData 배열 또는 ID 목록
var next_battle_map_data_path: String = ""  # MapData 리소스 경로

func set_next_battle_info(enemy_group_id_or_data, map_data_path_or_data):
    # enemy_group_id_or_data는 ID 문자열 또는 CharacterData 배열일 수 있음
    # map_data_path_or_data는 MapData 리소스 경로 또는 MapData 객체일 수 있음
    # 여기서는 간단히 문자열 ID/경로로 가정
    if typeof(enemy_group_id_or_data) == TYPE_STRING:
        next_battle_enemy_group_id = enemy_group_id_or_data
    # else if typeof(enemy_group_id_or_data) == TYPE_ARRAY:
        # next_battle_enemy_datas = enemy_group_id_or_data # 이런 식으로 직접 데이터 전달도 가능

    if typeof(map_data_path_or_data) == TYPE_STRING:
        next_battle_map_data_path = map_data_path_or_data
    # else if map_data_path_or_data is MapData:
        # next_battle_map_actual_data = map_data_path_or_data

    print("GameManager: Next battle info set - Enemies: %s, Map Path: %s" % [str(enemy_group_id_or_data), str(map_data_path_or_data)])

# BattleManager가 전투 준비 시 이 정보를 가져갈 수 있도록 함수 제공
func get_next_battle_info() -> Dictionary:
    # BattleManager는 이 정보를 바탕으로 실제 리소스를 로드해야 함
    return {
        "enemy_group_id": next_battle_enemy_group_id, # 또는 실제 데이터 배열
        "map_data_path": next_battle_map_data_path    # 또는 실제 MapData 객체
    }

func clear_next_battle_info():
    next_battle_enemy_group_id = ""
    next_battle_map_data_path = ""

# 예시: 게임 시작 시 플레이어 파티 설정 (실제로는 저장 파일 로드 등)
# func initialize_player_party():
#     var player_char_data = load("res://resources/characters/player_data_example.tres") as CharacterData
#     if player_char_data:
#         player_party_data = [player_char_data]
#     else:
#         printerr("GameManager: Failed to load initial player data for party.")

# func get_player_party() -> Array[CharacterData]:
#    return player_party_data

# func _unhandled_input(event):
    # 디버그용: 숫자 키로 씬 전환 테스트
    # if event is InputEventKey and event.pressed and not event.is_echo():
        # if event.keycode == KEY_1:
            # change_scene_to_path(MAIN_MENU_SCENE)
        # elif event.keycode == KEY_2:
            # set_next_battle_info("goblin_squad", "res://resources/maps/map_data_example.tres") # 예시 정보
            # change_scene_to_path(BATTLE_SCENE)
        # elif event.keycode == KEY_3:
            # change_scene_to_path(WORLD_MAP_SCENE)
        # elif event.keycode == KEY_4:
            # change_scene_to_path(CHARACTER_SCREEN_SCENE)
```
