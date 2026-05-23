## main.gd - 主场景脚本
extends Node2D

var selected_cultivator: Node2D
var selected_sect: Node2D

func _ready() -> void:
	print("[Main] 场景初始化完成")

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton): return
	if not event.pressed: return
	
	var cam = $Camera2D
	if not cam: return
	
	var world_pos: Vector2 = cam.get_screen_center_position() + (event.position - get_viewport().get_visible_rect().size / 2.0) / cam.zoom
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		_left_click(world_pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_right_click(world_pos, event.position)

func _left_click(world_pos: Vector2) -> void:
	_deselect_all()
	var spawner = $CultivatorSpawner
	if not spawner: return
	
	var best_sect: Node2D
	var best_sect_dist: float = 40.0
	var best_cult: Node2D
	var best_cult_dist: float = 32.0
	
	for node in spawner.get_children():
		if not node.has_method("get_display_name"): continue
		var d: float = world_pos.distance_to(node.position)
		if node.get("sect_name") != null or node.get("site_name") != null:
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
	else:
		# 点到空地：显示灵气信息
		var tx: int = int(world_pos.x / 32.0)
		var ty: int = int(world_pos.y / 32.0)
		var eb2 = get_node_or_null("/root/EventBus")
		if eb2:
			eb2.tile_selected.emit(tx, ty)

func _right_click(world_pos: Vector2, screen_pos: Vector2) -> void:
	var spawner = $CultivatorSpawner
	if not spawner: return
	for node in spawner.get_children():
		if node.get("sect_name") != null: continue
		if not node.has_method("get_display_name"): continue
		if world_pos.distance_to(node.position) > 32.0: continue
		_show_heavenly_menu(node, screen_pos)
		return

func _show_heavenly_menu(c: Node2D, pos: Vector2) -> void:
	var old = get_node_or_null("HeavenlyMenu")
	if old: old.queue_free()
	var menu = PopupMenu.new()
	menu.name = "HeavenlyMenu"
	menu.add_item("🙏 祝福 (20天道)", 0)
	menu.add_item("🩸 诅咒 (10天道)", 1)
	menu.position = pos + Vector2(10, 10)
	menu.id_pressed.connect(_on_heavenly_action.bind(c))
	add_child(menu)
	menu.popup()

func _on_heavenly_action(id: int, c: Node2D) -> void:
	var gt = get_node_or_null("/root/GameTime")
	var eb = get_node_or_null("/root/EventBus")
	match id:
		0:
			if gt and gt.spend_hm(20):
				c.call("bless", 30)
				if eb: eb.event_log_entry.emit("%s 获得天道祝福" % c.get("cultivator_name"), "hm")
			elif eb:
				eb.event_log_entry.emit("天道值不足 (需要 20)", "hm")
		1:
			if gt and gt.spend_hm(10):
				c.call("curse", 20)
				if eb: eb.event_log_entry.emit("%s 被天道诅咒" % c.get("cultivator_name"), "hm")
			elif eb:
				eb.event_log_entry.emit("天道值不足 (需要 10)", "hm")

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
