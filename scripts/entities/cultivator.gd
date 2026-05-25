## cultivator.gd - 修士实体
extends Node2D

enum Realm { QI_REFINING, FOUNDATION, GOLDEN_CORE, NASCENT_SOUL, DIVINE, TRIBULATION }
enum SpiritRoot { TURBID=0, CLEAR=1, MYSTIC=2, HEAVENLY=3 }
enum Element { NONE=0, METAL=1, WOOD=2, WATER=3, FIRE=4, EARTH=5 }
enum Personality { AGGRESSIVE=0, STEADY=1, PEACEFUL=2 }
enum Talent { SKY_WISDOM=0, TENACIOUS=1, GREEDY=2, EXPLORER=3, ALCHEMIST=4, SLAYER=5, LONER=6, CAUTIOUS=7, WAR_GOD=8 }

const PERSONALITY_NAMES: Array[String] = ["嗜杀", "稳健", "平和"]
const PERSONALITY_FIGHT_CHANCE: Array[float] = [0.80, 0.50, 0.20]
const TALENT_NAMES: Array[String] = ["天慧", "坚韧", "贪婪", "探奇", "丹道", "杀伐", "孤僻", "谨慎", "战神"]

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
const BREAK_DURATION: Array[int] = [3, 5, 8, 12, 20, 50]
const BREAK_ITEMS: Dictionary = {
	Realm.NASCENT_SOUL: "spec_spirit_marrow",  # 元婴→化神 需灵髓
	Realm.DIVINE: "spec_boundary_stone",        # 化神→渡劫 需破界石
}

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
var inventory: Dictionary = {}  # {"pill_qi": 3, "替死符": 1, ...}
var techniques: Array = []      # [{"name": "xxx", "grade": 0, "type": "cult"}]
static var _tech_cache: Dictionary = {}  # ID→数据
static var _tech_loaded: bool = false
var spirit_stones: int = 0
var pill_used_breakthrough: bool = false
var pill_qi_ticks: int = 0
var pill_life_used: bool = false
var life_bonus: int = 0
var learn_book: String = ""  # 正在学的功法书名
var learn_progress: float = 0.0  # 0~1
var is_in_encounter: bool = false
var encounter_timer: int = 0
var guided: bool = false
var overflow_reported: bool = false
var _loot_cooldown: float = 0.0
var in_tribulation: bool = false
var relations: Dictionary = {}  # { "对方名字": 数值 }
var personality: int = Personality.STEADY
var talent: int = Talent.SKY_WISDOM

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
var ai_goal: String = "游历"
var is_newborn: bool = false
var newborn_target_sect: String = ""

# 生涯大事
var life_events: Array = []  # [{year, text}]

static var _icon_textures: Array[Texture2D] = []

var _sprite: Sprite2D

var wander_target: Vector2
var wander_cooldown: float = 0.0
var move_speed: float = 60.0

func _ready() -> void:
	if _icon_textures.is_empty():
		for i in 16:
			var path = "res://assets/tiles/cultivator_%d.png" % i
			if FileAccess.file_exists(path.replace("res://", "")):
				_icon_textures.append(load(path))
			else:
				break
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	_connect_time()
	_update_icon()

func _update_icon() -> void:
	if not _sprite:
		_sprite = Sprite2D.new()
		_sprite.centered = true
		add_child(_sprite)
	if realm < _icon_textures.size():
		_sprite.texture = _icon_textures[realm]

func _draw() -> void:
	if not alive: return
	if is_selected:
		draw_circle(Vector2.ZERO, 72, Color.GOLD, false, 2)
	if blessed_ticks > 0:
		draw_circle(Vector2.ZERO, 68, Color.GOLD, false, 1)
	if cursed_ticks > 0:
		draw_circle(Vector2.ZERO, 68, Color.RED, false, 1)
		draw_circle(Vector2.ZERO, 9, Color.BLACK, false, 2)

func setup(p_name: String, p_realm: int, p_age: int) -> void:
	cultivator_name = p_name
	realm = p_realm
	age = p_age
	_generate_attributes()
	cultivation_exp = randf_range(0, EXP_TO_NEXT[realm] * 0.3) if EXP_TO_NEXT[realm] > 0 else 3000.0
	_update_icon()
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
		if tech["type"] == 0:  # TechType.CULT
			mult *= (1.0 + tech["grade"] * 0.15)
	# 受伤减速
	if injured_ticks > 0:
		mult *= 0.1
	# 培元丹
	if pill_qi_ticks > 0:
		mult *= 1.10
	return mult

func _on_tick(_year: int, _season: int) -> void:
	if not alive: return
	if in_tribulation: return
	if realm >= Realm.TRIBULATION: return
	
	# === 宗门俸禄（每年第一季） ===
	if _season == 0 and sect != "":
		var salary: int = realm + 1 + randi_range(0, 4)
		spirit_stones += salary
	
	# === 灵石兑换 ===
	_try_exchange()
	
	# === 同宗关系自然增长 ===
	if sect != "":
		var spawner = get_parent()
		if spawner:
			for other in spawner.get_children():
				if other == self: continue
				if other.get("sect") == sect:
					_mod_relation(other, 0.5)
	
	# === 丹药自动使用 ===
	if injured_ticks > 0 and inventory.get("pill_heal", 0) > 0:
		inventory["pill_heal"] -= 1
		var heal_amt: int = 7 if talent == Talent.ALCHEMIST else 5
		injured_ticks = maxi(0, injured_ticks - heal_amt)
		_add_event("服疗伤丹")
	if pill_qi_ticks <= 0 and inventory.get("pill_qi", 0) > 0:
		inventory["pill_qi"] -= 1
		pill_qi_ticks = 10
		_add_event("服培元丹")
	if pill_qi_ticks > 0:
		pill_qi_ticks -= 1
	if not pill_life_used and inventory.get("pill_life", 0) > 0:
		inventory["pill_life"] -= 1
		pill_life_used = true
		life_bonus += 50
		_add_event("服延寿丹，寿元+50")
	
	_tick_learning()
	
	# === 奇遇倒计时 ===
	if is_in_encounter and encounter_timer > 0:
		encounter_timer -= 1
		if encounter_timer <= 0:
			var em = get_node_or_null("/root/EncounterManager")
			if em: em.finish_encounter(self)
	
	if injured_ticks > 0:
		injured_ticks -= 1
		if _is_at_capital() or _is_at_sect():
			injured_ticks = maxi(0, injured_ticks - 1)
		if talent == Talent.TENACIOUS:
			injured_ticks = maxi(0, injured_ticks - 1)
	
	var speed_mult: float = 1.0
	if blessed_ticks > 0:
		speed_mult = 2.5
		blessed_ticks -= 1
	if cursed_ticks > 0:
		speed_mult = 0.3
		cursed_ticks -= 1
		if randf() < 0.05:
			die(true, "被诅咒而死")
	
	if is_breaking_through:
		breakthrough_progress += 1.0
		if breakthrough_progress >= BREAK_DURATION[realm]:
			_finish_breakthrough()
		return
	
	cultivation_exp += CULT_SPEED[realm] * speed_mult * get_cultivation_mult()
	# 修为上限锁定
	if EXP_TO_NEXT[realm] > 0 and cultivation_exp >= EXP_TO_NEXT[realm]:
		cultivation_exp = EXP_TO_NEXT[realm]
		if not overflow_reported:
			overflow_reported = true
			_add_event("修为溢出")
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
	
	# 高境界必须在同属性圣地
	if realm >= Realm.NASCENT_SOUL:
		var wm = get_node_or_null("/root/main/WorldMap")
		if wm:
			var tx: int = int(position.x / 32.0)
			var ty: int = int(position.y / 32.0)
			if wm.get_spirit_element(tx, ty) != spirit_element or wm.get_spirit_density(tx, ty) < 0.9:
				return  # 不在同属性圣地
	
	# 高境界需要特殊物品
	var item_id: String = BREAK_ITEMS.get(realm, "")
	if item_id != "" and inventory.get(item_id, 0) <= 0:
		var items_data = load("res://scripts/data/items.gd")
		var item_name: String = item_id
		for p in items_data.PILLS + items_data.SPECIALS:
			if p.get("id") == item_id: item_name = p["name"]; break
		ai_goal = "寻求" + item_name
		return  # 缺必备物品
	
	is_breaking_through = true
	breakthrough_progress = 0.0
	cultivation_exp = EXP_TO_NEXT[realm]  # 锁定满值
	# 消耗特殊物品
	if item_id != "":
		inventory[item_id] -= 1
		if inventory[item_id] <= 0: inventory.erase(item_id)
	ai_goal = "闭关中"
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
	if not pill_used_breakthrough:
		match realm:
			Realm.QI_REFINING:
				if inventory.get("pill_build_foundation", 0) > 0:
					inventory["pill_build_foundation"] -= 1
					pill_used_breakthrough = true
					_add_event("服筑基丹")
					success_chance = 1.0
			Realm.FOUNDATION:
				if inventory.get("pill_form_core", 0) > 0:
					inventory["pill_form_core"] -= 1
					pill_bonus = 0.15
					pill_used_breakthrough = true
					_add_event("服结丹丹")
			Realm.GOLDEN_CORE:
				if inventory.get("pill_nascent", 0) > 0:
					inventory["pill_nascent"] -= 1
					pill_bonus = 0.07
					pill_used_breakthrough = true
					_add_event("服婴变丹")
			Realm.NASCENT_SOUL:
				if inventory.get("pill_divine", 0) > 0:
					inventory["pill_divine"] -= 1
					pill_bonus = 0.02
					pill_used_breakthrough = true
					_add_event("服化神丹")
			Realm.DIVINE:
				if inventory.get("pill_trib", 0) > 0:
					inventory["pill_trib"] -= 1
					pill_bonus = 0.02
					pill_used_breakthrough = true
					_add_event("服渡劫丹")
	
	success_chance = clampf(success_chance + pill_bonus, 0.05, 0.95)
	
	var eb = get_node_or_null("/root/EventBus")
	var gt = get_node_or_null("/root/GameTime")
	
	if randf() < success_chance:
		var old_realm: int = realm
		realm += 1
		cultivation_exp = 0.0
		overflow_reported = false
		queue_redraw()
		var hm: int = [5, 10, 20, 50, 100, 200][old_realm]
		if gt: gt.add_hm(hm)
		_add_event("突破至 %s" % REALM_NAMES[realm])
		if eb:
			eb.cultivator_breakthrough.emit(self, old_realm, realm)
			eb.event_log_entry.emit("%s 突破至 %s！" % [cultivator_name, REALM_NAMES[realm]], "cult")
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play_success()
	else:
		cultivation_exp = 0.0
		overflow_reported = false
		_add_event("突破失败")
		# 失败惩罚
		match realm:
			Realm.QI_REFINING:
				pass  # 无损失
			Realm.FOUNDATION:
				pass  # 只掉修为
			Realm.GOLDEN_CORE:
				injured_ticks = 15
			Realm.NASCENT_SOUL:
				injured_ticks = 30
				if randf() < 0.2: die(true, "突破失败"); return
			Realm.DIVINE:
				injured_ticks = 60
				if randf() < 0.5: die(true, "突破失败"); return
		if eb:
			eb.event_log_entry.emit("%s 突破 %s 失败" % [cultivator_name, REALM_NAMES[realm + 1]], "cult")

func _process(delta: float) -> void:
	if not alive: return
	delta *= GameTime.speed_multipliers.get(GameTime.current_speed, 1.0)
	
	# 雷劫中：只做躲避
	if in_tribulation:
		_tribulation_dodge(delta)
		return
	
	if is_breaking_through: return  # 闭关中不移动
	if is_newborn:
		_newborn_ai(delta)
		return
	
	# 奇遇中：原地不动，不被攻击，倒计时
	if is_in_encounter:
		if encounter_timer > 0:
			return
		var em = get_node_or_null("/root/EncounterManager")
		if em: em.finish_encounter(self)
		return
	
	# 领地推斥：非本宗门不可进入
	var push = _territory_push()
	if push != Vector2.ZERO:
		wander_target = position + push * 200.0
		position = position.move_toward(position + push * 50.0, move_speed * 3.0 * delta)
		return
	
	# 雷劫区域排斥
	var tm = get_node_or_null("/root/main/TribulationManager")
	if tm and tm.active and not in_tribulation:
		var d: float = position.distance_to(tm.center)
		if d < tm.radius + 20:
			var away: Vector2 = (position - tm.center).normalized()
			wander_target = tm.center + away * (tm.radius + 60)
			position = position.move_toward(wander_target, move_speed * 3.0 * delta)
			return
	
	# 同宗避让
	if sect != "" and not guided and ai_goal in ["游历", "寻灵修炼", "回宗采购", "前往京城采购", "筹备突破"]:
		var avoid: Vector2 = Vector2.ZERO
		var spawner = get_parent()
		if spawner:
			for other in spawner.get_children():
				if other == self: continue
				if other.get("sect") != sect: continue
				var d: float = position.distance_to(other.position)
				if d < 80 and d > 0.01:
					avoid += (position - other.position).normalized() / maxf(d, 1.0)
		if avoid.length() > 0.01:
			wander_target = position + avoid.normalized() * 80.0
			wander_cooldown = randf_range(1.0, 3.0)
			position = position.move_toward(wander_target, move_speed * 2.0 * delta)
			return
	
	wander_cooldown -= delta
	if wander_cooldown <= 0.0:
		_decide_behavior()
	# 经过墓碑时拾取
	_try_loot_tombstone()
	if position.distance_to(wander_target) > 4.0:
		position = position.move_toward(wander_target, move_speed * delta)
	elif guided:
		# 指引到达，恢复自主行动
		guided = false
		wander_cooldown = 0.0
		ai_goal = "游历"

func _newborn_ai(delta: float) -> void:
	if newborn_target_sect != "":
		ai_goal = "前往" + newborn_target_sect
		var sp = _find_sect_by_name(newborn_target_sect)
		if sp:
			if position.distance_to(sp) < 48.0:
				# 到达宗门，入籍
				sect = newborn_target_sect
				is_newborn = false
				ai_goal = "游历"
				life_events.append({"year": GameTime.current_year, "text": "加入" + sect, "realm": REALM_NAMES[realm]})
				# 更新宗门人数
				var sn = _find_sect_node_by_name(sect)
				if sn:
					var mc: int = sn.get("member_count")
					sn.set("member_count", mc + 1)
				return
			position = position.move_toward(sp, move_speed * 2.0 * delta)
		return
	# 散修：京城附近转几圈
	var cp = _find_capital_pos()
	if cp:
		ai_goal = "新生游历"
		if position.distance_to(cp) < 120.0:
			# 近处随机走
			wander_cooldown -= delta
			if wander_cooldown <= 0.0:
				wander_target = cp + Vector2(randf_range(-100, 100), randf_range(-100, 100))
				wander_target.x = clampf(wander_target.x, 16, 12784)
				wander_target.y = clampf(wander_target.y, 16, 12784)
				wander_cooldown = randf_range(1.0, 3.0)
			if position.distance_to(wander_target) > 4.0:
				position = position.move_toward(wander_target, move_speed * delta)
		else:
			position = position.move_toward(cp, move_speed * delta)
	# 几个季度后自动去掉新生标记
	if GameTime.current_season >= 2:
		is_newborn = false
		ai_goal = "游历"

func _decide_behavior() -> void:
	# 1. 逃命
	if injured_ticks > 0:
		var danger = _find_nearby_threat()
		if danger:
			ai_goal = "逃命"
			_flee_from(danger)
			return
	
	# 2. 疗伤（先治再突破）
	if injured_ticks > 0:
		if sect != "":
			ai_goal = "回宗养伤"
			var sect_pos = _find_sect_pos()
			if sect_pos:
				wander_target = sect_pos
				wander_cooldown = randf_range(3.0, 5.0)
				return
		else:
			ai_goal = "前往京城"
			var cap_pos = _find_capital_pos()
			if cap_pos:
				wander_target = cap_pos
				wander_cooldown = randf_range(3.0, 5.0)
				return
	
	# 3. 闭关
	if _can_breakthrough_now():
		ai_goal = "准备闭关"
		_attempt_breakthrough()
		wander_cooldown = 99.0
		return
	
	# 4. 缺必备物品（高境界突破需要灵髓/破界石，只能奇遇获取）
	if cultivation_exp >= EXP_TO_NEXT[realm]:
		var item_id: String = BREAK_ITEMS.get(realm, "")
		if item_id != "" and inventory.get(item_id, 0) <= 0:
			var items_data = load("res://scripts/data/items.gd")
			var item_name: String = item_id
			for p in items_data.PILLS + items_data.SPECIALS:
				if p.get("id") == item_id: item_name = p["name"]; break
			ai_goal = "寻求" + item_name
			# 优先去最近的奇遇点
			if _try_go_encounter(): return
			_pick_wander_target()
			return
	
	# 5. 前往奇遇
	if injured_ticks <= 0 and _try_go_encounter():
		return
	
	# 6. 筹备
	if cultivation_exp >= EXP_TO_NEXT[realm]:
		ai_goal = "筹备突破"
		var target = _find_breakthrough_prep_target()
		if target:
			wander_target = target
			wander_cooldown = randf_range(2.0, 4.0)
			return
	
	# 7. 寻灵
	if cultivation_exp < EXP_TO_NEXT[realm]:
		ai_goal = "寻灵修炼"
		var spirit_target = _find_high_spirit()
		if spirit_target:
			wander_target = spirit_target
			wander_cooldown = randf_range(2.0, 4.0)
			return
	
	# 7. 购物
	if spirit_stones >= 10 and randf() < 0.15 and injured_ticks <= 0:
		if sect != "":
			ai_goal = "回宗采购"
			var sect_pos = _find_sect_pos()
			if sect_pos:
				wander_target = sect_pos
				wander_cooldown = randf_range(3.0, 6.0)
				return
		else:
			ai_goal = "前往京城采购"
			var cap_pos = _find_capital_pos()
			if cap_pos:
				wander_target = cap_pos
				wander_cooldown = randf_range(3.0, 6.0)
				return
	
	# 8. 游历
	ai_goal = "游历"
	if sect != "" and randf() < 0.6:
		var sect_pos = _find_sect_pos()
		if sect_pos:
			wander_target = sect_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80))
			wander_target.x = clampf(wander_target.x, 16, 12784)
			wander_target.y = clampf(wander_target.y, 16, 12784)
			wander_cooldown = randf_range(3.0, 6.0)
			return
	
	_pick_wander_target()

func _can_breakthrough_now() -> bool:
	if realm >= Realm.TRIBULATION: return false
	if cultivation_exp < EXP_TO_NEXT[realm]: return false
	var required: float = BREAK_SPIRIT[realm]
	var wm = get_node_or_null("/root/main/WorldMap")
	if not wm: return false
	var tx: int = int(position.x / 32.0)
	var ty: int = int(position.y / 32.0)
	if wm.get_spirit_density(tx, ty) < required: return false
	# 高境界需在同属性圣地
	if realm >= Realm.NASCENT_SOUL:
		if wm.get_spirit_element(tx, ty) != spirit_element or wm.get_spirit_density(tx, ty) < 0.9:
			return false
	# 检查特殊物品
	var item_id: String = BREAK_ITEMS.get(realm, "")
	if item_id != "" and inventory.get(item_id, 0) <= 0: return false
	# 谨慎天赋：必须有对应丹药才突破
	if talent == Talent.CAUTIOUS and not pill_used_breakthrough:
		# 检查是否有对应丹药
		var has_pill: bool = false
		match realm:
			Realm.QI_REFINING: has_pill = inventory.get("pill_build_foundation", 0) > 0
			Realm.FOUNDATION: has_pill = inventory.get("pill_form_core", 0) > 0
			Realm.GOLDEN_CORE: has_pill = inventory.get("pill_nascent", 0) > 0
			Realm.NASCENT_SOUL: has_pill = inventory.get("pill_divine", 0) > 0
			Realm.DIVINE: has_pill = inventory.get("pill_trib", 0) > 0
		if not has_pill: return false
	return true

func _find_nearby_threat():
	var spawner = get_parent()
	if not spawner: return null
	for other in spawner.get_children():
		if other == self: continue
		if not other.get("alive"): continue
		if other.get("realm") == null: continue
		if position.distance_to(other.position) > 120: continue
		if other.get_combat_power() > get_combat_power():
			return other
	return null

func _flee_from(threat) -> void:
	var dir: Vector2 = position - threat.position
	if dir.length() < 1: dir = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	dir = dir.normalized()
	wander_target = position + dir * 200.0
	wander_target.x = clampf(wander_target.x, 16, 12784)
	wander_target.y = clampf(wander_target.y, 16, 12784)
	wander_cooldown = randf_range(1.0, 2.0)

func _find_breakthrough_prep_target():
	var wm = get_node_or_null("/root/main/WorldMap")
	if not wm: return null
	var required: float = BREAK_SPIRIT[realm]
	var map_w: int = wm.MAP_WIDTH if wm.get("MAP_WIDTH") else 400
	var map_h: int = wm.MAP_HEIGHT if wm.get("MAP_HEIGHT") else 400
	var need_sacred: bool = realm >= Realm.NASCENT_SOUL
	
	var best_score: float = -1.0
	var best_pos: Vector2
	for _try in 50:
		var x: int = randi_range(1, map_w - 2)
		var y: int = randi_range(1, map_h - 2)
		var d: float = wm.get_spirit_density(x, y)
		var e: int = wm.get_spirit_element(x, y)
		var dist: float = position.distance_to(Vector2(x * 32, y * 32))
		# 高境界优先同属性圣地
		var score: float = d - dist / 12800.0
		if need_sacred:
			if e != spirit_element or d < 0.9: continue  # 非同属性圣地跳过
			score = 1000.0 - dist  # 直奔最近同属性圣地
		if score > best_score:
			best_score = score
			best_pos = Vector2(x * 32 + 16, y * 32 + 16)
	if best_score > 0: return best_pos
	return null

func _try_go_encounter() -> bool:
	if is_newborn: return false
	var em = get_node_or_null("/root/EncounterManager")
	if not em: return false
	var dist: int = 2 if talent == Talent.EXPLORER else 1
	var enc: Dictionary = em.check_nearby_range(position, dist)
	if enc.is_empty(): return false
	if not em.try_enter(self, enc): return false
	wander_target = Vector2(enc["grid_x"] * 32 + 16, enc["grid_y"] * 32 + 16)
	ai_goal = "前往奇遇"
	return true

func _find_sect_pos():
	var spawner = get_parent()
	if not spawner: return null
	for node in spawner.get_children():
		if node.get("sect_name") == sect:
			return node.position
	return null

func _find_sect_node_by_name(sn: String):
	var spawner = get_parent()
	if not spawner: return null
	for node in spawner.get_children():
		if node.get("sect_name") == sn:
			return node
	return null

func _find_sect_by_name(sn: String):
	var spawner = get_parent()
	if not spawner: return null
	for node in spawner.get_children():
		if node.get("sect_name") == sn:
			return node.position
	return null

func _territory_push() -> Vector2:
	if sect == "" or is_newborn: return Vector2.ZERO
	var spawner = get_parent()
	if not spawner: return Vector2.ZERO
	var push_dir: Vector2 = Vector2.ZERO
	for node in spawner.get_children():
		if not node.get("sect_name"): continue
		if node.get("is_capital"): continue  # 京城可以进
		if node.get("sect_name") == sect: continue  # 自己宗门
		var dist: float = position.distance_to(node.position)
		var r: int = node.get("territory_radius")
		if dist < r * 32:
			return (position - node.position).normalized()
	return Vector2.ZERO

func _inside_capital() -> bool:
	var cp = _find_capital_pos()
	return cp != null and position.distance_to(cp) < 480.0  # 京城领地15格

func _find_capital_pos():
	var spawner = get_parent()
	if not spawner: return null
	for node in spawner.get_children():
		if node.get("is_capital"):
			return node.position
	return null

func _is_at_capital() -> bool:
	var cp = _find_capital_pos()
	return cp != null and position.distance_to(cp) < 80.0

func _is_at_sect() -> bool:
	var sp = _find_sect_pos()
	return sp != null and position.distance_to(sp) < 80.0

func _find_high_spirit():
	var wm = get_node_or_null("/root/main/WorldMap")
	if not wm: return null
	var best_d: float = -1.0
	var best_pos: Vector2
	var map_w: int = wm.MAP_WIDTH if wm.get("MAP_WIDTH") else 400
	var map_h: int = wm.MAP_HEIGHT if wm.get("MAP_HEIGHT") else 400
	for _try in 20:
		var ox: float = randf_range(-80, 80)
		var oy: float = randf_range(-80, 80)
		var tx: int = int((position.x + ox) / 32.0)
		var ty: int = int((position.y + oy) / 32.0)
		tx = clampi(tx, 1, map_w - 2)
		ty = clampi(ty, 1, map_h - 2)
		var d: float = wm.get_spirit_density(tx, ty)
		# 未受伤时避开零灵气区（京城）
		if d <= 0.01 and injured_ticks <= 0: continue
		if d > best_d:
			best_d = d
			best_pos = Vector2(tx * 32 + 16, ty * 32 + 16)
	if best_pos: return best_pos
	return null

func _pick_wander_target() -> void:
	for _try in 10:
		wander_target = position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
		wander_target.x = clampf(wander_target.x, 16, 12784)
		wander_target.y = clampf(wander_target.y, 16, 12784)
		# 未受伤时避开京城零灵气区
		if injured_ticks > 0: break
		var cp = _find_capital_pos()
		if cp and wander_target.distance_to(cp) < 480: continue
		break
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

func tribulation_strike() -> bool:
	"""天道雷劫惩罚。返回 true = 存活, false = 死亡"""
	var survival_chance: float = 0.7
	
	# 境界加成 (每境界+5%，渡劫期额外+30%)
	survival_chance += realm * 0.05
	if realm == Realm.TRIBULATION:
		survival_chance += 0.30
	
	# 根骨加成 (每10点+2%)
	survival_chance += (root_bone - 50) * 0.002
	
	# 气运加成 (每20点+3%)
	survival_chance += fortune * 0.0015
	
	# 赐福/诅咒影响
	if blessed_ticks > 0:
		survival_chance += 0.15
	if cursed_ticks > 0:
		survival_chance -= 0.20
	
	survival_chance = clampf(survival_chance, 0.05, 0.95)
	
	var survived: bool = randf() < survival_chance
	
	if survived:
		injured_ticks = maxi(injured_ticks, 30)
		cultivation_exp = maxf(0, cultivation_exp * 0.7)
		_add_event("扛过天道雷劫")
		queue_redraw()
	else:
		_add_event("死于天道雷劫")
	
	return survived

# --- 关系 ---
func _get_relation(other: Node) -> float:
	return relations.get(other.get("cultivator_name"), 0.0)

func _mod_relation(other: Node, delta: float) -> void:
	var name: String = other.get("cultivator_name")
	var cur: float = relations.get(name, 0.0)
	if talent == Talent.SLAYER: delta *= 2.0
	if talent == Talent.LONER: delta *= 0.5
	relations[name] = clampf(cur + delta, -100.0, 100.0)

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
	# 受伤惩罚
	if injured_ticks > 25:
		base *= 0.15
	elif injured_ticks > 10:
		base *= 0.4
	elif injured_ticks > 0:
		base *= 0.7
	if talent == Talent.WAR_GOD: base *= 1.25
	return base

func perceive_combat_power() -> float:
	"""外人看到的战力：±15% 误差"""
	var real: float = get_combat_power()
	return real * randf_range(0.85, 1.15)

func _tick_learning() -> void:
	if not _tech_loaded:
		var item_data = load("res://scripts/data/items.gd").new()
		for t in item_data.TECHNIQUES:
			_tech_cache[t["id"]] = t
		item_data.queue_free()
		_tech_loaded = true
	
	# 没在学 → 挑一本能学的书开始学
	if learn_book == "":
		for key in inventory:
			if not key.begins_with("tech_"): continue
			if inventory[key] <= 0: continue
			var tech: Dictionary = _tech_cache.get(key, {})
			if tech.is_empty(): continue
			var g: int = tech.get("grade", 0)
			if spirit_root < g: continue  # 灵根不足
			# 检查是否已学会
			var known: bool = false
			for t in techniques:
				if t.get("id") == key: known = true; break
			if known: continue
			# 开始学（书暂时保留）
			learn_book = key
			learn_progress = 0.0
			break
		if learn_book == "": return
	
	var tech: Dictionary = _tech_cache.get(learn_book, {})
	if tech.is_empty(): 
		learn_book = ""; return
	# 书丢了就停学
	if inventory.get(learn_book, 0) <= 0:
		learn_book = ""; return
	
	var grade: int = tech.get("grade", 0)
	if spirit_root < grade:
		learn_book = ""; return  # 灵根变了，放弃
	
	# 悟性决定速度：每季 progress
	var speed: float = comprehension / 800.0  # 100悟性→每季 0.125
	speed /= (1.0 + grade * 0.5)  # 品级越高越慢
	if randf() < fortune / 200.0: speed *= 2.0  # 气运偶尔悟道
	if talent == Talent.SKY_WISDOM: speed *= 2.0
	learn_progress += speed
	if learn_progress >= 1.0:
		# 学成！消耗功法书，获得功法
		inventory[learn_book] = inventory.get(learn_book, 1) - 1
		if inventory[learn_book] <= 0: inventory.erase(learn_book)
		techniques.append(tech.duplicate())
		_add_event("学会%s" % tech["name"])
		learn_book = ""
		learn_progress = 0.0

func _try_exchange() -> void:
	if spirit_stones < 5: return
	# 只有宗门成员在宗门，或任何人在京城才能兑换
	var near_shop: bool = false
	if _is_at_capital(): near_shop = true
	if sect != "" and _is_at_sect(): near_shop = true
	if not near_shop: return
	if randf() > (0.4 if talent == Talent.GREEDY else 0.3): return
	
	# 随机挑一件可买物品
	var items_data = load("res://scripts/data/items.gd")
	var shop: Array = []
	# 不可兑换：化神丹/渡劫丹/地阶天阶功法
	var banned: Array[String] = ["pill_divine","pill_trib","tech_cult_earth","tech_cult_heaven","tech_combat_earth","tech_combat_heaven"]
	var pill_price: Dictionary = {
		"pill_qi": 5, "pill_build_foundation": 20, "pill_form_core": 30,
		"pill_nascent": 50, "pill_heal": 8, "pill_life": 100,
	}
	for p in items_data.PILLS:
		if p["id"] in banned: continue
		var pr: int = pill_price.get(p["id"], 10)
		shop.append({"id": p["id"], "name": p["name"], "price": pr})
	for t in items_data.TECHNIQUES:
		if t["id"] in banned: continue
		var grade: int = t.get("grade", 0)
		shop.append({"id": t["id"], "name": "书·" + t["name"], "price": (grade + 1) * 10 + grade * grade * 10})
	# 战斗符（很贵）
	for ci in items_data.COMBAT_ITEMS:
		var price: int = 80 if ci["id"] in ["cb_shield","cb_escape"] else 120
		shop.append({"id": ci["id"], "name": ci["name"], "price": price})
	
	var item: Dictionary = shop.pick_random()
	if item["price"] > spirit_stones: return
	if randf() > 0.4: return  # 40%有货，60%缺货
	
	spirit_stones -= item["price"]
	inventory[item["id"]] = inventory.get(item["id"], 0) + 1
	_add_event("购得%s(%d灵石)" % [item["name"], item["price"]])

func _check_combat() -> void:
	if in_tribulation: return
	if combat_cooldown > 0:
		combat_cooldown -= 1
		return
	if _inside_capital(): return
	var spawner = get_parent()
	if not spawner: return
	var eb = get_node_or_null("/root/EventBus")
	
	var all_cults: Array = []
	for child in spawner.get_children():
		if child == self: continue
		if child.get("realm") == null: continue
		if not child.get("alive"): continue
		if child.get("is_newborn") or is_newborn: continue
		if child.get("is_in_encounter") or is_in_encounter: continue
		all_cults.append(child)
	
	# 优先找仇人（关系 ≤ -30）
	var target: Node = null
	for other in all_cults:
		if position.distance_to(other.position) > 60: continue
		if sect != "" and sect == other.get("sect"): continue
		if _get_relation(other) <= -30:
			target = other
			break
	# 没仇人找弱者（贵重物品更诱人，战力有迷雾）
	if not target:
		var best_score: float = 999.0
		for other in all_cults:
			if position.distance_to(other.position) > 60: continue
			if sect != "" and sect == other.get("sect"): continue
			var r: float = other.perceive_combat_power() / maxf(perceive_combat_power(), 1.0)
			# 贵重物品加重攻击倾向
			var loot_score: float = 0.0
			var inv = other.get("inventory")
			if inv == null: inv = {}
			for key in inv:
				if key.begins_with("spec_"): loot_score += 0.5
				elif key.begins_with("tech_cult_earth") or key.begins_with("tech_combat_earth"): loot_score += 0.3
				elif key.begins_with("tech_cult_heaven") or key.begins_with("tech_combat_heaven"): loot_score += 0.4
			var ss = other.get("spirit_stones"); loot_score += (ss if ss != null else 0) * 0.002
			r -= loot_score  # 越诱人 r 越小，越优先打
			if r < best_score:
				best_score = r
				target = other
	if not target: return  # 没可打的
	if perceive_combat_power() <= target.perceive_combat_power() and inventory.get("cb_escape", 0) <= 0:
		return  # 打不过且无疾风符
	
	# 性格影响动手概率
	if randf() > PERSONALITY_FIGHT_CHANCE[personality]:
		return
	
	# === 组建阵营 ===
	var side_a: Array = [self]  # 我方
	var side_b: Array = [target]  # 敌方
	for other in all_cults:
		if other == target: continue
		if position.distance_to(target.position) > 80: continue
		if other.get("injured_ticks") > 10: continue  # 重伤不能帮忙
		# 对方对我的看法
		var their_rel_to_me: float = 0.0
		var their_rel_to_target: float = 0.0
		var rels = other.get("relations")
		if rels != null:
			their_rel_to_me = rels.get(cultivator_name, 0.0)
			their_rel_to_target = rels.get(target.cultivator_name, 0.0)
		if their_rel_to_me >= 40 and their_rel_to_target < 40:
			side_a.append(other)
		elif their_rel_to_target >= 40 and their_rel_to_me < 40:
			side_b.append(other)
	
	# 全员取消指引
	for c in side_a: c.set("guided", false)
	for c in side_b: c.set("guided", false)
	
	# 战力汇总
	var power_a: float = 0.0
	var power_b: float = 0.0
	for c in side_a:
		power_a += c.get_combat_power()
		# 战斗物品
		if c.get("inventory").get("cb_fire", 0) > 0:
			c.get("inventory")["cb_fire"] -= 1; power_a += 40
		if c.get("inventory").get("cb_fatal", 0) > 0:
			c.get("inventory")["cb_fatal"] -= 1; power_a *= 1.2
	for c in side_b:
		power_b += c.get_combat_power()
		if c.get("inventory").get("cb_fire", 0) > 0:
			c.get("inventory")["cb_fire"] -= 1; power_b += 40
	
	if power_a <= power_b and inventory.get("cb_escape", 0) <= 0:
		return  # 打不过
	
	var ratio: float = (power_a - power_b) / maxf(power_a, 1.0)
	
	if ratio > 0.5:
		# 斩杀
		for c in side_b:
			var op: Dictionary = c.get("inventory")
			if op:
				for key in op:
					if key.begins_with("cb_"): continue
					if op[key] > 0:
						inventory[key] = inventory.get(key, 0) + op[key]
			c.die(false, "被斩杀")  # 斩杀：不留物品
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_kill()
			_mod_relation(c, -25)
		for c in side_a:
			if c != self:
				c._mod_relation(target, -15)
		if eb: eb.event_log_entry.emit("%s一方 %d人 斩杀 %s一方 %d人" % [cultivator_name, side_a.size(), target.cultivator_name, side_b.size()], "fight")
	elif ratio > 0.2:
		# 重伤
		for c in side_b:
			c.set("losses", c.get("losses") + 1)
			c.set("injured_ticks", 40)
			c.combat_cooldown = 10.0
			_mod_relation(c, -20)
		if eb: eb.event_log_entry.emit("%s一方 重伤 %s一方" % [cultivator_name, target.cultivator_name], "fight")
	else:
		# 击退
		for c in side_b:
			c.set("losses", c.get("losses") + 1)
			c.set("injured_ticks", 8)
			c.combat_cooldown = 8.0
			_mod_relation(c, -20)
		if eb: eb.event_log_entry.emit("%s一方 击退 %s一方" % [cultivator_name, target.cultivator_name], "fight")
	
	# 战友加好感
	for c in side_a:
		if c != self:
			_mod_relation(c, 5.0)
	
	combat_cooldown = 5.0
	for c in side_a:
		if c != self:
			c.combat_cooldown = 5.0

func die(keep_items: bool = true, cause: String = "陨落") -> void:
	_add_event(cause)
	# 替死符
	if inventory.get("替死符", 0) > 0:
		inventory["替死符"] -= 1
		injured_ticks = 15
		var eb2 = get_node_or_null("/root/EventBus")
		if eb2:
			eb2.event_log_entry.emit("%s 消耗替死符躲过死劫" % cultivator_name, "item")
		return
	
	alive = false
	visible = false
	# 造墓碑
	var ts = Node2D.new()
	ts.set_script(load("res://scripts/entities/tombstone.gd"))
	ts.position = position
	ts.name = "Tombstone_" + cultivator_name
	_copy_to_tombstone(ts, keep_items, cause)
	var spawner = get_parent()
	if spawner: spawner.add_child(ts)
	
	var gt = get_node_or_null("/root/GameTime")
	if gt: gt.add_hm((realm + 1) * 3)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.cultivator_died.emit(self)
		eb.event_log_entry.emit("%s 陨落" % cultivator_name, "fight")
	queue_free()

func _copy_to_tombstone(ts: Node, keep_items: bool, cause: String) -> void:
	ts.set("cultivator_name", cultivator_name)
	ts.set("realm", realm)
	ts.set("age", age)
	ts.set("personality", personality)
	ts.set("talent", talent)
	ts.set("sect", sect)
	ts.set("wins", wins)
	ts.set("losses", losses)
	ts.set("spirit_root", spirit_root)
	ts.set("spirit_element", spirit_element)
	ts.set("root_bone", root_bone)
	ts.set("comprehension", comprehension)
	ts.set("fortune", fortune)
	ts.set("life_events", life_events.duplicate(true))
	ts.set("techniques", techniques.duplicate(true))
	ts.set("death_year", GameTime.current_year if get_node_or_null("/root/GameTime") else 0)
	ts.set("death_cause", cause)
	if keep_items:
		ts.set("inventory", inventory.duplicate(true))
		ts.set("spirit_stones", spirit_stones)

func _tribulation_dodge(delta: float) -> void:
	"""雷劫中躲避天雷"""
	var tm = get_node_or_null("/root/main/TribulationManager")
	if not tm or not tm.active: 
		in_tribulation = false; return
	# 境界越高移动越快（雷劫中拼命逃）
	var trib_speed: float = move_speed * (2.0 + realm * 0.5)  # 2~4.5倍
	var nearest: Vector2 = Vector2.ZERO
	var nearest_dist: float = 999.0
	for w in tm._warnings:
		var d: float = position.distance_to(w["pos"])
		if d < nearest_dist:
			nearest_dist = d; nearest = w["pos"]
	if nearest_dist < 120:
		var away: Vector2 = (position - nearest).normalized()
		position = position.move_toward(position + away * 80, trib_speed * delta)
	# 保持圈内
	var dist_to_center: float = position.distance_to(tm.center)
	if dist_to_center > tm.radius - 20:
		position = position.move_toward(tm.center, trib_speed * delta)

func _try_loot_tombstone() -> void:
	if _loot_cooldown > 0:
		_loot_cooldown -= 0.016  # ~60fps, 1秒冷却
		return
	var spawner = get_parent()
	if not spawner: return
	for child in spawner.get_children():
		if not child.has_method("try_loot"): continue
		if position.distance_to(child.position) > 80: continue
		if randf() > 0.5: return
		var loot = child.try_loot()
		if loot.is_empty(): return
		_loot_cooldown = 2.0
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play_loot()
		if loot.has("stones"):
			spirit_stones += loot["stones"]
			var eb = get_node_or_null("/root/EventBus")
			if eb: eb.event_log_entry.emit("%s 从墓碑拾取%d灵石" % [cultivator_name, loot["stones"]], "cult")
		elif loot.has("item"):
			var item_id: String = loot["item"]
			inventory[item_id] = inventory.get(item_id, 0) + 1
			var items_data = load("res://scripts/data/items.gd")
			var item_name: String = item_id
			for p in items_data.PILLS + items_data.TECHNIQUES + items_data.SPECIALS + items_data.COMBAT_ITEMS:
				if p["id"] == item_id: item_name = p["name"]; break
			_add_event("墓碑获%s" % item_name)
			var eb = get_node_or_null("/root/EventBus")
			if eb: eb.event_log_entry.emit("%s 从墓碑拾取%s" % [cultivator_name, item_name], "cult")
		return

func _add_event(text: String) -> void:
	var gt = get_node_or_null("/root/GameTime")
	var yr: int = gt.current_year if gt else 0
	life_events.append({"year": yr, "text": text, "realm": REALM_NAMES[realm] if realm < REALM_NAMES.size() else "?"})

func add_stones(amt: int) -> void:
	spirit_stones += amt

func add_item(item_id: String) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + 1
