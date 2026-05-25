# encounter_manager.gd - 奇遇点管理
extends Node2D

const SPAWN_INTERVAL: int = 20  # 每5年(20季)刷新
const DURATION: int = 20         # 持续5年后消失
const MIN_COUNT: int = 1
const MAX_COUNT: int = 3
const ENCOUNTER_LENGTH: int = 4  # 持续4季

var encounters: Array = []  # [{pos: Vector2i, quality: int, timer: int, occupied: String}]
var _tick_timer: int = 0
var _world_map: Node = null
var _blink_frame: int = 0
var _ui_label: Label = null

enum Quality { COMMON=0, RARE=1, PRECIOUS=2, LEGEND=3 }

static var REWARDS: Dictionary = {
	Quality.COMMON: [
		{"type": "stones", "min": 3, "max": 8},
		{"type": "item", "id": "pill_qi"},
		{"type": "item", "id": "tech_cult_mortal"},
		{"type": "item", "id": "tech_combat_mortal"},
	],
	Quality.RARE: [
		{"type": "stones", "min": 15, "max": 30},
		{"type": "item", "id": "pill_heal"},
		{"type": "item", "id": "tech_cult_yellow"},
		{"type": "item", "id": "tech_combat_yellow"},
		{"type": "item", "id": "cb_fire"},
		{"type": "item", "id": "cb_shield"},
	],
	Quality.PRECIOUS: [
		{"type": "stones", "min": 50, "max": 80},
		{"type": "item", "id": "pill_form_core"},
		{"type": "item", "id": "pill_nascent"},
		{"type": "item", "id": "tech_cult_mystic"},
		{"type": "item", "id": "tech_combat_mystic"},
		{"type": "item", "id": "spec_spirit_orb"},
	],
	Quality.LEGEND: [
		{"type": "stones", "min": 200, "max": 500},
		{"type": "item", "id": "pill_life"},
		{"type": "item", "id": "tech_cult_earth"},
		{"type": "item", "id": "tech_combat_earth"},
		{"type": "item", "id": "spec_spirit_marrow"},
		{"type": "item", "id": "spec_boundary_stone"},
	],
}

func _ready() -> void:
	_tick_timer = SPAWN_INTERVAL
	call_deferred("connect_tick")

func _process(_delta: float) -> void:
	_blink_frame += 1
	for enc in encounters:
		if enc["occupied"] != "": continue
		var sp: Sprite2D = enc.get("_sprite")
		if sp:
			var pulse: float = sin(_blink_frame * 0.08) * 0.3 + 0.7
			sp.self_modulate = Color(1, 1, 1, pulse)

func _all_occupied() -> bool:
	for enc in encounters:
		if enc["occupied"] == "": return false
	return true

func _draw() -> void:
	var qcolors: Array = [Color.WHITE, Color.CYAN, Color.GOLD, Color.ORANGE_RED]
	for enc in encounters:
		if enc["occupied"] != "": continue
		var wp: Vector2 = Vector2(enc["grid_x"] * 32 + 16, enc["grid_y"] * 32 + 16)
		var q: int = enc["quality"]
		var pulse: float = sin(_blink_frame * 0.08) * 0.5 + 0.5  # 0~1 呼吸
		var col: Color = qcolors[min(q, 3)]
		col.a = 0.15 + pulse * 0.2
		draw_circle(wp, 64, col, true)         # 大光晕
		col.a = 0.5 + pulse * 0.3
		draw_circle(wp, 24, col, false, 2)     # 边框
		draw_circle(wp, 8, col, true)           # 中心点

func connect_tick() -> void:
	var gt = get_node_or_null("/root/GameTime")
	if gt and gt.has_signal("tick_advanced"):
		gt.tick_advanced.connect(_on_tick)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.world_generated.connect(_spawn_encounters, CONNECT_ONE_SHOT)

func _on_tick(_year: int, _season: int) -> void:
	_tick_timer -= 1
	# 过期奇遇消失
	for i in range(encounters.size() - 1, -1, -1):
		encounters[i]["timer"] -= 1
		if encounters[i]["timer"] <= 0:
			var sp = encounters[i].get("_sprite")
			if sp: sp.queue_free()
			encounters.remove_at(i)
	# 刷新新一批
	if _tick_timer <= 0:
		_tick_timer = SPAWN_INTERVAL
		_spawn_encounters()

func _spawn_encounters() -> void:
	var wm = _get_wm()
	if not wm or not wm.get("terrain_map") or wm.terrain_map.size() == 0:
		return
	
	var count: int = randi_range(MIN_COUNT, MAX_COUNT)
	var water: Array = [0, 1]  # Terrain deep/shallow water
	var forbidden: Array = []  # 宗门领地+圣地
	for sp in wm.sect_positions:
		forbidden.append(sp)
	if wm.get("capital_pos") and wm.capital_pos.x >= 0:
		forbidden.append(wm.capital_pos)
	for ss in wm.sacred_sites:
		forbidden.append(ss.get("pos"))
	
	for _i in count:
		for _try in 100:
			var x: int = randi_range(5, wm.MAP_WIDTH - 6)
			var y: int = randi_range(5, wm.MAP_HEIGHT - 6)
			var t: int = wm.terrain_map[y][x] if wm.terrain_map[y].size() > x else 0
			if t in water: continue
			var pos: Vector2i = Vector2i(x, y)
			var blocked: bool = false
			for fp in forbidden:
				if pos.distance_to(fp) < 8: blocked = true; break
			if blocked: continue
			var q: int = _roll_quality()
			var enc_data: Dictionary = {
				"pos": pos,
				"grid_x": x, "grid_y": y,
				"quality": q,
				"timer": DURATION,
				"occupied": "",
				"_sprite": null,
			}
			# 创建可视标记
			var sp: Sprite2D = Sprite2D.new()
			sp.position = Vector2(x * 32 + 16, y * 32 + 16)
			var circle = _create_glow_circle(q)
			sp.texture = circle
			sp.centered = true
			wm.add_child(sp)
			enc_data["_sprite"] = sp
			encounters.append(enc_data)
			break

func _create_glow_circle(q: int) -> ImageTexture:
	var colors: Array = [Color.WHITE, Color.CYAN, Color.GOLD, Color.ORANGE_RED]
	var col: Color = colors[min(q, 3)]
	var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for dy in range(-63, 64):
		for dx in range(-63, 64):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > 63: continue
			var alpha: float = max(0, 1.0 - dist / 63.0)
			alpha *= 0.5
			img.set_pixel(64 + dx, 64 + dy, Color(col.r, col.g, col.b, alpha))
	return ImageTexture.create_from_image(img)

func _roll_quality() -> int:
	var r: float = randf()
	if r < 0.60: return Quality.COMMON
	if r < 0.85: return Quality.RARE
	if r < 0.95: return Quality.PRECIOUS
	return Quality.LEGEND

func spawn_legendary(gx: int, gy: int) -> void:
	var wm = _get_wm()
	if not wm: return
	var sp: Sprite2D = Sprite2D.new()
	sp.position = Vector2(gx * 32 + 16, gy * 32 + 16)
	var circle = _create_glow_circle(Quality.LEGEND)
	sp.texture = circle
	sp.centered = true
	wm.add_child(sp)
	encounters.append({
		"pos": Vector2i(gx, gy),
		"grid_x": gx, "grid_y": gy,
		"quality": Quality.LEGEND,
		"timer": DURATION,
		"occupied": "",
		"_sprite": sp,
	})

func _get_wm() -> Node:
	if _world_map: return _world_map
	_world_map = get_node_or_null("/root/main/WorldMap")
	return _world_map

func check_nearby_range(world_pos: Vector2, dist: int = 1) -> Dictionary:
	var tx: int = int(world_pos.x / 32.0)
	var ty: int = int(world_pos.y / 32.0)
	for enc in encounters:
		if enc["occupied"] != "": continue
		var dx: int = abs(tx - enc["grid_x"])
		var dy: int = abs(ty - enc["grid_y"])
		if dx <= dist and dy <= dist:
			return enc
	return {}

func check_nearby(world_pos: Vector2) -> Dictionary:
	return check_nearby_range(world_pos, 1)

func try_enter(cultivator: Node, enc: Dictionary) -> bool:
	"""多人竞争：先到先得 + 同季 roll 点"""
	if enc["occupied"] != "":
		var other = get_node_or_null(NodePath(enc["occupied"]))
		if other and is_instance_valid(other):
			# roll 点竞争
			if randi() % 100 > randi() % 100:
				other.set("is_in_encounter", false)
				other.set("encounter_timer", 0)
				other.set("ai_goal", "游历")
			else:
				return false
	enc["occupied"] = str(cultivator.get_path())
	cultivator.set("is_in_encounter", true)
	cultivator.set("encounter_timer", ENCOUNTER_LENGTH)
	cultivator.set("ai_goal", "奇遇中")
	return true

func finish_encounter(cultivator: Node) -> void:
	if not cultivator or not is_instance_valid(cultivator): return
	for enc in encounters:
		if enc["occupied"] == str(cultivator.get_path()):
			# 直接给奖励，不走 get/set 避免类型问题
			var q: int = enc["quality"]
			var pool: Array = REWARDS.get(q, [])
			var reward: Dictionary = pool.pick_random()
			t_send_reward(cultivator, reward, q)
			var sp = enc.get("_sprite")
			if sp: sp.queue_free()
			encounters.erase(enc)
			break
	cultivator.set("is_in_encounter", false)

func t_send_reward(cultivator: Node, reward: Dictionary, q: int) -> void:
	var gt = get_node_or_null("/root/GameTime")
	var eb = get_node_or_null("/root/EventBus")
	var cname: String = cultivator.get("cultivator_name") if cultivator.get("cultivator_name") != null else "?"
	var qname: Array = ["普通", "稀有", "珍贵", "传说"]
	# 加载物品名映射
	var item_names: Dictionary = {}
	var items_data = load("res://scripts/data/items.gd")
	for p in items_data.PILLS + items_data.TECHNIQUES + items_data.SPECIALS + items_data.COMBAT_ITEMS:
		item_names[p["id"]] = p["name"]
	
	match reward["type"]:
		"stones":
			var amt: int = randi_range(reward["min"], reward["max"])
			if cultivator.has_method("add_stones"):
				cultivator.add_stones(amt)
			else:
				cultivator.set("spirit_stones", cultivator.get("spirit_stones") + amt)
			var msg: String = "%s %s奇遇获%d灵石" % [cname, qname[q], amt]
			if cultivator.has_method("_add_event"):
				cultivator._add_event(msg)
			if eb: eb.event_log_entry.emit(msg, "cult")
		"item":
			var item_id: String = reward["id"]
			var display_name: String = item_names.get(item_id, item_id)
			if cultivator.has_method("add_item"):
				cultivator.add_item(item_id)
			else:
				var inv = cultivator.get("inventory")
				if typeof(inv) == TYPE_DICTIONARY:
					inv[item_id] = inv.get(item_id, 0) + 1
			var msg: String = "%s %s奇遇获%s" % [cname, qname[q], display_name]
			if cultivator.has_method("_add_event"):
				cultivator._add_event(msg)
			if eb: eb.event_log_entry.emit(msg, "cult")

func _give_reward(cultivator: Node, enc: Dictionary) -> void:
	if not cultivator or not is_instance_valid(cultivator): return
	var q: int = enc["quality"]
	var pool: Array = REWARDS.get(q, [])
	var reward: Dictionary = pool.pick_random()
	var inv: Dictionary = cultivator.get("inventory")
	var gt = get_node_or_null("/root/GameTime")
	var yr: int = gt.current_year if gt else 0
	
	match reward["type"]:
		"stones":
			var amt: int = randi_range(reward["min"], reward["max"])
			cultivator.set("spirit_stones", cultivator.get("spirit_stones") + amt)
			var qname: Array = ["普通", "稀有", "珍贵", "传说"]
			cultivator.get("life_events").append({
				"text": "%s奇遇获%d灵石" % [qname[q], amt],
				"year": yr,
			})
		"item":
			inv[reward["id"]] = inv.get(reward["id"], 0) + 1
			var items_data = load("res://scripts/data/items.gd")
			var name: String = reward["id"]
			for p in items_data.PILLS + items_data.TECHNIQUES + items_data.SPECIALS + items_data.COMBAT_ITEMS:
				if p["id"] == reward["id"]: name = p["name"]; break
			var qname: Array = ["普通", "稀有", "珍贵", "传说"]
			cultivator.get("life_events").append({
				"text": "%s奇遇获%s" % [qname[q], name],
				"year": yr,
			})
