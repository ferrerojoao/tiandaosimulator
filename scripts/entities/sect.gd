## sect.gd - 宗门实体
extends Node2D

var sect_name: String
var founder: String
var member_count: int = 0
var power: int = 10
var territory_radius: int = 15
var color_index: int = 0

static var _sect_names: Array[String] = [
	"青云宗", "太虚门", "天剑阁", "碧落宫", "万妖岭", "星辰殿",
	"灵霄派", "玄天宗", "紫霄宫", "无极门",
]

static var _sect_colors: Array[Color] = [
	Color.LIGHT_BLUE, Color.LIGHT_GREEN, Color.PALE_VIOLET_RED,
	Color.KHAKI, Color.CORAL, Color.MEDIUM_PURPLE,
]

func setup(p_idx: int, p_pos: Vector2) -> void:
	sect_name = _sect_names[p_idx % _sect_names.size()]
	color_index = p_idx % _sect_colors.size()
	position = p_pos
	queue_redraw()

func _draw() -> void:
	var col: Color = _sect_colors[color_index]
	draw_circle(Vector2.ZERO, 14, col, false, 3)
	draw_circle(Vector2.ZERO, 10, col, true)
	draw_rect(Rect2(-3, -1, 6, 2), Color.BLACK, true)
	draw_rect(Rect2(-1, -3, 2, 6), Color.BLACK, true)

func get_display_name() -> String:
	return "%s（%d人）" % [sect_name, member_count]
