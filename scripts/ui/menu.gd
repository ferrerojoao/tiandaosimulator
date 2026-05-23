## menu.gd - 主菜单
extends Control

@onready var btn_new: Button = $VBoxContainer/BtnNew
@onready var btn_load: Button = $VBoxContainer/BtnLoad
@onready var btn_quit: Button = $VBoxContainer/BtnQuit

func _ready() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	btn_load.disabled = not (sm and sm.has_save())
	btn_new.pressed.connect(_on_new)
	btn_load.pressed.connect(_on_load)
	btn_quit.pressed.connect(_on_quit)

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
