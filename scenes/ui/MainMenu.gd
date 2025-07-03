# MainMenu.gd
extends Control

# --- 노드 참조 (씬 트리 구조에 맞게 @onready var로 설정) ---
# VBoxContainer 경로가 루트 노드의 직접 자식이라고 가정
# 실제 씬 구조에 따라 $VBoxContainer/StartButton 등을 사용해야 함
@onready var start_button: Button = get_node_or_null("VBoxContainer/StartButton")
@onready var settings_button: Button = get_node_or_null("VBoxContainer/SettingsButton")
@onready var quit_button: Button = get_node_or_null("VBoxContainer/QuitButton")

# TitleLabel도 필요하다면 참조 추가
# @onready var title_label: Label = get_node_or_null("VBoxContainer/TitleLabel")

func _ready():
    # 버튼 시그널 연결
    if is_instance_valid(start_button):
        # 중복 연결 방지를 위해 연결 전에 이전 연결 해제 시도 또는 is_connected 확인
        if start_button.pressed.is_connected(Callable(self, "_on_start_button_pressed")):
            start_button.pressed.disconnect(Callable(self, "_on_start_button_pressed"))
        start_button.pressed.connect(Callable(self, "_on_start_button_pressed"))
    else:
        printerr("MainMenu: StartButton not found! Check scene path in script.")

    if is_instance_valid(settings_button):
        settings_button.disabled = true # 초기에는 설정 기능 미구현으로 비활성화
        if settings_button.pressed.is_connected(Callable(self, "_on_settings_button_pressed")):
            settings_button.pressed.disconnect(Callable(self, "_on_settings_button_pressed"))
        settings_button.pressed.connect(Callable(self, "_on_settings_button_pressed"))
    else:
        printerr("MainMenu: SettingsButton not found! Check scene path in script.")

    if is_instance_valid(quit_button):
        if quit_button.pressed.is_connected(Callable(self, "_on_quit_button_pressed")):
            quit_button.pressed.disconnect(Callable(self, "_on_quit_button_pressed"))
        quit_button.pressed.connect(Callable(self, "_on_quit_button_pressed"))
    else:
        printerr("MainMenu: QuitButton not found! Check scene path in script.")

func _on_start_button_pressed():
    print("MainMenu: StartButton pressed. Changing scene to Battle Scene...")

    # GameManager Autoload 인스턴스에 접근
    if GameManager: # Autoload 되었는지 확인 (안전장치)
        # 테스트를 위해 바로 전투 씬으로 (GameManager에 다음 전투 정보 설정 후)
        # 실제로는 캐릭터 선택, 난이도 선택 등을 거쳐 정보가 설정될 수 있음
        var default_enemy_group = "test_enemy_group_01" # 예시 적 그룹 ID
        var default_map_path = "res://resources/maps/map_data_example.tres" # 예시 맵 데이터 경로

        GameManager.set_next_battle_info(default_enemy_group, default_map_path)
        GameManager.change_scene_to_path(GameManager.BATTLE_SCENE)
    else:
        printerr("MainMenu: GameManager Autoload not found!")


func _on_settings_button_pressed():
    print("MainMenu: SettingsButton pressed. (Not implemented yet)")
    # 설정 화면으로 전환하는 로직 (추후 구현)
    # if GameManager: GameManager.change_scene_to_path(GameManager.SETTINGS_SCENE) # 예시


func _on_quit_button_pressed():
    print("MainMenu: QuitButton pressed. Quitting game...")
    if GameManager: GameManager.quit_game()

```
