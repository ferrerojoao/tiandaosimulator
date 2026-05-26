## top_bar.gd - 顶栏：年份、季节、速度、天道机制
extends PanelContainer

@onready var year_label: Label = $HBoxContainer/LabelYear
@onready var season_label: Label = $HBoxContainer/LabelSeason
@onready var speed_label: Label = $HBoxContainer/LabelSpeed
@onready var hm_label: Label = $HBoxContainer/LabelHeavenlyMechanism

func _ready() -> void:
	# 暗色顶栏
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.12, 0.92)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)
	year_label.add_theme_color_override("font_color", Color(0.78, 0.63, 0.31))
	year_label.add_theme_font_size_override("font_size", 20)
	season_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	season_label.add_theme_font_size_override("font_size", 16)
	speed_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	speed_label.add_theme_font_size_override("font_size", 16)
	hm_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	hm_label.add_theme_font_size_override("font_size", 16)
	
	# 存档/读档按钮
	var btn_save = Button.new(); btn_save.text = "存档"
	var btn_load = Button.new(); btn_load.text = "读档"
	_style_btn(btn_save); _style_btn(btn_load)
	btn_save.pressed.connect(func(): _do_save())
	btn_load.pressed.connect(func(): _do_load())
	$HBoxContainer.add_child(btn_save)
	$HBoxContainer.add_child(btn_load)
	
	# 静音按钮
	var btn_mute = Button.new()
	_style_btn(btn_mute)
	update_mute_btn(btn_mute)
	btn_mute.pressed.connect(func():
		var am = get_node_or_null("/root/AudioManager")
		if am:
			var muted: bool = am.toggle_mute()
			update_mute_btn(btn_mute, muted)
	)
	$HBoxContainer.add_child(btn_mute)
	
	_update_display()
	GameTime.season_changed.connect(_on_season_changed)
	GameTime.speed_changed.connect(_on_speed_changed)
	GameTime.hm_changed.connect(_on_hm_changed)

func _update_display() -> void:
	year_label.text = "第 %d 年" % GameTime.current_year
	season_label.text = "· %s季" % GameTime.get_season_name()
	speed_label.text = "速度: %s" % _speed_name(GameTime.current_speed)
	hm_label.text = "天道: %d" % GameTime.heavenly_mechanism

func _on_hm_changed(_val: int) -> void:
	hm_label.text = "天道: %d" % _val

func _on_season_changed(_year: int, _season: int, _name: String) -> void:
	_update_display()

func _on_speed_changed(_speed: int) -> void:
	_update_display()

func _speed_name(s: int) -> String:
	match s:
		GameTime.Speed.PAUSE: return "暂停"
		GameTime.Speed.NORMAL: return "1x"
		GameTime.Speed.FAST: return "2x"
		GameTime.Speed.ULTRA: return "5x"
		GameTime.Speed.ULTRA2: return "10x"
	return "??"

func _style_btn(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(48, 28)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.45))
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.18, 0.7)
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.63, 0.31, 0.4)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8; sb.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", sb)

func _do_save() -> void:
	var main = get_node_or_null("/root/main")
	if main and main.has_method("save_game"):
		main.save_game()

func _do_load() -> void:
	var main = get_node_or_null("/root/main")
	if main and main.has_method("load_game"):
		main.load_game()

func update_mute_btn(btn: Button, muted: bool = false) -> void:
	btn.text = "静音" if not muted else "播放"
