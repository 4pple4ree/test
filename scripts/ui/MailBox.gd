extends Panel
class_name MailBox

@export var remote_config_manager_path: NodePath = "/root/RemoteConfigManager"

@onready var item_list: ItemList = $MailList
@onready var content_label: RichTextLabel = $Preview/ContentLabel
@onready var reward_label: Label = $Preview/RewardLabel
@onready var claim_button: Button = $Preview/ClaimButton
@onready var close_button: Button = $CloseButton

var _mails: Array = []  # Each: {id:int,title:String,body:String,reward:String,claimed:bool}
var _selected_index: int = -1

func _ready() -> void:
    claim_button.pressed.connect(_on_claim_pressed)
    close_button.pressed.connect(_on_close_pressed)
    item_list.item_selected.connect(_on_item_selected)

    var rc = get_node_or_null(remote_config_manager_path)
    if rc:
        rc.config_updated.connect(_on_config_updated)
        _on_config_updated(rc.config)
    else:
        _refresh_ui()

func _on_config_updated(config: Dictionary):
    if config.has("mails") and config["mails"] is Array:
        _mails = config["mails"]
    _refresh_ui()

func _refresh_ui():
    item_list.clear()
    for mail in _mails:
        var title = mail.get("title", "(No title)")
        var claimed = mail.get("claimed", false)
        var display_title = title + (" [CLAIMED]" if claimed else "")
        item_list.add_item(display_title)
    _selected_index = -1
    _update_preview()

func _on_item_selected(index:int):
    _selected_index = index
    _update_preview()

func _update_preview():
    if _selected_index < 0 or _selected_index >= _mails.size():
        content_label.text = "Select a mail to view."
        reward_label.text = ""
        claim_button.disabled = true
        return
    var mail = _mails[_selected_index]
    content_label.text = mail.get("body", "")
    reward_label.text = "Reward: " + mail.get("reward", "None")
    var claimed = mail.get("claimed", false)
    claim_button.disabled = claimed
    claim_button.text = "Claimed" if claimed else "Claim"

func _on_claim_pressed():
    if _selected_index < 0 or _selected_index >= _mails.size():
        return
    var mail = _mails[_selected_index]
    if mail.get("claimed", false):
        return
    # TODO: send HTTP request to /mail/claim/{id}. Here we simulate success immediately.
    mail["claimed"] = true
    _mails[_selected_index] = mail
    _refresh_ui()

func _on_close_pressed():
    visible = false