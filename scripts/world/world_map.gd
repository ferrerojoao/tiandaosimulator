## world_map.gd - 地形生成与 TileMap 渲染
extends TileMap

@onready var tilemap: TileMapLayer = $TileMapLayer

const MAP_WIDTH: int = 200
const MAP_HEIGHT: int = 200
const TILE_SIZE: int = 32

enum Terrain {
	DEEP_WATER=0, SHALLOW_WATER=1, SAND=2, PLAIN=3, GRASSLAND=4,
	FOREST=5, MOUNTAIN=6, HIGH_MOUNTAIN=7, SWAMP=8, SPIRIT_VEIN=9,
	SECT_GROUND=10, VILLAGE=11
}

enum Element { NONE=0, METAL=1, WOOD=2, WATER=3, FIRE=4, EARTH=5 }

const ELEMENT_NAMES: Array = ["无", "金", "木", "水", "火", "土"]
const ELEMENT_COLORS: Array = [
	Color.WHITE, Color.GOLD, Color.GREEN, Color.CYAN, Color.ORANGE_RED, Color.SADDLE_BROWN
]
const TERRAIN_NAMES: Array = ["深海", "浅水", "沙地", "平原", "草原", "森林", "山脉", "高山", "沼泽", "灵脉", "宗门", "村落"]

var terrain_map: Array = []
var spirit_density_map: Array = []
var spirit_element_map: Array = []
var sacred_sites: Array = []  # [{pos: Vector2i, element: int, name: String}]
var sect_positions: Array = []
var village_positions: Array = []
var spirit_vein_positions: Array = []
var height_map: Array = []

var _noise_continent: FastNoiseLite

var _noise_height: FastNoiseLite
var _noise_temp: FastNoiseLite
var _noise_humid: FastNoiseLite
var _noise_spirit: FastNoiseLite
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _world_generated: bool = false

func _ready() -> void:
	_rng.randomize()
	_init_noise()
	# generate_world() 由 main 菜单触发

func _init_noise() -> void:
	_noise_continent = FastNoiseLite.new()
	_noise_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_continent.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_continent.frequency = 0.004
	_noise_continent.fractal_octaves = 3
	_noise_continent.seed = _rng.randi()

	_noise_height = FastNoiseLite.new()
	_noise_height.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_height.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_height.frequency = 0.01
	_noise_height.fractal_octaves = 5
	_noise_height.seed = _rng.randi()

	_noise_temp = FastNoiseLite.new()
	_noise_temp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_temp.frequency = 0.008
	_noise_temp.seed = _rng.randi()

	_noise_humid = FastNoiseLite.new()
	_noise_humid.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_humid.frequency = 0.012
	_noise_humid.seed = _rng.randi()

	_noise_spirit = FastNoiseLite.new()
	_noise_spirit.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_spirit.frequency = 0.025
	_noise_spirit.seed = _rng.randi()

func generate_world() -> void:
	if _world_generated:
		return
	_world_generated = true
	print("[WorldMap] 开始生成世界...")
	_generate_terrain()
	_generate_spirit_maps()
	_place_sects()
	_place_villages()
	_render_tilemap()
	print("[WorldMap] 世界生成完毕")
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.world_generated.emit()
		eb.event_log_entry.emit("世界已生成，灵气充盈大地。", "world")
	var gt = get_node_or_null("/root/GameTime")
	if gt:
		gt.season_changed.connect(_on_season_changed)

func _generate_terrain() -> void:
	terrain_map.clear()
	height_map.clear()
	var continent: Array = []
	for y in MAP_HEIGHT:
		var c_row: Array = []
		var h_row: Array = []
		for x in MAP_WIDTH:
			var c: float = _norm(_noise_continent.get_noise_2d(x, y))
			c_row.append(c > 0.38)
			h_row.append(_norm(_noise_height.get_noise_2d(x, y)))
		continent.append(c_row)
		height_map.append(h_row)
	
	for y in MAP_HEIGHT:
		var row: Array = []
		for x in MAP_WIDTH:
			if not continent[y][x]:
				var c: float = _norm(_noise_continent.get_noise_2d(x, y))
				row.append(Terrain.DEEP_WATER if c < 0.20 else Terrain.SHALLOW_WATER)
			else:
				var h: float = height_map[y][x]
				var s: float = _norm(_noise_spirit.get_noise_2d(x, y))
				var m: float = _norm(_noise_humid.get_noise_2d(x, y))
				var t: float = _norm(_noise_temp.get_noise_2d(x, y))
				row.append(_classify_land(h, m, s, t))
		terrain_map.append(row)
	
	_coast_smooth(2)
	_generate_rivers()

func _generate_rivers() -> void:
	var water: Array = [Terrain.DEEP_WATER, Terrain.SHALLOW_WATER]
	var sources: Array = []
	# 在内陆高处随机找 5-8 个源头
	for _i in 50:
		if sources.size() >= 8: break
		var sx: int = _rng.randi_range(5, MAP_WIDTH - 6)
		var sy: int = _rng.randi_range(5, MAP_HEIGHT - 6)
		var t: int = terrain_map[sy][sx]
		if t in water: continue
		sources.append(Vector2i(sx, sy))
	print("[River] 找到 %d 个源头" % sources.size())
	
	var total_river: int = 0
	for src in sources:
		var cells = _trace_river(src, water)
		total_river += cells.size()
		for v in cells:
			var t: int = terrain_map[v.y][v.x]
			if not t in water and t != Terrain.HIGH_MOUNTAIN and t != Terrain.MOUNTAIN:
				terrain_map[v.y][v.x] = Terrain.SHALLOW_WATER
				# 拓宽：上下左右也变浅水
				for dn in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var wn: Vector2i = v + dn
					if _in_bounds(wn) and not terrain_map[wn.y][wn.x] in water:
						terrain_map[wn.y][wn.x] = Terrain.SHALLOW_WATER

func _trace_river(start: Vector2i, water: Array) -> Array:
	# BFS 找最短路径
	var frontier: Array = [start]
	var came_from: Dictionary = {}
	came_from[start] = Vector2i(-1, -1)
	var end: Vector2i
	
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if terrain_map[cur.y][cur.x] in water:
			end = cur; break
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var nb: Vector2i = Vector2i(cur.x + dx, cur.y + dy)
				if not _in_bounds(nb) or nb in came_from: continue
				came_from[nb] = cur
				frontier.append(nb)
	
	if end == Vector2i(0, 0): return []
	
	# 回溯路径
	var path: Array = []
	var cur: Vector2i = end
	while cur != start and cur in came_from:
		path.append(cur)
		cur = came_from[cur]
	path.append(start)
	path.reverse()
	
	# 中点位移 3 轮，产生蜿蜒
	for _round in 3:
		var curved: Array = []
		for i in path.size() - 1:
			var a: Vector2i = path[i]
			var b: Vector2i = path[i + 1]
			curved.append(a)
			var mid: Vector2i = Vector2i((a.x + b.x) / 2, (a.y + b.y) / 2)
			# 垂直于流向偏移 1~3 格
			var dx: int = b.y - a.y
			var dy: int = -(b.x - a.x)
			var dist: int = abs(dx) + abs(dy)
			if dist > 0:
				var offset: int = randi_range(-3, 3)
				if offset != 0:
					mid.x = clampi(mid.x + round(dx * offset / dist), 0, MAP_WIDTH - 1)
					mid.y = clampi(mid.y + round(dy * offset / dist), 0, MAP_HEIGHT - 1)
			curved.append(mid)
		curved.append(path[path.size() - 1])
		path = curved
	
	return path

func _generate_spirit_maps() -> void:
	spirit_density_map.clear()
	spirit_element_map.clear()
	sacred_sites.clear()
	
	# 灵气浓度：基于灵气噪声 + 地形加成
	var water_t: Array = [Terrain.DEEP_WATER, Terrain.SHALLOW_WATER]
	for y in MAP_HEIGHT:
		var d_row: Array = []
		var e_row: Array = []
		for x in MAP_WIDTH:
			var s: float = _norm(_noise_spirit.get_noise_2d(x, y)) * 1.3
			var t: int = terrain_map[y][x]
			# 地形修正
			if t == Terrain.HIGH_MOUNTAIN: s += 0.2
			elif t == Terrain.MOUNTAIN: s += 0.1
			elif t in water_t: s -= 0.4
			var density: float = clampf(s, 0.0, 1.0)
			d_row.append(density)
			
			# 属性：基于地形默认 + 噪声扰动
			var elem: int = _terrain_element(t)
			if randi() % 3 == 0 and density > 0.3:
				elem = randi_range(1, 5)  # 随机洗牌
			e_row.append(elem)
		spirit_density_map.append(d_row)
		spirit_element_map.append(e_row)
	
	_place_sacred_sites()

func _terrain_element(terrain: int) -> int:
	match terrain:
		Terrain.MOUNTAIN, Terrain.HIGH_MOUNTAIN: return Element.METAL
		Terrain.FOREST, Terrain.GRASSLAND: return Element.WOOD
		Terrain.DEEP_WATER, Terrain.SHALLOW_WATER: return Element.WATER
		Terrain.SAND: return Element.FIRE
		Terrain.SWAMP, Terrain.PLAIN: return Element.EARTH
	return Element.NONE

func _place_sacred_sites() -> void:
	var elem_terrain: Dictionary = {
		Element.METAL: Terrain.MOUNTAIN,
		Element.WOOD: Terrain.FOREST,
		Element.WATER: Terrain.DEEP_WATER,
		Element.FIRE: Terrain.SAND,
		Element.EARTH: Terrain.PLAIN,
	}
	
	for elem in [Element.METAL, Element.WOOD, Element.WATER, Element.FIRE, Element.EARTH]:
		var wanted: int = elem_terrain.get(elem, Terrain.PLAIN)
		var best_pos: Vector2i
		var best_score: float = -1.0
		
		# 阶段1：优先在匹配地形上找
		for _try in 200:
			var x: int = _rng.randi_range(3, MAP_WIDTH - 4)
			var y: int = _rng.randi_range(3, MAP_HEIGHT - 4)
			if terrain_map[y][x] != wanted: continue
			var density: float = spirit_density_map[y][x]
			if density > best_score:
				best_score = density
				best_pos = Vector2i(x, y)
		
		# 阶段2：没找到匹配地形，退到任意陆地高灵区
		if best_pos == Vector2i(0, 0):
			for _try in 300:
				var x: int = _rng.randi_range(3, MAP_WIDTH - 4)
				var y: int = _rng.randi_range(3, MAP_HEIGHT - 4)
				if terrain_map[y][x] in [Terrain.DEEP_WATER, Terrain.SHALLOW_WATER]: continue
				var density: float = spirit_density_map[y][x]
				if density > best_score:
					best_score = density
					best_pos = Vector2i(x, y)
		
		if best_pos == Vector2i(0, 0): continue
		
		spirit_density_map[best_pos.y][best_pos.x] = 1.0
		spirit_element_map[best_pos.y][best_pos.x] = elem
		var replacement: int = wanted
		for dy in [-3, -2, -1, 0, 1, 2, 3]:
			for dx in [-3, -2, -1, 0, 1, 2, 3]:
				var nx: int = best_pos.x + dx
				var ny: int = best_pos.y + dy
				if _in_bounds(Vector2i(nx, ny)):
					terrain_map[ny][nx] = replacement
					spirit_density_map[ny][nx] = 1.0
		sacred_sites.append({
			"pos": best_pos,
			"element": elem,
			"name": ELEMENT_NAMES[elem] + "灵圣地"
		})
	print("[Spirit] %d 处圣地生成完毕" % sacred_sites.size())

func _classify_land(h: float, m: float, s: float, _t: float) -> int:
	if h > 0.80: return Terrain.HIGH_MOUNTAIN
	if h > 0.65: return Terrain.MOUNTAIN
	if h > 0.40 and h < 0.47 and m > 0.55: return Terrain.SWAMP
	if h > 0.35 and h < 0.45 and m < 0.35: return Terrain.SAND
	if h > 0.48 and m > 0.55: return Terrain.FOREST
	if h > 0.42: return Terrain.GRASSLAND
	return Terrain.PLAIN

func _coast_smooth(rounds: int) -> void:
	var water: Array = [Terrain.DEEP_WATER, Terrain.SHALLOW_WATER]
	for _round in rounds:
		var changes: Array = []
		for y in MAP_HEIGHT:
			for x in MAP_WIDTH:
				var t: int = terrain_map[y][x]
				var land: int = 0
				var total: int = 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = x + dx
						var ny: int = y + dy
						if not _in_bounds(Vector2i(nx, ny)): continue
						total += 1
						if not terrain_map[ny][nx] in water:
							land += 1
				if total == 0: continue
				if t in water and land >= 6:
					changes.append([x, y, Terrain.SAND])
				elif not t in water and land <= 3:
					changes.append([x, y, Terrain.SHALLOW_WATER])
		for ch in changes:
			terrain_map[ch[1]][ch[0]] = ch[2]

func _collect_spirit_veins() -> void:
	spirit_vein_positions.clear()
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			if terrain_map[y][x] == Terrain.SPIRIT_VEIN:
				spirit_vein_positions.append(Vector2i(x, y))

func _place_sects() -> void:
	sect_positions.clear()
	var water: Array = [Terrain.DEEP_WATER, Terrain.SHALLOW_WATER]
	var attempts: int = 0
	while sect_positions.size() < 6 and attempts < 2000:
		attempts += 1
		var x: int = _rng.randi_range(5, MAP_WIDTH - 6)
		var y: int = _rng.randi_range(5, MAP_HEIGHT - 6)
		var t: int = terrain_map[y][x]
		if t in water or t == Terrain.HIGH_MOUNTAIN: continue
		if not _far_enough(Vector2i(x, y), sect_positions, 30): continue
		sect_positions.append(Vector2i(x, y))
		terrain_map[y][x] = Terrain.SECT_GROUND

func _place_villages() -> void:
	village_positions.clear()
	var target: int = _rng.randi_range(10, 15)
	var attempts: int = 0
	while village_positions.size() < target and attempts < 5000:
		attempts += 1
		var candidate: Vector2i = Vector2i(_rng.randi_range(0, MAP_WIDTH - 1), _rng.randi_range(0, MAP_HEIGHT - 1))
		var t: int = terrain_map[candidate.y][candidate.x]
		if t != Terrain.PLAIN and t != Terrain.GRASSLAND: continue
		if not _far_enough(candidate, sect_positions, 10): continue
		if not _far_enough(candidate, village_positions, 8): continue
		village_positions.append(candidate)
		terrain_map[candidate.y][candidate.x] = Terrain.VILLAGE

func _render_tilemap() -> void:
	render_tilemap()

func render_tilemap() -> void:
	tilemap.clear()
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			var t: int = terrain_map[y][x]
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))
	print("[WorldMap] 渲染完成: cells=%d" % tilemap.get_used_cells().size())

func _on_season_changed(_year: int, season: int, _name: String) -> void:
	match season:
		0: tilemap.modulate = Color(1.0, 1.0, 1.0, 1.0)
		1: tilemap.modulate = Color(0.92, 1.0, 0.92, 1.0)
		2: tilemap.modulate = Color(1.0, 0.90, 0.75, 1.0)
		3: tilemap.modulate = Color(0.88, 0.93, 1.0, 1.0)

func _norm(v: float) -> float:
	return (v + 1.0) * 0.5

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < MAP_WIDTH and pos.y >= 0 and pos.y < MAP_HEIGHT

func _far_enough(pos: Vector2i, others: Array, min_dist: int) -> bool:
	for other in others:
		if Vector2(pos.x, pos.y).distance_to(Vector2(other.x, other.y)) < min_dist:
			return false
	return true

func get_spirit_density(tile_x: int, tile_y: int) -> float:
	if spirit_density_map.is_empty(): return 0.0
	if tile_y < 0 or tile_y >= spirit_density_map.size(): return 0.0
	if tile_x < 0 or tile_x >= spirit_density_map[tile_y].size(): return 0.0
	return spirit_density_map[tile_y][tile_x]

func get_spirit_element(tile_x: int, tile_y: int) -> int:
	if spirit_element_map.is_empty(): return Element.NONE
	if tile_y < 0 or tile_y >= spirit_element_map.size(): return Element.NONE
	if tile_x < 0 or tile_x >= spirit_element_map[tile_y].size(): return Element.NONE
	return spirit_element_map[tile_y][tile_x]
