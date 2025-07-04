extends Node
class_name SupportCharacterSystem

# In singleplayer, this system spawns a predefined support character from local resources

@export var support_character_data_path: String = "res://resources/characters/support_npc.tres"
@export var battle_manager_path: NodePath

func spawn_support_character():
    if battle_manager_path == NodePath(""):
        push_warning("SupportCharacterSystem: battle_manager_path is not set")
        return null
    var bm := get_node_or_null(battle_manager_path) as BattleManager
    if not bm:
        push_warning("SupportCharacterSystem: BattleManager not found at %s" % battle_manager_path)
        return null
    var char_data = load(support_character_data_path)
    if not char_data:
        push_warning("SupportCharacterSystem: failed to load %s" % support_character_data_path)
        return null
    # Use BattleManager's internal method to create character instance on player's side.
    var spawn_pos = Vector2.ZERO
    if bm.player_spawns_root and bm.player_spawns_root.get_child_count() > 0:
        spawn_pos = (bm.player_spawns_root.get_child(0) as Node2D).global_position
    var char_instance = bm._create_character_instance(char_data, true, spawn_pos)
    bm.player_party.append(char_instance)
    bm.turn_queue.append(char_instance)
    bm.add_battle_log("지원 캐릭터 %s 합류!" % char_instance.name)
    return char_instance