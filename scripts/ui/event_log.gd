## event_log.gd - 事件日志面板
extends PanelContainer

@onready var entries: VBoxContainer = $VBoxContainer/Scroll/EntriesVBox
@onready var btn_toggle: Button = $VBoxContainer/HeaderBar/BtnToggle

func _ready() -> void:
	# 暗色主题
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.12, 0.88)
	sb.border_width_left = 1; sb.border_width_top = 1
	sb.border_color = Color(0.78, 0.63, 0.31, 0.4)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)
	btn_toggle.pressed.connect(_toggle)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.event_log_entry.connect(_add_entry)

func _add_entry(text: String, category: String) -> void:
	var label = Label.new()
	label.text = "[%s] %s" % [category, text]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(250, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	entries.add_child(label)
	if entries.get_child_count() > 50:
		entries.get_child(0).queue_free()

func _toggle() -> void:
	$VBoxContainer/Scroll.visible = not $VBoxContainer/Scroll.visible
	btn_toggle.text = "展开" if not $VBoxContainer/Scroll.visible else "收起"
