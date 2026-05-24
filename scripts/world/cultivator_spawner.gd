## cultivator_spawner.gd - 修士生成器（京城出生制）
extends Node

const CULTIVATOR_SCENE: String = "res://scripts/entities/cultivator.gd"
const SPAWN_COUNT: int = 20
const POP_CAP: int = 30
const BIRTH_PER_YEAR: int = 2
const TECH_POOL: Array[String] = ["tech_cult_mortal","tech_cult_yellow","tech_cult_mystic","tech_cult_earth","tech_cult_heaven","tech_combat_mortal","tech_combat_yellow","tech_combat_mystic","tech_combat_earth","tech_combat_heaven"]

var _surnames: Array[String] = [
	"李","王","张","刘","陈","杨","赵","黄","周","吴",
	"徐","孙","胡","朱","高","林","何","郭","马","罗",
	"梁","宋","郑","谢","韩","唐","冯","于","董","萧",
]
var _given_names: Array[String] = [
	"云","风","天","雨","雷","月","星","龙","凤","虎",
	"无极","清扬","子轩","逸尘","凌霄","若云","芷若","追风","破天",
]
var _birth_counter: int = 0

func _ready() -> void:
	var gt = get_node_or_null("/root/GameTime")
	if gt and gt.has_signal("tick_advanced"):
		gt.tick_advanced.connect(_on_tick)

func _on_tick(_year: int, season: int) -> void:
	if season != 0: return  # 每年第一季
	var alive: int = 0
	for child in get_children():
		if child.get("realm") != null and child.get("alive"):
			alive += 1
	if alive >= POP_CAP: return
	
	# 新生儿数：BIRTH_PER_YEAR 但有随机波动
	var count: int = mini(BIRTH_PER_YEAR + randi_range(-1, 1), POP_CAP - alive)
	count = maxi(1, count)
	
	var wm = get_node_or_null("/root/main/WorldMap")
	if not wm or wm.capital_pos.x < 0: return
	
	var spawn_pos: Vector2 = Vector2(wm.capital_pos.x * 32 + 16, wm.capital_pos.y * 32 + 16)
	var sects: Array = []
	for child in get_children():
		if child.get("sect_name") != null and not child.get("is_capital"):
			sects.append(child.get("sect_name"))
	
	for _i in count:
		_birth_counter += 1
		var c = Node2D.new()
		c.set_script(load(CULTIVATOR_SCENE))
		c.name = "Cultivator_B%d" % _birth_counter
		var offset: Vector2 = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		c.position = spawn_pos + offset
		c.setup(_random_name(), _random_realm(), 18)
		c.set("is_newborn", true)
		# 新生儿装备：1~3 颗丹药
		var pool: Array = ["pill_qi","pill_qi","pill_qi","pill_build_foundation","pill_heal","pill_heal","pill_life"]
		var bag: Dictionary = {}
		for _j in randi_range(1, 3):
			var pid: String = pool.pick_random()
			bag[pid] = bag.get(pid, 0) + 1
		c.set("inventory", bag)
		c.set("spirit_stones", randi_range(2, 8))
		c.set("personality", randi() % 3)
		c.set("talent", randi() % 9)
		# 新生儿基本都入宗
		if sects.size() > 0 and randf() < 0.85:
			c.set("newborn_target_sect", sects.pick_random())
		add_child(c)
	
	print("[Spawner] %d 名新生儿" % count)

func spawn_all() -> void:
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm and wm.terrain_map and wm.terrain_map.size() > 0:
		_do_spawn(wm)

func _try_spawn() -> void:
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm and wm.terrain_map and wm.terrain_map.size() > 0:
		_do_spawn(wm)
	else:
		var eb = get_node_or_null("/root/EventBus")
		if eb:
			eb.world_generated.connect(_on_world_generated)

func _on_world_generated() -> void:
	var wm = get_node_or_null("/root/main/WorldMap")
	if wm:
		_do_spawn(wm)

func _do_spawn(wm: Node) -> void:
	_spawn_sects(wm)
	_spawn_capital(wm)
	_spawn_sacred_sites(wm)
	_spawn_cultivators(wm)

func _spawn_cultivators(wm: Node) -> void:
	if wm.capital_pos.x < 0: return
	
	var spawn_pos: Vector2 = Vector2(wm.capital_pos.x * 32 + 16, wm.capital_pos.y * 32 + 16)
	var sects: Array = []
	for child in get_children():
		if child.get("sect_name") != null and not child.get("is_capital"):
			sects.append(child.get("sect_name"))
	
	var rogue_count: int = 2
	var per_sect: int = int(ceil(float(SPAWN_COUNT - rogue_count) / maxi(sects.size(), 1)))
	
	var queue: Array = []
	for sn in sects:
		for _i in per_sect:
			queue.append(sn)
	# 不足凑散修
	while queue.size() < SPAWN_COUNT:
		queue.append("")
	# 保证 rogue 数
	while queue.size() > SPAWN_COUNT:
		queue.remove_at(0)
	
	queue.shuffle()
	
	for i in queue.size():
		var c = Node2D.new()
		c.set_script(load(CULTIVATOR_SCENE))
		c.name = "Cultivator_%d" % i
		# 京城周围随机偏移
		var offset: Vector2 = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		c.position = spawn_pos + offset
		c.setup(_random_name(), _random_realm(), randi_range(18, 200))
		c.set("is_newborn", true)
		# 开局随机丹药 2~5 颗 + 功法书 0~2 本
		var pool: Array = ["pill_qi","pill_qi","pill_qi","pill_build_foundation","pill_form_core","pill_nascent","pill_divine","pill_trib","pill_heal","pill_heal","pill_life"]
		var bag: Dictionary = {}
		for _j in randi_range(2, 5):
			var pid: String = pool.pick_random()
			bag[pid] = bag.get(pid, 0) + 1
		# 随机功法书
		for _j in randi_range(0, 2):
			var tid: String = TECH_POOL.pick_random()
			bag[tid] = bag.get(tid, 0) + 1
		# 随机战斗物品 0~2 个
		var cb_pool: Array[String] = ["cb_fire","cb_shield","cb_escape","cb_fatal"]
		for _j in randi_range(0, 2):
			var cid: String = cb_pool.pick_random()
			bag[cid] = bag.get(cid, 0) + 1
		c.set("inventory", bag)
		c.set("spirit_stones", randi_range(5, 20))
		c.set("personality", randi() % 3)  # 随机性格
		c.set("talent", randi() % 9)        # 随机天赋
		var target: String = queue[i]
		if target != "":
			c.set("newborn_target_sect", target)
		add_child(c)
	
	var sect_count: int = 0
	var rogue: int = 0
	for child in get_children():
		if child.get("realm") == null: continue
		if child.get("newborn_target_sect") != "":
			sect_count += 1
		else:
			rogue += 1
	print("[Spawner] %d 新生儿: %d 入宗, %d 散修" % [queue.size(), sect_count, rogue])

func _spawn_sects(wm: Node) -> void:
	var sect_script = load("res://scripts/entities/sect.gd")
	for i in wm.sect_positions.size():
		var tile_pos: Vector2i = wm.sect_positions[i]
		var world_pos: Vector2 = Vector2(tile_pos.x * 32 + 16, tile_pos.y * 32 + 16)
		var s = Node2D.new()
		s.set_script(sect_script)
		s.name = "Sect_%d" % i
		s.setup(i, world_pos)
		add_child(s)
	print("[Spawner] 生成了 %d 个宗门" % wm.sect_positions.size())

func _spawn_capital(wm: Node) -> void:
	if wm.capital_pos.x < 0: return
	var sect_script = load("res://scripts/entities/sect.gd")
	var world_pos: Vector2 = Vector2(wm.capital_pos.x * 32 + 16, wm.capital_pos.y * 32 + 16)
	var s = Node2D.new()
	s.set_script(sect_script)
	s.name = "Capital"
	s.setup(0, world_pos, "京城", true)
	add_child(s)
	print("[Spawner] 京城: (%d, %d)" % [wm.capital_pos.x, wm.capital_pos.y])

func _spawn_sacred_sites(wm: Node) -> void:
	var ss_script = load("res://scripts/entities/sacred_site.gd")
	for site in wm.sacred_sites:
		var tile_pos: Vector2i = site["pos"]
		var world_pos: Vector2 = Vector2(tile_pos.x * 32 + 16, tile_pos.y * 32 + 16)
		var s = Node2D.new()
		s.set_script(ss_script)
		s.name = "Sacred_%d" % site["element"]
		s.setup(site["element"], site["name"], world_pos)
		add_child(s)
	print("[Spawner] 生成了 %d 个圣地" % wm.sacred_sites.size())

func _random_name() -> String:
	return _surnames.pick_random() + _given_names.pick_random()

func _random_realm() -> int:
	var roll: float = randf()
	if roll < 0.45:   return 0  # 炼气 45%
	if roll < 0.75:   return 1  # 筑基 30%
	if roll < 0.92:   return 2  # 金丹 17%
	if roll < 0.98:   return 3  # 元婴 6%
	return 4                      # 化神 2%
