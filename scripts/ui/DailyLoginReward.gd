extends Panel
class_name DailyLoginReward

signal reward_claimed(day:int, reward_desc:String)

@export var remote_config_manager_path: NodePath = "/root/RemoteConfigManager"

@onready var reward_label: Label = $RewardLabel
@onready var claim_button: Button = $ClaimButton
@onready var close_button: Button = $CloseButton

const SAVE_PATH := "user://daily_login_reward.cfg"
const CONFIG_SECTION := "daily_reward"
const KEY_LAST_CLAIM_DATE := "last_claim_date"

var _rewards: Array = []  # Loaded from RemoteConfigManager.config["daily_login_rewards"]
var _current_day_index:int = 0
var _claim_available: bool = false

func _ready():
    claim_button.pressed.connect(_on_claim_pressed)
    close_button.pressed.connect(_on_close_pressed)

    var rc = get_node_or_null(remote_config_manager_path)
    if rc:
        rc.config_updated.connect(_on_config_updated)
        _on_config_updated(rc.config)
    else:
        _update_ui()

func _on_config_updated(config: Dictionary):
    if config.has("daily_login_rewards") and config["daily_login_rewards"] is Array:
        _rewards = config["daily_login_rewards"]
    _update_ui()

func _load_last_claim_date() -> String:
    var cfg := ConfigFile.new()
    var err = cfg.load(SAVE_PATH)
    if err == OK:
        return cfg.get_value(CONFIG_SECTION, KEY_LAST_CLAIM_DATE, "")
    return ""

func _save_last_claim_date(date_str:String):
    var cfg := ConfigFile.new()
    cfg.set_value(CONFIG_SECTION, KEY_LAST_CLAIM_DATE, date_str)
    var err = cfg.save(SAVE_PATH)
    if err != OK:
        push_warning("DailyLoginReward: Failed to save claim date, err=%s" % err)

func _today_string() -> String:
    var date = Time.get_date_string_from_unix_time(OS.get_unix_time())
    return date  # yyyy-mm-dd

func _update_ui():
    var last_claim_date = _load_last_claim_date()
    _claim_available = last_claim_date != _today_string()

    if _claim_available:
        # Determine reward description for today
        if _rewards.is_empty():
            reward_label.text = "Reward available! (table missing)"
        else:
            _current_day_index = (int(Time.get_unix_time_from_datetime_string(_today_string())) / 86400) % _rewards.size()
            var reward = _rewards[_current_day_index]
            var desc := reward.get("desc", str(reward))
            reward_label.text = "Today\'s reward: " + desc
    else:
        reward_label.text = "Already claimed today's reward. Come back tomorrow!"
    claim_button.disabled = not _claim_available

func _on_claim_pressed():
    if not _claim_available:
        return
    _save_last_claim_date(_today_string())
    _claim_available = false
    claim_button.disabled = true

    var reward_desc = ""
    if not _rewards.is_empty():
        var reward = _rewards[_current_day_index]
        reward_desc = reward.get("desc", str(reward))
    reward_label.text = "Claimed: " + reward_desc
    emit_signal("reward_claimed", _current_day_index + 1, reward_desc)

func _on_close_pressed():
    visible = false