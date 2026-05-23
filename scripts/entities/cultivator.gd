## cultivator.gd - 修士实体
extends Node2D

enum Realm { QI_REFINING, FOUNDATION, GOLDEN_CORE, NASCENT_SOUL, DIVINE, TRIBULATION }
enum SpiritRoot { TURBID=0, CLEAR=1, MYSTIC=2, HEAVENLY=3 }
enum Element { NONE=0, METAL=1, WOOD=2, WATER=3, FIRE=4, EARTH=5 }

const REALM_NAMES: Array[String] = ["炼气", "筑基", "金丹", "元婴", "化神", "渡劫"]
const REALM_COLORS: Array[Color] = [
	Color.LIGHT_BLUE, Color.CYAN, Color.YELLOW, Color.ORANGE, Color.RED, Color.PURPLE,
]
const SPIRIT_ROOT_NAMES: Array[String] = ["浊灵根", "清灵根", "玄灵根", "天灵根"]
const SPIRIT_ROOT_SPEED: Array[float] = [1.0, 1.8, 3.0, 5.0]
const SPIRIT_ROOT_WEIGHTS: Array[float] = [0.50, 0.30, 0.15, 0.05]
const ELEMENT_NAMES: Array[String] = ["无", "金", "木", "水", "火", "土"]

const CULT_SPEED: Array[float] = [2.0, 5.0, 10.0, 20.0, 40.0, 80.0]
const EXP_TO_NEXT: Array[float] = [80.0, 200.0, 400.0, 800.0, 2000.0, 5000.0]
const LIFESPAN: Array[int] = [150, 300, 800, 2000, 5000, 9999]

# 突破所需灵气阈值
const BREAK_SPIRIT: Array[float] = [0.0, 0.3, 0.5, 0.7, 1.0, 1.0]

# 基础属性
var cultivator_name: String
var realm: int = Realm.QI_REFINING
var age: int = 18
var cultivation_exp: float = 0.0
var alive: bool = true
var is_selected: bool = false
var sect: String = ""

# 灵根
var spirit_root: int = SpiritRoot.TURBID
var spirit_element: int = Element.NONE

# 四维属性
var root_bone: int = 50    # 根骨 10-100
var comprehension: int = 50 # 悟性 10-100
var fortune: int = 50       # 气运 10-100

# 物品
var pills: Dictionary = {}   # {"筑基丹": 1, ...}
var techniques: Array = []   # [{"name": "xxx", "grade": 0, "type": "cult"}]
var special_items: Dictionary = {} # {"替死符": 1, "灵髓": 0, ...}
var spirit_stones: int = 0

# 战斗
var combat_cooldown: float = 0.0
var wins: int = 0
var losses: int = 0

# 天道干预
var blessed_ticks: int = 0
var cursed_ticks: int = 0

# 突破状态
var is_breaking_through: bool = false
var breakthrough_progress: float = 0.0
var injured_ticks: int = 0

# 生涯大事
var life_events: Array = []  # [{year, text}]

static var _icon_textures: Array[Texture2D] = []

var wander_target: Vector2
var wander_cooldown: float = 0.0
var move_speed: float = 60.0

func _ready() -> void:
	if _icon_textures.is_empty():
		for i in 6:
			_icon_textures.append(load("res://assets/tiles/cultivator_%d.png" % i))
	_connect_time()
	queue_redraw()

func _draw() -> void:
	if not alive: return
	if is_selected:
		draw_circle(Vector2.ZERO, 20, Color.GOLD, false, 2)
	if blessed_ticks > 0:
		draw_circle(Vector2.ZERO, 18, Color.GOLD, false, 1)
	if cursed_ticks > 0:
		draw_circle(Vector2.ZERO, 18, Color.RED, false, 1)
	if realm < _icon_textures.size() and _icon_textures[realm]:
		draw_texture(_icon_textures[realm], Vector2(-16, -16))
	else:
		draw_circle(Vector2.ZERO, 8, REALM_COLORS[realm])
		draw_circle(Vector2.ZERO, 9, Color.BLACK, false, 2)

func setup(p_name: String, p_realm: int, p_age: int) -> void:
	cultivator_name = p_name
	realm = p_realm
	age = p_age
	_generate_attributes()
	cultivation_exp = randf_range(0, EXP_TO_NEXT[realm] * 0.3) if EXP_TO_NEXT[realm] > 0 else 3000.0
	_pick_wander_target()

func _generate_attributes() -> void:
	# 灵根
	var roll: float = randf()
	var acc: float = 0.0
	for i in SPIRIT_ROOT_WEIGHTS.size():
		acc += SPIRIT_ROOT_WEIGHTS[i]
		if roll < acc:
			spirit_root = i
			break
	# 灵根属性
	if randf() < 0.4:
		spirit_element = randi_range(Element.METAL, Element.EARTH)
	else:
		spirit_element = Element.NONE
	# 四维
	root_bone = randi_range(10, 100)
	comprehension = randi_range(10, 100)
	fortune = randi_range(10, 100)

func _connect_time() -> void:
	var gt = get_node_or_null("/root/GameTime")
	if gt:
		gt.tick_advanced.connect(_on_tick)

func get_cultivation_mult() -> float:
	var mult: float = SPIRIT_ROOT_SPEED[spirit_root]
	mult *= root_bone / 50.0
	# 灵根属性匹配
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm:
		var tx: int = int(position.x / 32.0)
		var ty: int = int(position.y / 32.0)
		var sd: float = wm.get_spirit_density(tx, ty)
		var se: int = wm.get_spirit_element(tx, ty)
		mult *= (1.0 + sd * 0.5)
		if spirit_element != Element.NONE and se == spirit_element:
			mult *= 1.5  # 同属性圣地 +50%
	# 功法加成
	for tech in techniques:
		if tech["type"] == "cult":
			mult *= (1.0 + tech["grade"] * 0.15)
	# 受伤减速
	if injured_ticks > 0:
		mult *= 0.3
	return mult

func _on_tick(_year: int, _season: int) -> void:
	if not alive: return
	if realm >= Realm.TRIBULATION: return
	if injured_ticks > 0:
		injured_ticks -= 1
	
	var speed_mult: float = 1.0
	if blessed_ticks > 0:
		speed_mult = 2.5
		blessed_ticks -= 1
	if cursed_ticks > 0:
		speed_mult = 0.3
		cursed_ticks -= 1
		if randf() < 0.05:
			die()
			return
	
	if is_breaking_through:
		breakthrough_progress += 1.0
		if breakthrough_progress >= 3.0:
			_finish_breakthrough()
		return
	
	cultivation_exp += CULT_SPEED[realm] * speed_mult * get_cultivation_mult()
	if EXP_TO_NEXT[realm] > 0 and cultivation_exp >= EXP_TO_NEXT[realm]:
		_attempt_breakthrough()
	_check_combat()

func _attempt_breakthrough() -> void:
	var required: float = BREAK_SPIRIT[realm]
	if required > 0:
		var wm = get_node_or_null("/root/main/WorldMap")
		if wm:
			var tx: int = int(position.x / 32.0)
			var ty: int = int(position.y / 32.0)
			if wm.get_spirit_density(tx, ty) < required:
				return  # 灵气不足，继续等
	
	is_breaking_through = true
	breakthrough_progress = 0.0
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.event_log_entry.emit("%s 开始突破 %s" % [cultivator_name, REALM_NAMES[realm + 1]], "cult")

func _finish_breakthrough() -> void:
	is_breaking_through = false
	breakthrough_progress = 0.0
	
	var success_chance: float = comprehension / 100.0
	success_chance *= SPIRIT_ROOT_SPEED[spirit_root] / 4.0
	
	# 环境灵气
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm:
		var tx: int = int(position.x / 32.0)
		var ty: int = int(position.y / 32.0)
		success_chance *= (0.5 + wm.get_spirit_density(tx, ty) * 0.5)
		# 同属性圣地
		if spirit_element != Element.NONE and wm.get_spirit_element(tx, ty) == spirit_element:
			success_chance += 0.1
	
	# 丹药加成
	var pill_bonus: float = 0.0
	match realm:
		Realm.QI_REFINING:
			if pills.get("筑基丹", 0) > 0:
				success_chance = 1.0  # 100%
				pills["筑基丹"] -= 1
		Realm.FOUNDATION:
			if pills.get("结丹丹", 0) > 0:
				pill_bonus = 0.30
				pills["结丹丹"] -= 1
		Realm.GOLDEN_CORE:
			if pills.get("婴变丹", 0) > 0:
				pill_bonus = 0.15
				pills["婴变丹"] -= 1
		Realm.NASCENT_SOUL:
			if pills.get("化神丹", 0) > 0:
				pill_bonus = 0.05
				pills["化神丹"] -= 1
		Realm.DIVINE:
			if pills.get("渡劫丹", 0) > 0:
				pill_bonus = 0.05
				pills["渡劫丹"] -= 1
	
	success_chance = clampf(success_chance + pill_bonus, 0.05, 0.95)
	
	var eb = get_node_or_null("/root/EventBus")
	var gt = get_node_or_null("/root/GameTime")
	
	if randf() < success_chance:
		var old_realm: int = realm
		realm += 1
		cultivation_exp = 0.0
		queue_redraw()
		var hm: int = [5, 10, 20, 50, 100, 200][old_realm]
		if gt: gt.add_hm(hm)
		_add_event("突破至 %s" % REALM_NAMES[realm])
		if eb:
			eb.cultivator_breakthrough.emit(self, old_realm, realm)
			eb.event_log_entry.emit("%s 突破至 %s！" % [cultivator_name, REALM_NAMES[realm]], "cult")
	else:
		cultivation_exp *= 0.7
		# 失败惩罚
		match realm:
			Realm.QI_REFINING:
				pass  # 无损失
			Realm.FOUNDATION:
				pass  # 只掉修为
			Realm.GOLDEN_CORE:
				injured_ticks = 5
			Realm.NASCENT_SOUL:
				injured_ticks = 10
				if randf() < 0.2: die(); return
			Realm.DIVINE:
				injured_ticks = 15
				if randf() < 0.5: die(); return
		if eb:
			eb.event_log_entry.emit("%s 突破 %s 失败" % [cultivator_name, REALM_NAMES[realm + 1]], "cult")

func _process(delta: float) -> void:
	if not alive: return
	wander_cooldown -= delta
	if wander_cooldown <= 0.0:
		_pick_wander_target()
	if position.distance_to(wander_target) > 4.0:
		position = position.move_toward(wander_target, move_speed * delta)

func _pick_wander_target() -> void:
	wander_target = position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	wander_target.x = clampf(wander_target.x, 16, 6384)
	wander_target.y = clampf(wander_target.y, 16, 6384)
	wander_cooldown = randf_range(2.0, 6.0)

func get_display_name() -> String:
	return "%s · %s" % [cultivator_name, REALM_NAMES[realm]]

func set_selected(s: bool) -> void:
	is_selected = s
	queue_redraw()

func bless(ticks: int) -> void:
	blessed_ticks += ticks
	queue_redraw()

func curse(ticks: int) -> void:
	cursed_ticks += ticks
	queue_redraw()

func get_combat_power() -> float:
	# 战力 = 境界×30 + 根骨×0.3 + 战斗功法×10 ± 气运/5
	var base: float = (realm + 1) * 30.0
	base += root_bone * 0.3
	for tech in techniques:
		if tech["type"] == 1:  # TechType.COMBAT
			base += (tech["grade"] + 1) * 10.0
	# 随机波动
	var rng = RandomNumberGenerator.new()
	rng.seed = randi()
	base += rng.randf_range(-fortune / 5.0, fortune / 5.0)
	return base

func _check_combat() -> void:
	if combat_cooldown > 0:
		combat_cooldown -= 1
		return
	var spawner = get_parent()
	if not spawner: return
	for other in spawner.get_children():
		if other == self: continue
		if other.get("realm") == null: continue
		if not other.get("alive"): continue
		if position.distance_to(other.position) > 60: continue
		var my_power: float = get_combat_power()
		var other_power: float = other.get_combat_power()
		if my_power <= other_power: continue  # 我方弱，不主动出手
		var eb = get_node_or_null("/root/EventBus")
		var ratio: float = (my_power - other_power) / maxf(my_power, 1.0)
		if ratio > 0.5:
			wins += 1
			other.die()
			if eb:
				eb.event_log_entry.emit("%s 斩杀 %s" % [cultivator_name, other.cultivator_name], "fight")
		elif ratio > 0.2:
			wins += 1
			other.set("losses", other.get("losses") + 1)
			other.set("injured_ticks", 10)
			other.combat_cooldown = 10.0
			if eb:
				eb.event_log_entry.emit("%s 重伤 %s，后者逃走" % [cultivator_name, other.cultivator_name], "fight")
		else:
			wins += 1
			other.set("losses", other.get("losses") + 1)
			other.set("injured_ticks", 3)
			other.combat_cooldown = 8.0
			if eb:
				eb.event_log_entry.emit("%s 击退 %s" % [cultivator_name, other.cultivator_name], "fight")
		combat_cooldown = 5.0
		return

func die() -> void:
	# 替死符
	if special_items.get("替死符", 0) > 0:
		special_items["替死符"] -= 1
		injured_ticks = 5
		var eb2 = get_node_or_null("/root/EventBus")
		if eb2:
			eb2.event_log_entry.emit("%s 消耗替死符躲过死劫" % cultivator_name, "item")
		return
	alive = false
	visible = false
	var gt = get_node_or_null("/root/GameTime")
	if gt: gt.add_hm((realm + 1) * 3)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.cultivator_died.emit(self)
		eb.event_log_entry.emit("%s 陨落" % cultivator_name, "fight")

func _add_event(text: String) -> void:
	var gt = get_node_or_null("/root/GameTime")
	var yr: int = gt.current_year if gt else 0
	life_events.append({"year": yr, "text": text, "realm": REALM_NAMES[realm] if realm < REALM_NAMES.size() else "?"})
