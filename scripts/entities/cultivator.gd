## cultivator.gd - 修士实体
extends Node2D

enum Realm { MORTAL, QI_REFINING, FOUNDATION, GOLDEN_CORE, NASCENT_SOUL, DIVINE }

const REALM_NAMES: Array[String] = ["凡人", "炼气", "筑基", "金丹", "元婴", "化神"]
const REALM_COLORS: Array[Color] = [
	Color.WHITE, Color.LIGHT_BLUE, Color.CYAN,
	Color.YELLOW, Color.ORANGE, Color.RED,
]
const CULT_SPEED: Array[float] = [1.0, 2.0, 5.0, 10.0, 20.0, 40.0]
const EXP_TO_NEXT: Array[float] = [50.0, 100.0, 250.0, 500.0, 1000.0, -1.0]

var cultivator_name: String
var realm: int = Realm.MORTAL
var age: int = 18
var cultivation_exp: float = 0.0
var alive: bool = true
var is_selected: bool = false
var sect: String = ""

# 战斗
var combat_cooldown: float = 0.0
var wins: int = 0
var losses: int = 0

# 天道干预
var blessed_ticks: int = 0
var cursed_ticks: int = 0

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
	# 祝福/诅咒光环
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
	cultivation_exp = randf_range(0, EXP_TO_NEXT[realm] * 0.5) if EXP_TO_NEXT[realm] > 0 else 5000.0
	_pick_wander_target()

func _connect_time() -> void:
	var gt = get_node_or_null("/root/GameTime")
	if gt:
		gt.tick_advanced.connect(_on_tick)

func _on_tick(_year: int, _season: int) -> void:
	if not alive: return
	if realm >= Realm.DIVINE: return
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
	cultivation_exp += CULT_SPEED[realm] * speed_mult
	if EXP_TO_NEXT[realm] > 0 and cultivation_exp >= EXP_TO_NEXT[realm]:
		_breakthrough()
	_check_combat()

func _breakthrough() -> void:
	var old_realm: int = realm
	realm += 1
	cultivation_exp = 0.0
	queue_redraw()
	var hm_gain: int = [5, 10, 20, 50, 100][old_realm]
	var gt = get_node_or_null("/root/GameTime")
	if gt: gt.add_hm(hm_gain)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.cultivator_breakthrough.emit(self, old_realm, realm)
		eb.event_log_entry.emit("%s 突破至 %s！" % [cultivator_name, REALM_NAMES[realm]], "cult")

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

func get_combat_power() -> int:
	return (realm + 1) * 20 + wins * 5 - losses * 3 + randi_range(-10, 10)

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
		var my_power: int = get_combat_power()
		var other_power: int = other.get_combat_power()
		var eb = get_node_or_null("/root/EventBus")
		if my_power > other_power:
			wins += 1
			cultivation_exp += 10.0
			other.die()
			if eb:
				eb.event_log_entry.emit("%s 击败了 %s" % [cultivator_name, other.cultivator_name], "fight")
		else:
			losses += 1
			if eb:
				eb.event_log_entry.emit("%s 败给了 %s" % [cultivator_name, other.cultivator_name], "fight")
		combat_cooldown = 3.0
		return

func die() -> void:
	alive = false
	visible = false
	var gt = get_node_or_null("/root/GameTime")
	if gt: gt.add_hm((realm + 1) * 3)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.cultivator_died.emit(self)
		eb.event_log_entry.emit("%s 陨落" % cultivator_name, "fight")
