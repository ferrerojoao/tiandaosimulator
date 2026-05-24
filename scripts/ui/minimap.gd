## minimap.gd - 小地图
extends PanelContainer

const MAP_W: int = 400
const MAP_H: int = 400
const VP_W: int = 1920
const VP_H: int = 1080

var _terrain: Array = []
var _sects: Array = []
var _vills: Array = []
var _loaded: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	self_modulate = Color(1, 1, 1, 0.15)
	$Overlay.draw.connect(_on_draw)
	# 移除标题
	var title = get_node_or_null("LblTitle")
	if title: title.queue_free()

func reload_data() -> void:
	var wm = get_node_or_null("/root/main/WorldMap")
	if not wm or not wm.terrain_map or wm.terrain_map.size() == 0: return
	_terrain = wm.terrain_map.duplicate(true)
	_sects = wm.sect_positions.duplicate()
	_vills = wm.village_positions.duplicate()
	_loaded = true
	await get_tree().process_frame
	$Overlay.queue_redraw()

func _process(_delta: float) -> void:
	# 首次加载：等世界生成后自动抓数据
	if _loaded: return
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm and wm.terrain_map and wm.terrain_map.size() > 0:
		_terrain = wm.terrain_map.duplicate(true)
		_sects = wm.sect_positions.duplicate()
		_vills = wm.village_positions.duplicate()
		_loaded = true
		$Overlay.queue_redraw()

func _on_draw() -> void:
	if not _loaded: return
	var overlay = $Overlay
	if overlay.size.x <= 0: return
	var sx: float = float(overlay.size.x) / MAP_W
	var sy: float = float(overlay.size.y) / MAP_H
	
	var colors: Dictionary = {
		0: Color("#1a3a5c"), 1: Color("#2a6aa6"), 2: Color("#c2b280"),
		3: Color("#4a8c3f"), 4: Color("#3a7d32"), 5: Color("#2d5a27"),
		6: Color("#6b6b6b"), 7: Color("#4a4a4a"), 8: Color("#3d5c3a"),
		9: Color("#9b59b6"), 10: Color("#d4a843"), 11: Color("#8b7355"),
	}
	
	for y in _terrain.size():
		var row = _terrain[y]
		for x in row.size():
			overlay.draw_rect(
				Rect2(x * sx, y * sy, sx + 1, sy + 1),
				colors.get(int(row[x]), Color.BLACK), true
			)
	
	for sect in _sects:
		overlay.draw_circle(Vector2(sect.x * sx, sect.y * sy), 2, Color.YELLOW)
	
	for vil in _vills:
		overlay.draw_rect(Rect2(vil.x * sx - 1, vil.y * sy - 1, 2, 2), Color.WHITE, true)
	
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm and wm.sacred_sites:
		var sac_cols = [Color.WHITE, Color.GOLD, Color.GREEN, Color.CYAN, Color.ORANGE_RED, Color.SADDLE_BROWN]
		for site in wm.sacred_sites:
			var sp = site["pos"]
			var ec: int = site["element"]
			overlay.draw_circle(Vector2(sp.x * sx, sp.y * sy), 3, sac_cols[ec] if ec < sac_cols.size() else Color.WHITE)

func _gui_input(_event: InputEvent) -> void:
	pass
