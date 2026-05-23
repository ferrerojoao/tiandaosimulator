## minimap.gd - 小地图
extends PanelContainer

const MAP_W: int = 200
const MAP_H: int = 200
const VP_W: int = 1920
const VP_H: int = 1080

var _terrain: Array = []
var _sects: Array = []
var _vills: Array = []
var _loaded: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Overlay.draw.connect(_on_draw)

func _process(_delta: float) -> void:
	if _loaded:
		$Overlay.queue_redraw()
		return
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm and wm.terrain_map and wm.terrain_map.size() > 0:
		_terrain = wm.terrain_map.duplicate(true)
		_sects = wm.sect_positions.duplicate()
		_vills = wm.village_positions.duplicate()
		_loaded = true

func _on_draw() -> void:
	if not _loaded: return
	var overlay = $Overlay
	var sx: float = overlay.size.x / MAP_W
	var sy: float = overlay.size.y / MAP_H
	
	var colors: Dictionary = {
		0: Color("#1a3a5c"), 1: Color("#2a6aa6"), 2: Color("#c2b280"),
		3: Color("#4a8c3f"), 4: Color("#3a7d32"), 5: Color("#2d5a27"),
		6: Color("#6b6b6b"), 7: Color("#4a4a4a"), 8: Color("#3d5c3a"),
		9: Color("#9b59b6"), 10: Color("#d4a843"), 11: Color("#8b7355"),
	}
	
	# 地形
	for y in _terrain.size():
		for x in _terrain[y].size():
			overlay.draw_rect(
				Rect2(x * sx, y * sy, sx + 1, sy + 1),
				colors.get(_terrain[y][x], Color.BLACK), true
			)
	
	# 宗门
	for sect in _sects:
		overlay.draw_circle(Vector2(sect.x * sx, sect.y * sy), 2, Color.YELLOW)
	
	# 村落
	for vil in _vills:
		overlay.draw_rect(Rect2(vil.x * sx - 1, vil.y * sy - 1, 2, 2), Color.WHITE, true)
	
	# 圣地
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm and wm.sacred_sites:
		for site in wm.sacred_sites:
			var sp: Vector2i = site["pos"]
			var ec: int = site["element"]
			var colors_arr = [Color.WHITE, Color.GOLD, Color.GREEN, Color.CYAN, Color.ORANGE_RED, Color.SADDLE_BROWN]
			overlay.draw_circle(Vector2(sp.x * sx, sp.y * sy), 3, colors_arr[ec] if ec < colors_arr.size() else Color.WHITE)
	
	# 相机视口框
	var cam = get_node_or_null("/root/main/Camera2D")
	if cam:
		var zoom: float = cam.zoom.x
		var cam_left: float = cam.position.x - VP_W / (2.0 * zoom)
		var cam_top: float = cam.position.y - VP_H / (2.0 * zoom)
		var cam_w: float = VP_W / zoom
		var cam_h: float = VP_H / zoom
		overlay.draw_rect(
			Rect2(cam_left / 32.0 * sx, cam_top / 32.0 * sy,
				  maxf(cam_w / 32.0 * sx, 2), maxf(cam_h / 32.0 * sy, 2)),
			Color.WHITE, false, 1
		)
	
	# 修士
	var realm_colors: Array[Color] = [
		Color.WHITE, Color.LIGHT_BLUE, Color.CYAN,
		Color.YELLOW, Color.ORANGE, Color.RED,
	]
	var spawner = get_node_or_null("/root/main/CultivatorSpawner")
	if spawner:
		for c in spawner.get_children():
			if c.has_method("get_display_name") and c.get("realm") != null:
				var tx: float = c.position.x / 32.0 * sx
				var ty: float = c.position.y / 32.0 * sy
				overlay.draw_rect(Rect2(tx - 1, ty - 1, 2, 2), realm_colors[c.get("realm")], true)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton): return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if not event.pressed: return
	
	var cam = get_node_or_null("/root/main/Camera2D")
	if not cam: return
	
	var local_pos: Vector2 = $Overlay.get_local_mouse_position()
	var sx: float = $Overlay.size.x / MAP_W
	var sy: float = $Overlay.size.y / MAP_H
	if sx <= 0 or sy <= 0: return
	
	# 鼠标在 minimap 上的 tile 位置 → 世界坐标（相机中心）
	var target_x: float = (local_pos.x / sx) * 32.0
	var target_y: float = (local_pos.y / sy) * 32.0
	var zoom: float = cam.zoom.x
	cam.position = Vector2(
		clampf(target_x, VP_W / (2.0 * zoom), 6400.0 - VP_W / (2.0 * zoom)),
		clampf(target_y, VP_H / (2.0 * zoom), 6400.0 - VP_H / (2.0 * zoom))
	)
