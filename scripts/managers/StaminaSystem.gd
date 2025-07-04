extends Node
class_name StaminaSystem

signal stamina_changed(current:int, max:int)

@export var max_power: int = 160
@export var regen_interval_sec: float = 6 * 60.0  # 6분당 1포인트 (예시)

var _current_power: int = max_power
var _last_update_epoch: int = OS.get_unix_time()
var _regen_timer: Timer

func _ready():
    _regen_timer = Timer.new()
    _regen_timer.wait_time = 1.0  # 매초 틱
    _regen_timer.autostart = true
    _regen_timer.one_shot = false
    add_child(_regen_timer)
    _regen_timer.timeout.connect(_process_regen)

func _process_regen():
    var now = OS.get_unix_time()
    var elapsed = now - _last_update_epoch
    if elapsed <= 0:
        return
    var points_to_add = int(elapsed / regen_interval_sec)
    if points_to_add > 0:
        _current_power = clamp(_current_power + points_to_add, 0, max_power)
        _last_update_epoch += int(points_to_add * regen_interval_sec)
        emit_signal("stamina_changed", _current_power, max_power)

func spend(cost: int) -> bool:
    if cost <= 0:
        return true
    if _current_power < cost:
        return false
    _current_power -= cost
    emit_signal("stamina_changed", _current_power, max_power)
    return true

func get_current_power() -> int:
    return _current_power