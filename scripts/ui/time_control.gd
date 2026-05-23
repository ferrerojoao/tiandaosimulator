## time_control.gd - 时间控制面板
extends PanelContainer

@onready var btn_pause: Button = $HBoxContainer/BtnPause
@onready var btn_1x: Button = $HBoxContainer/Btn1x
@onready var btn_2x: Button = $HBoxContainer/Btn2x
@onready var btn_5x: Button = $HBoxContainer/Btn5x
@onready var btn_10x: Button = $HBoxContainer/Btn10x

func _ready() -> void:
	btn_pause.pressed.connect(func(): GameTime.toggle_pause())
	btn_1x.pressed.connect(func(): GameTime.set_speed(GameTime.Speed.NORMAL))
	btn_2x.pressed.connect(func(): GameTime.set_speed(GameTime.Speed.FAST))
	btn_5x.pressed.connect(func(): GameTime.set_speed(GameTime.Speed.ULTRA))
	btn_10x.pressed.connect(func(): GameTime.set_speed(GameTime.Speed.ULTRA2))
