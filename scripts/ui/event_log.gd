## event_log.gd - 事件日志面板
extends PanelContainer

@onready var entries: VBoxContainer = $VBoxContainer/Scroll/EntriesVBox
@onready var btn_toggle: Button = $VBoxContainer/HeaderBar/BtnToggle

func _ready() -> void:
	btn_toggle.pressed.connect(_toggle)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.event_log_entry.connect(_add_entry)

func _add_entry(text: String, category: String) -> void:
	var label = Label.new()
	label.text = "[%s] %s" % [category, text]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(250, 0)
	entries.add_child(label)
	if entries.get_child_count() > 50:
		entries.get_child(0).queue_free()

func _toggle() -> void:
	$VBoxContainer/Scroll.visible = not $VBoxContainer/Scroll.visible
	btn_toggle.text = "展开" if not $VBoxContainer/Scroll.visible else "收起"
