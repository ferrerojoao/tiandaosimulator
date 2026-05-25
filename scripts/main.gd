## main.gd - 主场景脚本
extends Node2D

var selected_cultivator: Node2D
var selected_sect: Node2D
var _detail_popup: Control

func _ready() -> void:
	print("[Main] 场景初始化完成")
	# 雷劫管理器
	var tm = load("res://scripts/world/tribulation_manager.gd").new()
	tm.name = "TribulationManager"
	add_child(tm)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.request_cultivator_detail.connect(_on_detail_request)

func _on_detail_request(c: Node2D) -> void:
	_show_detail_popup(c)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		var gt = get_node_or_null("/root/GameTime")
		if gt: gt.toggle_pause()
		get_viewport().set_input_as_handled()
	if not (event is InputEventMouseButton): return
	if not event.pressed: return
	var cam = $Camera2D
	if not cam: return
	var world_pos: Vector2 = cam.get_screen_center_position() + (event.position - get_viewport().get_visible_rect().size / 2.0) / cam.zoom
	if event.button_index == MOUSE_BUTTON_LEFT:
		_left_click(world_pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_right_click(world_pos, event.position)

func start_new_game() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_bgm("游戏音乐.ogg")
	$UI/Menu.hide()
	$WorldMap.generate_world()
	$CultivatorSpawner.spawn_all()
	print("[Main] 新游戏就绪")

func load_game() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_bgm("游戏音乐.ogg")
	var sm = get_node_or_null("/root/SaveManager")
	if not sm: return
	var data: Dictionary = sm.load_game()
	if data.is_empty(): return
	$UI/Menu.hide()
	
	var gt = get_node_or_null("/root/GameTime")
	if gt:
		var t: Dictionary = data["time"]
		gt.current_year = t["year"]
		gt.current_season = t["season"]
		gt.current_speed = t["speed"]
		gt.heavenly_mechanism = t["hm"]
		gt.season_changed.emit(gt.current_year, gt.current_season, gt.get_season_name())
	
	var wm = $WorldMap
	wm.terrain_map = data["terrain_map"]
	wm.spirit_density_map = data["spirit_density_map"]
	wm.spirit_element_map = data["spirit_element_map"]
	wm.sacred_sites.clear()
	for site in data["sacred_sites"]:
		wm.sacred_sites.append({"pos": Vector2i(site["pos"]["x"], site["pos"]["y"]), "element": site["element"], "name": site["name"]})
	wm.sect_positions.clear()
	wm.village_positions.clear()
	for sp in data["sect_positions"]: wm.sect_positions.append(Vector2i(sp["x"], sp["y"]))
	for vp in data["village_positions"]: wm.village_positions.append(Vector2i(vp["x"], vp["y"]))
	wm._world_generated = true
	wm.render_tilemap()
	
	# 刷新小地图和 HUD（延迟一帧等 UI 布局完成）
	var mm = $UI/Minimap
	if mm: mm.call_deferred("reload_data")
	
	var spawner = $CultivatorSpawner
	for child in spawner.get_children(): child.queue_free()
	await get_tree().process_frame
	
	var sect_script = load("res://scripts/entities/sect.gd")
	for sdata in data["sects"]:
		var s = Node2D.new()
		s.set_script(sect_script)
		s.name = sdata["name"]
		s.setup(sdata["color_index"], Vector2(sdata["pos_x"], sdata["pos_y"]))
		s.member_count = sdata["member_count"]
		spawner.add_child(s)
	
	var ss_script = load("res://scripts/entities/sacred_site.gd")
	for site in data["sacred_sites"]:
		var sp = Node2D.new()
		sp.set_script(ss_script)
		sp.name = "Sacred_%d" % site["element"]
		sp.setup(site["element"], site["name"], Vector2(site["pos"]["x"] * 32 + 16, site["pos"]["y"] * 32 + 16))
		spawner.add_child(sp)
	
	var cult_script = load("res://scripts/entities/cultivator.gd")
	for i in data["cultivators"].size():
		var cd: Dictionary = data["cultivators"][i]
		var c = Node2D.new()
		c.set_script(cult_script)
		c.name = "Cultivator_%d" % i
		c.position = Vector2(cd["pos_x"], cd["pos_y"])
		c.setup(cd["name"], cd["realm"], cd["age"])
		c.spirit_root = cd["spirit_root"]
		c.spirit_element = cd["spirit_element"]
		c.root_bone = cd["root_bone"]
		c.comprehension = cd["comprehension"]
		c.fortune = cd["fortune"]
		c.cultivation_exp = cd["cultivation_exp"]
		c.sect = cd["sect"]
		c.inventory = cd.get("inventory", {})
		if cd.has("pills"):
			for k in cd["pills"]: c.inventory[k] = c.inventory.get(k, 0) + cd["pills"][k]
		if cd.has("special_items"):
			for k in cd["special_items"]: c.inventory[k] = c.inventory.get(k, 0) + cd["special_items"][k]
		c.techniques = cd["techniques"]
		c.spirit_stones = cd["spirit_stones"]
		c.pill_qi_ticks = cd.get("pill_qi_ticks", 0)
		c.pill_used_breakthrough = cd.get("pill_used_breakthrough", false)
		c.pill_life_used = cd.get("pill_life_used", false)
		c.life_bonus = cd.get("life_bonus", 0)
		c.learn_book = cd.get("learn_book", "")
		c.learn_progress = cd.get("learn_progress", 0.0)
		c.relations = cd.get("relations", {})
		c.personality = cd.get("personality", 1)
		c.talent = cd.get("talent", 0)
		c.wins = cd["wins"]
		c.losses = cd["losses"]
		c.life_events = cd["life_events"]
		c.is_breaking_through = cd["is_breaking_through"]
		c.breakthrough_progress = cd["breakthrough_progress"]
		c.injured_ticks = cd["injured_ticks"]
		c.blessed_ticks = cd["blessed_ticks"]
		c.cursed_ticks = cd["cursed_ticks"]
		c.ai_goal = cd["ai_goal"]
		spawner.add_child(c)
	
	print("[Load] 读档成功")

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var cam = $Camera2D
	if not cam: return screen_pos
	return cam.get_screen_center_position() + (screen_pos - get_viewport().get_visible_rect().size / 2.0) / cam.zoom

func _left_click(world_pos: Vector2) -> void:
	# 雷劫中手动落雷
	var tm = get_node_or_null("TribulationManager")
	if tm and tm.active:
		tm.strike_at(world_pos)
		return
	
	var spawner = $CultivatorSpawner
	if not spawner: return
	var best_sect: Node2D
	var best_sect_dist: float = 40.0
	var best_cult: Node2D
	var best_cult_dist: float = 64.0
	for node in spawner.get_children():
		if not node.has_method("get_display_name"): continue
		var d: float = world_pos.distance_to(node.position)
		if node.get("sect_name") != null or node.get("site_name") != null:
			if d < best_sect_dist:
				best_sect_dist = d; best_sect = node
		else:
			if d < best_cult_dist:
				best_cult_dist = d; best_cult = node
	var was_same: bool = selected_cultivator != null and selected_cultivator == best_cult
	_deselect_all()
	_close_detail_popup()
	if best_sect: _select_sect(best_sect)
	elif best_cult:
		_select_cultivator(best_cult)
		if was_same: _show_detail_popup(best_cult)
	else:
		var eb = get_node_or_null("/root/EventBus")
		if eb:
			eb.tile_selected.emit(int(world_pos.x / 32.0), int(world_pos.y / 32.0))

func _right_click(world_pos: Vector2, screen_pos: Vector2) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_click()
	var tile_x: int = int(world_pos.x / 32.0)
	var tile_y: int = int(world_pos.y / 32.0)
	var popup = PopupMenu.new()
	
	# 判断是否点在修士身上
	var clicked_cult: bool = false
	if selected_cultivator and is_instance_valid(selected_cultivator):
		var dist: float = world_pos.distance_to(selected_cultivator.position)
		clicked_cult = dist < 40  # 点在修士附近
	
	if clicked_cult:
		var c = selected_cultivator
		popup.add_item("赐福 (20 天道值)", 0)
		popup.add_item("诅咒 (30 天道值)", 1)
		# popup.add_item("抹杀 (10 天道值)", 2)  # 暂时屏蔽
		popup.add_item("雷劫 (50 天道值)", 3)
		popup.position = screen_pos
		popup.id_pressed.connect(func(id: int):
			var gt = get_node_or_null("/root/GameTime")
			var eb = get_node_or_null("/root/EventBus")
			match id:
				0:
					if gt and gt.spend_hm(20):
						c.bless(20)
						if eb: eb.event_log_entry.emit("%s 获得天道赐福" % c.cultivator_name, "hm")
					elif eb: eb.event_log_entry.emit("天道值不足 (需要 20)", "hm")
				1:
					if gt and gt.spend_hm(30):
						c.curse(10)
						if eb: eb.event_log_entry.emit("%s 被天道诅咒" % c.cultivator_name, "hm")
					elif eb: eb.event_log_entry.emit("天道值不足 (需要 30)", "hm")
				3:
					if gt and gt.spend_hm(50):
						if c.get("is_newborn"):
							if eb: eb.event_log_entry.emit("新生修士不可降雷劫", "hm")
						else:
							var tm = get_node_or_null("TribulationManager")
							if tm:
								tm.start_tribulation(c)
								if eb: eb.event_log_entry.emit("天道降下雷劫！", "hm")
					elif eb: eb.event_log_entry.emit("天道值不足 (需要 50)", "hm")
		)
	else:
		popup.add_item("灵潮 (30 天道值)", 0)
		popup.add_item("秘境 (60 天道值)", 1)
		if selected_cultivator and is_instance_valid(selected_cultivator):
			popup.add_item("指引修士至此 (15 天道值)", 2)
		popup.position = screen_pos
		popup.id_pressed.connect(func(id: int):
			var gt = get_node_or_null("/root/GameTime")
			var eb = get_node_or_null("/root/EventBus")
			match id:
				0:
					if gt and gt.spend_hm(30):
						var wm = get_node_or_null("/root/main/WorldMap")
						if wm:
							wm.spirit_boosts.append({"x": tile_x, "y": tile_y, "radius": 8, "multiplier": 2.0, "ticks": 20})
							if eb: eb.event_log_entry.emit("灵潮爆发于(%d,%d)" % [tile_x, tile_y], "hm")
					elif eb: eb.event_log_entry.emit("天道值不足 (需要 30)", "hm")
				1:
					if gt and gt.spend_hm(60):
						var em = get_node_or_null("/root/EncounterManager")
						if em: em.spawn_legendary(tile_x, tile_y)
						if eb: eb.event_log_entry.emit("秘境现世于(%d,%d)！" % [tile_x, tile_y], "hm")
					elif eb: eb.event_log_entry.emit("天道值不足 (需要 60)", "hm")
				2:
					if gt and gt.spend_hm(15):
						var c = selected_cultivator
						if c.get("is_newborn"): 
							if eb: eb.event_log_entry.emit("新生修士不受天道指引", "hm")
							return
						c.set("wander_target", Vector2(tile_x * 32 + 16, tile_y * 32 + 16))
						c.set("wander_cooldown", 99.0)
						c.set("guided", true)
						c.set("ai_goal", "天道指引")
						if eb: eb.event_log_entry.emit("天道指引 %s 前往(%d,%d)" % [c.cultivator_name, tile_x, tile_y], "hm")
					elif eb: eb.event_log_entry.emit("天道值不足 (需要 15)", "hm")
		)
	add_child(popup)
	popup.popup()

func _deselect_all() -> void:
	if selected_cultivator and is_instance_valid(selected_cultivator):
		if selected_cultivator.has_method("set_selected"):
			selected_cultivator.set_selected(false)
	selected_cultivator = null
	var eb = get_node_or_null("/root/EventBus")
	if eb: eb.cultivator_selected.emit(null)
	if selected_sect and is_instance_valid(selected_sect):
		if selected_sect.has_method("set_selected"):
			selected_sect.set_selected(false)
	selected_sect = null
	if eb: eb.sect_selected.emit(null)

func _select_cultivator(c: Node2D) -> void:
	selected_cultivator = c
	c.set_selected(true)
	if selected_sect:
		selected_sect.set_selected(false)
	selected_sect = null
	c.combat_cooldown = 5.0
	var eb = get_node_or_null("/root/EventBus")
	if eb: eb.cultivator_selected.emit(c)

func _select_sect(s: Node2D) -> void:
	selected_sect = s
	s.set_selected(true)
	if selected_cultivator:
		selected_cultivator.set_selected(false)
	selected_cultivator = null
	var eb = get_node_or_null("/root/EventBus")
	if eb: eb.sect_selected.emit(s)

func save_game() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if not sm: return
	var gt = get_node_or_null("/root/GameTime")
	var wm = $WorldMap
	var spawner = $CultivatorSpawner
	if not wm or not spawner: return
	var t_year: int = gt.current_year if gt else 1
	var t_season: int = gt.current_season if gt else 0
	var t_speed: int = gt.current_speed if gt else 1
	var t_hm: int = gt.heavenly_mechanism if gt else 0
	var data: Dictionary = {
		"time": {"year": t_year, "season": t_season, "speed": t_speed, "hm": t_hm},
		"terrain_map": wm.terrain_map,
		"spirit_density_map": wm.spirit_density_map,
		"spirit_element_map": wm.spirit_element_map,
	}
	var ssaves: Array = []
	for s in wm.sacred_sites:
		ssaves.append({"pos": {"x": s["pos"].x, "y": s["pos"].y}, "element": s["element"], "name": s["name"]})
	data["sacred_sites"] = ssaves
	var sects_sp: Array = []
	for sp in wm.sect_positions: sects_sp.append({"x": sp.x, "y": sp.y})
	var vills: Array = []
	for vp in wm.village_positions: vills.append({"x": vp.x, "y": vp.y})
	data["sect_positions"] = sects_sp
	data["village_positions"] = vills
	var cults: Array = []
	for child in spawner.get_children():
		if child.get("cultivator_name") == null: continue
		cults.append({
			"name": child.cultivator_name, "realm": child.realm, "age": child.age,
			"spirit_root": child.spirit_root, "spirit_element": child.spirit_element,
			"root_bone": child.root_bone, "comprehension": child.comprehension, "fortune": child.fortune,
			"cultivation_exp": child.cultivation_exp, "sect": child.sect,
			"inventory": child.inventory, "techniques": child.techniques,
			"spirit_stones": child.spirit_stones,
			"pill_qi_ticks": child.pill_qi_ticks, "pill_used_breakthrough": child.pill_used_breakthrough,
			"pill_life_used": child.pill_life_used, "life_bonus": child.life_bonus,
		"learn_book": child.learn_book, "learn_progress": child.learn_progress,
		"relations": child.relations,
		"personality": child.personality, "talent": child.talent,
			"pos_x": child.position.x, "pos_y": child.position.y,
			"wins": child.wins, "losses": child.losses, "life_events": child.life_events,
			"is_breaking_through": child.is_breaking_through, "breakthrough_progress": child.breakthrough_progress,
			"injured_ticks": child.injured_ticks, "blessed_ticks": child.blessed_ticks, "cursed_ticks": child.cursed_ticks,
			"ai_goal": child.ai_goal,
		})
	data["cultivators"] = cults
	var sects: Array = []
	for child in spawner.get_children():
		if child.get("sect_name") == null: continue
		sects.append({
			"name": child.sect_name, "color_index": child.color_index,
			"member_count": child.member_count, "pos_x": child.position.x, "pos_y": child.position.y,
		})
	data["sects"] = sects
	if sm.save_game(data): print("[Save] 存档成功")
	else: print("[Save] 存档失败")

func _dl_label(text: String) -> Label:
	var l = Label.new(); l.text = text; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	l.add_theme_font_size_override("font_size", 15)
	return l

func _style_panel(panel: PanelContainer) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.16, 0.94)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.78, 0.63, 0.31, 0.8)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

func _show_detail_popup(c: Node2D) -> void:
	_close_detail_popup()
	var ui = get_node_or_null("UI")
	if not ui: return
	var panel = PanelContainer.new()
	panel.name = "DetailPopup"
	panel.custom_minimum_size = Vector2(380, 500)
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -190; panel.offset_top = -250
	panel.offset_right = 190; panel.offset_bottom = 250
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(panel)
	var vbox = VBoxContainer.new(); panel.add_child(vbox)
	vbox.add_child(_dl_label("▎%s" % c.get("cultivator_name")))
	vbox.add_child(_dl_label("境界: %s" % c.get("REALM_NAMES")[c.get("realm")]))
	var sr_names: Array = c.get("SPIRIT_ROOT_NAMES")
	var e_names: Array = c.get("ELEMENT_NAMES")
	vbox.add_child(_dl_label("灵根: %s(%s)" % [sr_names[c.get("spirit_root")], e_names[c.get("spirit_element")]]))
	vbox.add_child(_dl_label("根骨: %d  悟性: %d  气运: %d" % [c.get("root_bone"), c.get("comprehension"), c.get("fortune")]))
	var pn: Array = c.get("PERSONALITY_NAMES")
	var tn: Array = c.get("TALENT_NAMES")
	vbox.add_child(_dl_label("性格: %s  天赋: %s" % [pn[c.get("personality")], tn[c.get("talent")]]))
	vbox.add_child(_dl_label("宗门: %s  年龄: %d%s" % [
		c.get("sect") if c.get("sect") else "散修", 
		c.get("age"),
		" (已故)" if str(c.name).begins_with("Tombstone_") else ""
	]))
	var dc = c.get("death_cause")
	if dc and dc != "":
		vbox.add_child(_dl_label("死因: %s" % dc))
	var ne: float = c.get("EXP_TO_NEXT")[c.get("realm")] if c.get("realm") < c.get("EXP_TO_NEXT").size() else -1
	vbox.add_child(_dl_label("修为: %.0f / %.0f" % [c.get("cultivation_exp"), ne] if ne > 0 else "修为: %.0f (圆满)" % c.get("cultivation_exp")))
	vbox.add_child(_dl_label("战绩: %d胜 %d败" % [c.get("wins"), c.get("losses")]))
	vbox.add_child(_dl_label("灵石: %d" % c.get("spirit_stones")))
	var pills: Dictionary = c.get("inventory"); var pl: String = ""
	var pill_data = load("res://scripts/data/items.gd").new()
	for k in pills:
		if pills[k] > 0:
			var name: String = k
			for p in pill_data.PILLS:
				if p["id"] == k: name = p["name"]; break
			for t in pill_data.TECHNIQUES:
				if t["id"] == k: name = "书·" + t["name"]; break
			for s in pill_data.SPECIALS:
				if s["id"] == k: name = s["name"]; break
			for ci in pill_data.COMBAT_ITEMS:
				if ci["id"] == k: name = ci["name"]; break
			pl += "%s×%d " % [name, pills[k]]
	pill_data.queue_free()
	vbox.add_child(_dl_label("随身: %s" % (pl if pl else "无")))
	var tech_list: String = ""
	for t in c.get("techniques"):
		tech_list += "%s " % t["name"]
	if c.get("learn_book") != "":
		var lb: String = c.get("learn_book")
		for t in pill_data.TECHNIQUES:
			if t["id"] == lb: lb = t["name"]; break
		tech_list += "[学%s:%.0f%%] " % [lb, c.get("learn_progress") * 100]
	if tech_list != "":
		vbox.add_child(_dl_label("功法: %s" % tech_list))
	vbox.add_child(HSeparator.new())
	vbox.add_child(_dl_label("生涯大事:"))
	var events: Array = c.get("life_events")
	var shown: int = mini(20, events.size())
	for i in range(events.size() - shown, events.size()):
		var evt = events[i]
		if evt is Dictionary:
			vbox.add_child(_dl_label("[%d年] %s %s" % [evt["year"], evt.get("realm", ""), evt["text"]]))
		else:
			vbox.add_child(_dl_label(str(evt)))
	var btn = Button.new(); btn.text = "关闭"; btn.pressed.connect(_close_detail_popup)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.78, 0.63, 0.31))
	vbox.add_child(btn)
	ui.add_child(panel)
	_detail_popup = panel

func _close_detail_popup() -> void:
	if _detail_popup and is_instance_valid(_detail_popup):
		_detail_popup.queue_free(); _detail_popup = null
