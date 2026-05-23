## main.gd - 主场景脚本
extends Node2D

var selected_cultivator: Node2D
var selected_sect: Node2D

func _ready() -> void:
	print("[Main] 场景初始化完成")

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton): return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if not event.pressed: return
	
	var cam = $Camera2D
	if not cam: return
	
	var world_pos: Vector2 = cam.get_screen_center_position() + (event.position - get_viewport().get_visible_rect().size / 2.0) / cam.zoom
	
	_deselect_all()
	
	var spawner = $CultivatorSpawner
	if not spawner: return
	
	# 先检测宗门（半径更大，优先）
	var best_sect: Node2D
	var best_sect_dist: float = 40.0
	# 再检测修士
	var best_cult: Node2D
	var best_cult_dist: float = 32.0
	
	for node in spawner.get_children():
		if not node.has_method("get_display_name"): continue
		var d: float = world_pos.distance_to(node.position)
		if node.get("sect_name") != null:
			if d < best_sect_dist:
				best_sect_dist = d
				best_sect = node
		else:
			if d < best_cult_dist:
				best_cult_dist = d
				best_cult = node
	
	if best_sect:
		_select_sect(best_sect)
	elif best_cult:
		_select_cultivator(best_cult)

func _select_cultivator(c: Node2D) -> void:
	selected_cultivator = c
	if c.has_method("set_selected"):
		c.set_selected(true)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.cultivator_selected.emit(c)

func _select_sect(s: Node2D) -> void:
	selected_sect = s
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.sect_selected.emit(s)

func _deselect_all() -> void:
	if selected_cultivator and is_instance_valid(selected_cultivator):
		if selected_cultivator.has_method("set_selected"):
			selected_cultivator.set_selected(false)
	selected_cultivator = null
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.cultivator_selected.emit(null)
	selected_sect = null
	if eb:
		eb.sect_selected.emit(null)
