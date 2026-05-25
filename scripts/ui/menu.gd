## menu.gd - 主菜单
extends Control

@onready var btn_new: Button = $VBoxContainer/BtnNew
@onready var btn_load: Button = $VBoxContainer/BtnLoad
@onready var btn_quit: Button = $VBoxContainer/BtnQuit
@onready var title: Label = $VBoxContainer/Title

func _ready() -> void:
	# 背景图
	var bg = TextureRect.new()
	bg.texture = load("res://assets/menu_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	add_child(bg); move_child(bg, 0)
	# 减少暗色遮罩透明度让背景透出
	$ColorRect.color = Color(0.04, 0.06, 0.12, 0.55)
	
	# 标题样式
	title.add_theme_color_override("font_color", Color(0.9, 0.82, 0.4))
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_font_override("font", null)
	
	# 按钮样式
	_style_btn(btn_new, "新游戏")
	_style_btn(btn_load, "读档")
	_style_btn(btn_quit, "退出游戏")
	
	var sm = get_node_or_null("/root/SaveManager")
	btn_load.disabled = not (sm and sm.has_save())
	if btn_load.disabled:
		btn_load.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	btn_new.pressed.connect(_on_new)
	btn_load.pressed.connect(_on_load)
	btn_quit.pressed.connect(_on_quit)

func _style_btn(btn: Button, _text: String) -> void:
	btn.custom_minimum_size = Vector2(380, 64)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.6))
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.18, 0.85)
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.63, 0.31, 0.5)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.15, 0.12, 0.25, 0.9)
	sb_hover.border_color = Color(1.0, 0.85, 0.45, 0.7)
	btn.add_theme_stylebox_override("hover", sb_hover)

func _on_new() -> void:
	hide()
	var main = get_node("/root/main")
	main.start_new_game()

func _on_load() -> void:
	hide()
	var main = get_node("/root/main")
	main.load_game()

func _on_quit() -> void:
	get_tree().quit()
