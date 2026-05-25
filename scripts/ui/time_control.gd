## time_control.gd - 时间控制面板
extends PanelContainer

@onready var btn_pause: Button = $HBoxContainer/BtnPause
@onready var btn_1x: Button = $HBoxContainer/Btn1x
@onready var btn_2x: Button = $HBoxContainer/Btn2x
@onready var btn_5x: Button = $HBoxContainer/Btn5x
@onready var btn_10x: Button = $HBoxContainer/Btn10x

func _ready() -> void:
	btn_pause.pressed.connect(func(): _try_speed(GameTime.Speed.PAUSE, true))
	btn_1x.pressed.connect(func(): _try_speed(GameTime.Speed.NORMAL))
	btn_2x.pressed.connect(func(): _try_speed(GameTime.Speed.FAST))
	btn_5x.pressed.connect(func(): _try_speed(GameTime.Speed.ULTRA))
	btn_10x.pressed.connect(func(): _try_speed(GameTime.Speed.ULTRA2))

func _try_speed(speed: int, is_pause: bool = false) -> void:
	var tm = get_node_or_null("/root/main/TribulationManager")
	if tm and tm.active: return  # 雷劫中不许改速
	if is_pause:
		GameTime.toggle_pause()
	else:
		GameTime.set_speed(speed)
