## sect.gd - 宗门实体（Sprite2D 贴图）
extends Node2D

var sect_name: String
var founder: String
var member_count: int = 0
var power: int = 10
var territory_radius: int = 15
var color_index: int = 0
var is_selected: bool = false

var _sprite: Sprite2D

static var _sect_names: Array[String] = [
	"青云宗", "太虚门", "天剑阁", "碧落宫", "万妖岭", "星辰殿",
	"灵霄派", "玄天宗", "紫霄宫", "无极门",
]

static var _sect_colors: Array[Color] = [
	Color.LIGHT_BLUE, Color.LIGHT_GREEN, Color.PALE_VIOLET_RED,
	Color.KHAKI, Color.CORAL, Color.MEDIUM_PURPLE,
]

static var _icons: Array[Texture2D] = []

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)

func setup(p_idx: int, p_pos: Vector2) -> void:
	sect_name = _sect_names[p_idx % _sect_names.size()]
	color_index = p_idx % _sect_colors.size()
	position = p_pos
	
	if not _sprite:
		_sprite = Sprite2D.new()
		_sprite.centered = true
		add_child(_sprite)
	
	if _icons.is_empty():
		for i in 16:
			var path = "res://assets/tiles/sect_%d.png" % i
			var real = path.replace("res://", "")
			if FileAccess.file_exists(real):
				_icons.append(load(path))
			else:
				break
	if color_index < _icons.size():
		_sprite.texture = _icons[color_index]
	queue_redraw()

func _draw() -> void:
	if is_selected:
		draw_circle(Vector2.ZERO, 72, Color.GOLD, false, 2)

func set_selected(s: bool) -> void:
	is_selected = s
	queue_redraw()

func get_display_name() -> String:
	return "%s（%d人）" % [sect_name, member_count]
