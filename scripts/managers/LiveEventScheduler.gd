extends Node
class_name LiveEventScheduler

# RemoteConfigManager가 Autoload로 등록되어 있다고 가정합니다.
@export var remote_config_manager_path: NodePath = "/root/RemoteConfigManager"  # 변경 시 제작자가 설정

var _events: Dictionary = {}  # { event_key: {"start": 1700000000, "end": 1700600000} }

func _ready():
    var rc := get_node_or_null(remote_config_manager_path)
    if rc:
        rc.config_updated.connect(_on_remote_config_updated)
        _initialize_from_config(rc.config)
    else:
        push_warning("LiveEventScheduler: RemoteConfigManager not found at %s" % remote_config_manager_path)

func _on_remote_config_updated(config: Dictionary):
    _initialize_from_config(config)

func _initialize_from_config(config: Dictionary):
    if config.has("events") and config["events"] is Dictionary:
        _events = config["events"]
    else:
        _events.clear()

func is_event_active(event_key: String) -> bool:
    if not _events.has(event_key):
        return false
    var event_dict: Dictionary = _events[event_key]
    if not event_dict.has("start") or not event_dict.has("end"):
        return false
    var now := OS.get_unix_time()
    return now >= int(event_dict["start"]) and now <= int(event_dict["end"])