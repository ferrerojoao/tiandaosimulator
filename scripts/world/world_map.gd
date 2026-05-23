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

var terrain_map: Array = []
var spirit_qi_map: Array = []
var sect_positions: Array = []
var village_positions: Array = []
var spirit_vein_positions: Array = []

var _noise_height: FastNoiseLite
var _noise_temp: FastNoiseLite
var _noise_humid: FastNoiseLite
var _noise_spirit: FastNoiseLite
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _world_generated: bool = false

func _ready() -> void:
	print("[WorldMap] _ready() 开始")
	_rng.randomize()
	_init_noise()
	generate_world()

func _init_noise() -> void:
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
	_collect_spirit_veins()
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
	for y in MAP_HEIGHT:
		var row: Array = []
		for x in MAP_WIDTH:
			var h: float = _norm(_noise_height.get_noise_2d(x, y))
			var t: float = _norm(_noise_temp.get_noise_2d(x, y))
			var m: float = _norm(_noise_humid.get_noise_2d(x, y))
			var s: float = _norm(_noise_spirit.get_noise_2d(x, y))
			row.append(_classify(h, t, m, s))
		terrain_map.append(row)

func _classify(h: float, _t: float, m: float, s: float) -> int:
	if s > 0.72 and h > 0.35 and h < 0.85:
		return Terrain.SPIRIT_VEIN
	if h < 0.25: return Terrain.DEEP_WATER
	if h < 0.35: return Terrain.SHALLOW_WATER
	if h > 0.85: return Terrain.HIGH_MOUNTAIN
	if h > 0.70: return Terrain.MOUNTAIN
	if h > 0.35 and h < 0.42 and m > 0.55: return Terrain.SWAMP
	if h > 0.35 and h < 0.45 and m < 0.35: return Terrain.SAND
	if h > 0.50 and m > 0.55: return Terrain.FOREST
	if h > 0.45: return Terrain.GRASSLAND
	return Terrain.PLAIN

func _collect_spirit_veins() -> void:
	spirit_vein_positions.clear()
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			if terrain_map[y][x] == Terrain.SPIRIT_VEIN:
				spirit_vein_positions.append(Vector2i(x, y))

func _place_sects() -> void:
	sect_positions.clear()
	if spirit_vein_positions.is_empty():
		return
	var attempts: int = 0
	while sect_positions.size() < 6 and attempts < 2000:
		attempts += 1
		var vein: Vector2i = spirit_vein_positions[_rng.randi_range(0, spirit_vein_positions.size() - 1)]
		var offset_dist: int = _rng.randi_range(3, 8)
		var angle: float = _rng.randf() * TAU
		var candidate: Vector2i = Vector2i(vein.x + int(cos(angle) * offset_dist), vein.y + int(sin(angle) * offset_dist))
		if not _in_bounds(candidate): continue
		var t: int = terrain_map[candidate.y][candidate.x]
		if t == Terrain.DEEP_WATER or t == Terrain.SHALLOW_WATER or t == Terrain.HIGH_MOUNTAIN:
			continue
		if not _far_enough(candidate, sect_positions, 30): continue
		sect_positions.append(candidate)
		terrain_map[candidate.y][candidate.x] = Terrain.SECT_GROUND

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
