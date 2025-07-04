extends Node
class_name LocalizationManager

signal language_changed(new_locale: String)

@export var remote_translation_url: String = "https://example.com/game/lang/en.json"
@export var default_locale: String = "en"

var _translations: Dictionary = {}
var _current_locale: String = default_locale
var _http: HTTPRequest

func _ready():
    _http = HTTPRequest.new()
    add_child(_http)
    _http.request_completed.connect(_on_http_completed)
    load_locale(_current_locale)

func load_locale(locale_code: String):
    if locale_code == _current_locale and TranslationServer.get_locale() == locale_code:
        return
    var url = remote_translation_url.replace("en", locale_code)
    var err = _http.request(url)
    if err != OK:
        push_warning("LocalizationManager: failed to request %s, err=%s" % [url, err])

func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
    if response_code != 200:
        push_warning("LocalizationManager: HTTP %s" % response_code)
        return
    var json = JSON.parse_string(body.get_string_from_utf8())
    if typeof(json) != TYPE_DICTIONARY:
        push_warning("LocalizationManager: invalid translation JSON")
        return
    var translation := Translation.new()
    for key in json.keys():
        translation.add_message(key, json[key])
    TranslationServer.clear()
    TranslationServer.add_translation(translation)
    _current_locale = translation.get_locale() if translation.get_locale() != "" else _current_locale
    TranslationServer.set_locale(_current_locale)
    emit_signal("language_changed", _current_locale)