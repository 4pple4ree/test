extends Node
class_name RemoteConfigManager

signal config_updated(config: Dictionary)

# 원격 설정 파일 URL (서버 배포 시 CDN 주소로 교체)
@export var remote_config_url: String = "https://example.com/game/config.json"

# 설정을 다시 가져올 주기(초). 0이면 한 번만 가져옵니다.
@export var refresh_interval_sec: float = 600.0

var _http_request: HTTPRequest
var _refresh_timer: Timer

var config: Dictionary = {}

func _ready() -> void:
    _http_request = HTTPRequest.new()
    add_child(_http_request)

    _http_request.request_completed.connect(_on_http_request_completed)

    _fetch_remote_config()

    if refresh_interval_sec > 0:
        _refresh_timer = Timer.new()
        _refresh_timer.wait_time = refresh_interval_sec
        _refresh_timer.autostart = true
        _refresh_timer.one_shot = false
        add_child(_refresh_timer)
        _refresh_timer.timeout.connect(_fetch_remote_config)

func _fetch_remote_config() -> void:
    if _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        return  # 이미 요청 중
    var err = _http_request.request(remote_config_url)
    if err != OK:
        push_warning("RemoteConfigManager: Failed to start HTTP request: %s" % err)

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code != 200:
        push_warning("RemoteConfigManager: HTTP %s when fetching remote config" % response_code)
        return

    var body_str := body.get_string_from_utf8()
    var json := JSON.new()
    var parse_err := json.parse(body_str)
    if parse_err != OK:
        push_warning("RemoteConfigManager: JSON parse error %s" % json.get_error_message())
        return

    var new_config = json.get_data() if json.get_data() is Dictionary else {}
    if new_config.is_empty():
        push_warning("RemoteConfigManager: Received empty config dictionary")
        return

    config = new_config
    emit_signal("config_updated", config)