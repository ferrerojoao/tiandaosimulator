## sacred_site.gd - 圣地实体标记（Sprite2D 贴图）
extends Node2D

var element: int = 0
var site_name: String = ""
var is_selected: bool = false

var _sprite: Sprite2D

static var _icons: Array[Texture2D] = []
# 元素 → 图标编号映射：无/金/木/水/火/土 对应 sacred_几
static var ELEMENT_ICON_MAP: Array[int] = [11, 0, 1, 2, 3, 4]

func setup(p_element: int, p_name: String, p_pos: Vector2) -> void:
	element = p_element
	site_name = p_name
	position = p_pos
	
	if not _sprite:
		_sprite = Sprite2D.new()
		_sprite.centered = true
		add_child(_sprite)
	
	if _icons.is_empty():
		for i in 16:
			var path = "res://assets/tiles/sacred_%d.png" % i
			if ResourceLoader.exists(path):
				_icons.append(load(path))
	var icon_idx: int = ELEMENT_ICON_MAP[element] if element < ELEMENT_ICON_MAP.size() else element
	if icon_idx < _icons.size():
		_sprite.texture = _icons[icon_idx]
	queue_redraw()

func _draw() -> void:
	if is_selected:
		draw_circle(Vector2.ZERO, 72, Color.GOLD, false, 2)

func set_selected(s: bool) -> void:
	is_selected = s
	queue_redraw()

func get_display_name() -> String:
	return site_name
