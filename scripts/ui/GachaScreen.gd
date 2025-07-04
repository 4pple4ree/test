extends Panel
class_name GachaScreen

signal pull_completed(results: Array)

@export var remote_config_manager_path: NodePath = "/root/RemoteConfigManager"

@onready var banner_list: ItemList = $BannerList
@onready var animation_rect: TextureRect = $Animation/Texture
@onready var single_pull_button: Button = $Controls/SinglePullButton
@onready var ten_pull_button: Button = $Controls/TenPullButton
@onready var result_container: VBoxContainer = $ResultPanel
@onready var result_label: RichTextLabel = $ResultPanel/ResultLabel
@onready var close_button: Button = $CloseButton

var _banners: Array = []  # Each banner Dictionary: {id:int, name:String, pool:Array}
var _selected_banner_index: int = 0

func _ready():
    single_pull_button.pressed.connect(_on_single_pull)
    ten_pull_button.pressed.connect(_on_ten_pull)
    close_button.pressed.connect(_on_close)
    banner_list.item_selected.connect(_on_banner_selected)

    var rc := get_node_or_null(remote_config_manager_path)
    if rc:
        rc.config_updated.connect(_on_config_updated)
        _on_config_updated(rc.config)
    else:
        _refresh_banner_list()

func _on_config_updated(config: Dictionary):
    if config.has("gacha_banners") and config["gacha_banners"] is Array:
        _banners = config["gacha_banners"]
    _refresh_banner_list()

func _refresh_banner_list():
    banner_list.clear()
    for banner in _banners:
        var name = banner.get("name", "Banner")
        banner_list.add_item(name)
    if banner_list.get_item_count() > 0:
        banner_list.select(0)
        _selected_banner_index = 0

func _on_banner_selected(index:int):
    _selected_banner_index = index

func _on_single_pull():
    _perform_pull(1)

func _on_ten_pull():
    _perform_pull(10)

func _perform_pull(count:int):
    if _selected_banner_index < 0 or _selected_banner_index >= _banners.size():
        return
    var banner = _banners[_selected_banner_index]
    var pool: Array = banner.get("pool", [])
    if pool.is_empty():
        result_label.text = "No items in pool!"
        result_container.visible = true
        return
    var results: Array = []
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    for i in range(count):
        var item = pool[rng.randi_range(0, pool.size() - 1)]
        results.append(item)
    _show_results(results)
    emit_signal("pull_completed", results)

func _show_results(results:Array):
    var text := "[b]Pull Results:[/b]\n"
    for item in results:
        text += "• %s\n" % str(item)
    result_label.text = text
    result_container.visible = true
    # Simple placeholder animation flash
    animation_rect.modulate = Color(1,1,1)
    var tween := create_tween()
    tween.tween_property(animation_rect, "modulate", Color(1,1,1,0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_close():
    visible = false