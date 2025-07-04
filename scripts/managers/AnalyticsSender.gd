extends Node
class_name AnalyticsSender

@export var endpoint_url: String = "https://example.com/analytics/bulk"
@export var batch_size: int = 10
@export var flush_interval_sec: float = 30.0

var _queue: Array[Dictionary] = []
var _http: HTTPRequest
var _timer: Timer

func _ready():
    _http = HTTPRequest.new()
    add_child(_http)
    _http.request_completed.connect(_on_request_completed)

    _timer = Timer.new()
    _timer.wait_time = flush_interval_sec
    _timer.autostart = true
    _timer.one_shot = false
    add_child(_timer)
    _timer.timeout.connect(flush)

func queue_event(event_name: String, payload: Dictionary = {}):
    var evt = {
        "name": event_name,
        "payload": payload,
        "ts": OS.get_unix_time()
    }
    _queue.append(evt)
    if _queue.size() >= batch_size:
        flush()

func flush():
    if _queue.is_empty():
        return
    if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        return  # 요청 진행 중
    var body = JSON.stringify(_queue)
    var headers = ["Content-Type: application/json"]
    var err = _http.request(endpoint_url, headers, HTTPClient.METHOD_POST, body)
    if err != OK:
        push_warning("AnalyticsSender: HTTP request failed to start (%s)" % err)
    # 전송 성공/실패는 완료 콜백에서 다룸

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
    if response_code == 200:
        _queue.clear()
    else:
        push_warning("AnalyticsSender: server responded %s. Keeping events in queue." % response_code)