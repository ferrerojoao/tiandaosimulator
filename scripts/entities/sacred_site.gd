## sacred_site.gd - 圣地实体标记
extends Node2D

var element: int = 0
var site_name: String = ""

func setup(p_element: int, p_name: String, p_pos: Vector2) -> void:
	element = p_element
	site_name = p_name
	position = p_pos
	queue_redraw()

func _draw() -> void:
	var colors: Array = [Color.WHITE, Color.GOLD, Color.GREEN, Color.CYAN, Color.ORANGE_RED, Color.SADDLE_BROWN]
	var col: Color = colors[element] if element < colors.size() else Color.WHITE
	# 外层光晕
	draw_circle(Vector2.ZERO, 22, col, false, 2)
	draw_circle(Vector2.ZERO, 18, Color(col.r, col.g, col.b, 0.3), true)
	# 内层核心
	draw_circle(Vector2.ZERO, 8, col, true)
	draw_circle(Vector2.ZERO, 5, Color.WHITE, true)

func get_display_name() -> String:
	return site_name
