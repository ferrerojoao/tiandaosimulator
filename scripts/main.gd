## main.gd - 主场景脚本
extends Node2D

var selected_cultivator: Node2D
var selected_sect: Node2D
var _detail_popup: Control

func _ready() -> void:
	print("[Main] 场景初始化完成")
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.request_cultivator_detail.connect(_on_detail_request)

func _on_detail_request(c: Node2D) -> void:
	_show_detail_popup(c)

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
	
	# 双击修士：已选中同一人 → 弹出详情
	var was_same: bool = selected_cultivator != null and selected_cultivator == best_cult
	_deselect_all()
	_close_detail_popup()
	
	if best_sect:
		_select_sect(best_sect)
	elif best_cult:
		_select_cultivator(best_cult)
		if was_same:
			_show_detail_popup(best_cult)
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

func _show_detail_popup(c: Node2D) -> void:
	_close_detail_popup()
	var ui = get_node_or_null("UI")
	if not ui: return
	
	var panel = PanelContainer.new()
	panel.name = "DetailPopup"
	panel.custom_minimum_size = Vector2(380, 500)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190
	panel.offset_top = -250
	panel.offset_right = 190
	panel.offset_bottom = 250
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	vbox.add_child(_dl_label("▎%s" % c.get("cultivator_name")))
	vbox.add_child(_dl_label("境界: %s" % c.get("REALM_NAMES")[c.get("realm")]))
	var sr_names: Array = c.get("SPIRIT_ROOT_NAMES")
	var e_names: Array = c.get("ELEMENT_NAMES")
	vbox.add_child(_dl_label("灵根: %s(%s)" % [sr_names[c.get("spirit_root")], e_names[c.get("spirit_element")]]))
	vbox.add_child(_dl_label("根骨: %d  悟性: %d  气运: %d" % [c.get("root_bone"), c.get("comprehension"), c.get("fortune")]))
	vbox.add_child(_dl_label("宗门: %s  年龄: %d" % [c.get("sect") if c.get("sect") else "散修", c.get("age")]))
	var ne: float = c.get("EXP_TO_NEXT")[c.get("realm")] if c.get("realm") < c.get("EXP_TO_NEXT").size() else -1
	vbox.add_child(_dl_label("修为: %.0f / %.0f" % [c.get("cultivation_exp"), ne] if ne > 0 else "修为: %.0f (圆满)" % c.get("cultivation_exp")))
	vbox.add_child(_dl_label("战绩: %d胜 %d败" % [c.get("wins"), c.get("losses")]))
	
	vbox.add_child(_dl_label("灵石: %d" % c.get("spirit_stones")))
	var pills: Dictionary = c.get("pills")
	var pl: String = ""
	for k in pills: if pills[k] > 0: pl += "%s×%d " % [k, pills[k]]
	vbox.add_child(_dl_label("丹药: %s" % (pl if pl else "无")))
	
	var specs: Dictionary = c.get("special_items")
	var sl: String = ""
	for k in specs: if specs[k] > 0: sl += "%s×%d " % [k, specs[k]]
	vbox.add_child(_dl_label("特殊: %s" % (sl if sl else "无")))
	
	vbox.add_child(HSeparator.new())
	vbox.add_child(_dl_label("生涯大事:"))
	var events: Array = c.get("life_events")
	var shown: int = mini(20, events.size())
	for i in range(events.size() - shown, events.size()):
		var evt: Dictionary = events[i]
		vbox.add_child(_dl_label("[%d年] %s %s" % [evt["year"], evt["realm"], evt["text"]]))
	
	var btn = Button.new()
	btn.text = "关闭"
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_close_detail_popup)
	vbox.add_child(btn)
	
	ui.add_child(panel)
	_detail_popup = panel

func _dl_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _close_detail_popup() -> void:
	if _detail_popup and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()
		_detail_popup = null
