## cultivator_spawner.gd - 修士生成器
extends Node

const CULTIVATOR_SCENE: String = "res://scripts/entities/cultivator.gd"
const SPAWN_COUNT: int = 30

var _surnames: Array[String] = [
	"李","王","张","刘","陈","杨","赵","黄","周","吴",
	"徐","孙","胡","朱","高","林","何","郭","马","罗",
	"梁","宋","郑","谢","韩","唐","冯","于","董","萧",
]
var _given_names: Array[String] = [
	"云","风","天","雨","雷","月","星","龙","凤","虎",
	"无极","清扬","子轩","逸尘","凌霄","若云","芷若","追风","破天",
]

func _ready() -> void:
	# 如果世界已生成，直接创建；否则等信号
	call_deferred("_try_spawn")

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
	for i in SPAWN_COUNT:
		var pos = _find_spawn_pos(wm)
		if pos == null: continue
		_spawn_cultivator(pos, i)
	_spawn_sects(wm)
	_assign_to_sects()
	print("[Spawner] 生成完成：%d 修士, %d 宗门" % [SPAWN_COUNT, wm.sect_positions.size()])

func _assign_to_sects() -> void:
	# 收集所有宗门
	var sects: Array = []
	for child in get_children():
		if child.get("sect_name") != null:
			sects.append(child)
	if sects.is_empty(): return
	
	# 为每个修士分配最近宗门
	for child in get_children():
		if child.get("realm") == null: continue
		var best_sect
		var best_dist: float = INF
		for s in sects:
			var d: float = child.position.distance_squared_to(s.position)
			if d < best_dist:
				best_dist = d
				best_sect = s
		if best_sect:
			child.set("sect", best_sect.get("sect_name"))
			best_sect.set("member_count", best_sect.get("member_count") + 1)
	
	for s in sects:
		print("[Spawner] %s: %d 名弟子" % [s.get("sect_name"), s.get("member_count")])

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

func _find_spawn_pos(wm: Node) -> Variant:
	for _attempt in 100:
		var x: int = randi_range(10, 189)
		var y: int = randi_range(10, 189)
		var t: int = wm.terrain_map[y][x]
		# 不在深海/高山生成
		if t == 0 or t == 7: continue
		return Vector2(x * 32 + 16, y * 32 + 16)
	return null

func _spawn_cultivator(pos: Vector2, index: int) -> void:
	var c = Node2D.new()
	c.set_script(load(CULTIVATOR_SCENE))
	c.name = "Cultivator_%d" % index
	c.position = pos
	c.setup(
		_random_name(),
		_random_realm(),
		randi_range(18, 200)
	)
	add_child(c)

func _random_name() -> String:
	return _surnames.pick_random() + _given_names.pick_random()

func _random_realm() -> int:
	var roll: float = randf()
	if roll < 0.40:   return 0  # 凡人 40%
	if roll < 0.70:   return 1  # 炼气 30%
	if roll < 0.88:   return 2  # 筑基 18%
	if roll < 0.96:   return 3  # 金丹 8%
	if roll < 0.99:   return 4  # 元婴 3%
	return 5                      # 化神 1%
