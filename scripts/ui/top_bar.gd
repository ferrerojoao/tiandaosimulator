## top_bar.gd - 顶栏：年份、季节、速度、天道机制
extends PanelContainer

@onready var year_label: Label = $HBoxContainer/LabelYear
@onready var season_label: Label = $HBoxContainer/LabelSeason
@onready var speed_label: Label = $HBoxContainer/LabelSpeed
@onready var hm_label: Label = $HBoxContainer/LabelHeavenlyMechanism

func _ready() -> void:
	_update_display()
	GameTime.season_changed.connect(_on_season_changed)
	GameTime.speed_changed.connect(_on_speed_changed)

func _update_display() -> void:
	year_label.text = "第 %d 年" % GameTime.current_year
	season_label.text = "· %s季" % GameTime.get_season_name()
	speed_label.text = "速度: %s" % _speed_name(GameTime.current_speed)
	hm_label.text = "天道: 0"

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
