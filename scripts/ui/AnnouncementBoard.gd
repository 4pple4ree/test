extends Panel

@export var remote_config_manager_path: NodePath = "/root/RemoteConfigManager"

@onready var rich_text: RichTextLabel = $Scroll/Text
@onready var close_button: Button = $CloseButton

func _ready() -> void:
    close_button.pressed.connect(_on_close_pressed)
    var rc = get_node_or_null(remote_config_manager_path)
    if rc:
        rc.config_updated.connect(_on_config_updated)
        _on_config_updated(rc.config)

func _on_config_updated(config: Dictionary):
    var news_text := ""
    if config.has("news"):
        var news_data = config["news"]
        if news_data is Array:
            for item in news_data:
                if item is Dictionary and item.has("title") and item.has("body"):
                    news_text += "[b]%s[/b]\n%s\n\n" % [str(item["title"]), str(item["body"])]
                else:
                    news_text += "%s\n" % str(item)
        elif typeof(news_data) == TYPE_STRING:
            news_text = str(news_data)
    rich_text.clear()
    rich_text.append_text(news_text)

func _on_close_pressed():
    visible = false