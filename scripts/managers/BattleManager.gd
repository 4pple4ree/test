# scripts/managers/BattleManager.gd
extends Node
class_name BattleManager

# 캐릭터 프리팹 (씬)
const BASE_CHARACTER_SCENE = preload("res://scenes/characters/BaseCharacterScene.tscn") # 캐릭터 기본 씬 경로

# UI 연결 (에디터에서 설정하거나 _ready에서 get_node)
@export var battle_ui_path: NodePath
@onready var battle_ui: BattleUI = get_node(battle_ui_path) if battle_ui_path else null

# 캐릭터 배치용 노드 (에디터에서 Main.tscn 내부에 설정)
@export var player_spawn_points_parent_path: NodePath # 경로로 받고 _ready에서 노드 가져오기
@export var enemy_spawn_points_parent_path: NodePath

@onready var player_spawns_root: Node2D = get_node_or_null(player_spawn_points_parent_path) if player_spawn_points_parent_path else null
@onready var enemy_spawns_root: Node2D = get_node_or_null(enemy_spawn_points_parent_path) if enemy_spawn_points_parent_path else null

var current_map_instance: Node = null # 현재 로드된 맵 씬의 루트 노드 참조

var player_party: Array[BaseCharacter] = []
var enemy_party: Array[BaseCharacter] = []
var turn_queue: Array[BaseCharacter] = [] # 현재 턴 진행 중인 캐릭터 포함 전체 턴 순서
var current_actor: BaseCharacter = null
var current_map_data: MapData

var battle_in_progress: bool = false
var player_input_awaits: bool = false

# 유니크 ID 생성을 위한 카운터
var character_instance_counter: int = 0

func _ready():
    if Engine.is_editor_hint():
        return

    # 스폰 지점 노드들 가져오기
    if get_node_or_null(player_spawn_points_parent):
        for child in get_node(player_spawn_points_parent).get_children():
            if child is Node2D:
                player_spawns.append(child)
    if get_node_or_null(enemy_spawn_points_parent):
        for child in get_node(enemy_spawn_points_parent).get_children():
            if child is Node2D:
                enemy_spawns.append(child)

    # SkillManager가 Autoload가 아니라면 여기서 인스턴스화 필요 없음 (이미 Autoload로 가정)

    # UI가 제대로 연결되었는지 확인
    if not battle_ui:
        printerr("BattleManager: BattleUI is not assigned or found!")
        # get_tree().quit() # 또는 에러 처리
        return

    # 테스트용 데이터 로드 및 전투 시작 (예시)
    # 실제 게임에서는 다른 GameManager나 레벨 로더에서 호출될 것임
    # _start_test_battle()


func _start_test_battle(): # 테스트용 함수
    var p_char_data1 = load("res://resources/characters/player_test.tres") as CharacterData
    var e_char_data1 = load("res://resources/characters/enemy_test.tres") as CharacterData
    var e_char_data2 = load("res://resources/characters/enemy_test_2.tres") as CharacterData # 다른 적 데이터
    var map_data = load("res://resources/maps/map_test.tres") as MapData

    if p_char_data1 and e_char_data1 and e_char_data2 and map_data:
        var player_datas = [p_char_data1]
        var enemy_datas = [e_char_data1, e_char_data2]
        setup_battle(map_data, player_datas, enemy_datas)
    else:
        printerr("Failed to load one or more test resources for battle.")


func setup_battle(map_data: MapData, player_character_datas: Array[CharacterData], enemy_character_datas: Array[CharacterData]):
    if battle_in_progress:
        print("Battle already in progress. Cannot start a new one yet.")
        return

    print("--- Setting up Battle ---")
    current_map_data = map_data
    # TODO: 맵 관련 설정 (배경, 음악 등)
    # if current_map_data.tilemap_scene:
    #     var map_instance = current_map_data.tilemap_scene.instantiate()
    #     # 적절한 위치에 add_child(map_instance)

    # 이전 전투의 캐릭터들 정리 (필요시)
    _clear_parties()
    character_instance_counter = 0 # ID 카운터 리셋

    # 플레이어 캐릭터 생성 및 초기화
    for i in range(player_character_datas.size()):
        var char_data = player_character_datas[i]
        var spawn_point = player_spawns[i % player_spawns.size()] if not player_spawns.is_empty() else self # 스폰 포인트 없으면 BattleManager 위치
        var player_node = _create_character_instance(char_data, true, spawn_point.global_position)
        player_party.append(player_node)

    # 적 캐릭터 생성 및 초기화
    for i in range(enemy_character_datas.size()):
        var char_data = enemy_character_datas[i]
        var spawn_point = enemy_spawns[i % enemy_spawns.size()] if not enemy_spawns.is_empty() else self
        var enemy_node = _create_character_instance(char_data, false, spawn_point.global_position)
        enemy_party.append(enemy_node)
        # 적 AI 설정
        var enemy_char = enemy_node as EnemyCharacter
        if enemy_char:
            enemy_char.set_ai_controller(AIController.new(enemy_char))


    # 턴 순서 결정 (속도 기반)
    turn_queue.assign(player_party + enemy_party)
    turn_queue.sort_custom(func(a, b): return a.current_stats.speed > b.current_stats.speed)

    # 죽은 캐릭터는 턴 큐에서 제외 (초기화 시에는 모두 살아있겠지만)
    turn_queue = turn_queue.filter(func(c): return not c.is_dead())

    if turn_queue.is_empty():
        printerr("No characters in turn queue. Battle cannot start.")
        # TODO: 전투 실패 처리 또는 로그
        return

    battle_in_progress = true
    player_input_awaits = false
    if battle_ui: battle_ui.initialize_battle_ui(player_party, enemy_party) # UI 초기화

    add_battle_log("전투 시작! 맵: " + current_map_data.map_name)
    _proceed_to_next_actor()


func _create_character_instance(char_data: CharacterData, is_player: bool, position: Vector2) -> BaseCharacter:
    if not BASE_CHARACTER_SCENE:
        printerr("BASE_CHARACTER_SCENE is not loaded!")
        return null

    var character_node = BASE_CHARACTER_SCENE.instantiate() as BaseCharacter
    if not character_node:
        printerr("Failed to instantiate BASE_CHARACTER_SCENE.")
        return null

    # Battle Scene 노드 아래에 추가 (예: get_node("BattleSceneContainer"))
    # 여기서는 BattleManager의 자식으로 직접 추가 (씬 구조에 따라 변경)
    var battle_scene_container = get_node_or_null("BattleScene") # Main.tscn에 BattleScene 노드가 있다고 가정
    if battle_scene_container:
        battle_scene_container.add_child(character_node)
    else:
        add_child(character_node) # 임시로 BattleManager 자식으로

    character_instance_counter += 1
    var instance_id = ("p" if is_player else "e") + str(character_instance_counter)

    character_node.initialize(char_data, instance_id, is_player)
    character_node.global_position = position
    character_node.character_died.connect(Callable(self, "_on_character_died").bind(character_node))
    return character_node

func _clear_parties():
    for char_node in player_party:
        if is_instance_valid(char_node):
            char_node.queue_free()
    player_party.clear()
    for char_node in enemy_party:
        if is_instance_valid(char_node):
            char_node.queue_free()
    enemy_party.clear()
    turn_queue.clear()


func _proceed_to_next_actor():
    if not battle_in_progress: return

    if _check_battle_over_conditions():
        _end_battle()
        return

    # 현재 턴 큐에서 다음 액터 선정 (죽은 캐릭터 건너뛰기)
    var next_actor_found = false
    while not turn_queue.is_empty() and not next_actor_found:
        current_actor = turn_queue.pop_front()
        if current_actor and not current_actor.is_dead():
            next_actor_found = true
        else: # 죽었거나 유효하지 않은 경우 큐에 다시 넣지 않음
            current_actor = null

    if not next_actor_found or not current_actor: # 모든 캐릭터가 행동했거나 큐가 비었음 (이론상 _check_battle_over_conditions에서 걸러짐)
        add_battle_log("다음 행동할 캐릭터가 없습니다. 전투 상태 확인 중...")
        if _check_battle_over_conditions(): _end_battle()
        return

    turn_queue.append(current_actor) # 처리 후 다시 큐의 맨 뒤로

    add_battle_log("--- %s의 턴 ---" % current_actor.name)
    current_actor.process_turn_start_effects() # 턴 시작 시 효과 처리 (스킬 포인트 회복 등)

    if battle_ui:
        battle_ui.update_current_turn_indicator(current_actor)
        battle_ui.highlight_active_character(current_actor.unique_id_ingame)

    if current_actor.is_player_character:
        player_input_awaits = true
        if battle_ui:
            battle_ui.enable_player_input(current_actor)
    else: # 적 턴
        player_input_awaits = false
        if battle_ui:
            battle_ui.disable_player_input()

        var enemy_char = current_actor as EnemyCharacter
        if enemy_char:
            # AI 행동 결정에 약간의 딜레이를 주어 플레이어가 볼 수 있게 함
            await get_tree().create_timer(0.5).timeout
            if not battle_in_progress or current_actor.is_dead(): return # AI 결정 전 전투 종료 또는 사망

            var action_to_take = enemy_char.decide_action(self)
            if action_to_take.has("skill") and action_to_take.has("targets"):
                # SkillManager는 Autoload로 가정
                SkillManager.execute_skill(current_actor, action_to_take.targets, action_to_take.skill, self)
            else:
                add_battle_log("%s(은)는 행동하지 않았습니다." % current_actor.name)

            # 적 행동 후 다음 턴 진행 (애니메이션 시간 등 고려하여 딜레이)
            await get_tree().create_timer(1.0).timeout
            if not battle_in_progress: return # 딜레이 중 전투 종료 시
            _proceed_to_next_actor()
        else: # AI가 없는 적인 경우 (오류 또는 특수 케이스)
            add_battle_log("%s(은)는 AI가 없어 행동하지 않습니다." % current_actor.name)
            await get_tree().create_timer(1.0).timeout
            if not battle_in_progress: return
            _proceed_to_next_actor()


func _check_battle_over_conditions() -> bool:
    var all_players_defeated = player_party.all(func(p_char): return p_char.is_dead())
    var all_enemies_defeated = enemy_party.all(func(e_char): return e_char.is_dead())

    if all_players_defeated:
        add_battle_log("--- 전투 종료: 패배 ---")
        if battle_ui: battle_ui.show_battle_result("패배")
        return true
    elif all_enemies_defeated:
        add_battle_log("--- 전투 종료: 승리! ---")
        if battle_ui: battle_ui.show_battle_result("승리!")
        return true

    return false

func _end_battle():
    battle_in_progress = false
    player_input_awaits = false
    current_actor = null
    add_battle_log("전투가 종료되었습니다.")
    # TODO: 전투 결과 창 표시, 보상 처리, 다음 씬으로 이동 등
    # 예: get_tree().change_scene_to_file("res://scenes/world_map.tscn")


# 플레이어 UI에서 행동 선택 시 호출될 함수
func on_player_action_confirmed(caster: BaseCharacter, skill_data: SkillData, selected_targets: Array[BaseCharacter]):
    if not battle_in_progress or not player_input_awaits: return
    if caster != current_actor or not caster.is_player_character:
        printerr("Invalid player action: Not current actor or not a player character.")
        return

    player_input_awaits = false # 입력 처리 시작, 중복 입력 방지
    if battle_ui: battle_ui.disable_player_input() # 입력 UI 비활성화

    # SkillManager는 Autoload로 가정
    var success = SkillManager.execute_skill(caster, selected_targets, skill_data, self)

    # 플레이어 행동 후 다음 턴 진행 (애니메이션 시간 등 고려하여 딜레이)
    # 성공 여부와 관계없이 턴은 넘어감 (실패 시에도 턴 소모)
    await get_tree().create_timer(1.0).timeout
    if not battle_in_progress: return # 딜레이 중 전투 종료 시
    _proceed_to_next_actor()


func _on_character_died(character_node: BaseCharacter):
    add_battle_log("%s(이)가 전투 불능 상태가 되었습니다." % character_node.name)
    # 턴 큐에서 완전히 제거할 필요는 없음. _proceed_to_next_actor에서 is_dead()로 체크.
    # UI 업데이트 (예: 캐릭터 회색 처리)는 BattleUI에서 character_node의 died 시그널을 받아 처리.

    # 사망으로 인해 전투가 종료될 수 있으므로 즉시 체크
    if _check_battle_over_conditions():
        _end_battle()


# 전투 로그 메시지 추가 (UI 연동)
func add_battle_log(message: String):
    print("BattleManager Log: " + message) # 콘솔에도 출력
    if battle_ui:
        battle_ui.add_log_message(message)

# AI 또는 스킬 효과가 타겟을 찾을 때 사용
func get_all_enemy_characters_of(caster: BaseCharacter) -> Array[BaseCharacter]:
    var list_to_filter = enemy_party if caster.is_player_character else player_party
    return list_to_filter.filter(func(c): return not c.is_dead()) # 살아있는 캐릭터만 반환

func get_all_ally_characters_of(caster: BaseCharacter) -> Array[BaseCharacter]:
    var list_to_filter = player_party if caster.is_player_character else enemy_party
    # 자기 자신을 포함할지 여부는 스킬 설계에 따라 다름. 여기서는 포함.
    return list_to_filter.filter(func(c): return not c.is_dead())


# 디버그용: 현재 턴 큐 상태 출력
func print_turn_queue():
    var queue_names = []
    for char_node in turn_queue:
        queue_names.append(char_node.name + ("(Dead)" if char_node.is_dead() else ""))
    print("Current Turn Queue: ", queue_names)

# 외부에서 테스트 전투 시작용 (예: 메인 메뉴에서 버튼 클릭)
func start_test_battle_from_external():
    if not battle_in_progress:
        _start_test_battle()
    else:
        print("Cannot start test battle, another battle is in progress.")

func get_current_actor() -> BaseCharacter:
    return current_actor

func get_player_party() -> Array[BaseCharacter]:
    return player_party

func get_enemy_party() -> Array[BaseCharacter]:
    return enemy_party
