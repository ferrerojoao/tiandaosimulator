# tombstone.gd - 修士墓碑
extends Node2D

var cultivator_name: String = "???"
var realm: int = 0
var age: int = 0
var personality: int = 0
var talent: int = 0
var sect: String = ""
var wins: int = 0
var losses: int = 0
var spirit_root: int = 0
var spirit_element: int = 0
var root_bone: int = 0
var comprehension: int = 0
var fortune: int = 0
var life_events: Array = []
var techniques: Array = []
var inventory: Dictionary = {}
var spirit_stones: int = 0
var death_year: int = 0
var lifetime: int = 80
var ai_goal: String = "已陨落"
var cultivation_exp: float = 0
var learn_book: String = ""
var learn_progress: float = 0.0
var pill_life_used: bool = true
var pill_used_breakthrough: bool = true
var pill_qi_ticks: int = 0
var life_bonus: int = 0
var combat_cooldown: float = 0.0

# 引用常量
const REALM_NAMES: Array = ["炼气", "筑基", "金丹", "元婴", "化神", "渡劫"]
const SPIRIT_ROOT_NAMES: Array = ["浊灵根", "清灵根", "玄灵根", "天灵根"]
const ELEMENT_NAMES: Array = ["无", "金", "木", "水", "火", "土"]
const PERSONALITY_NAMES: Array = ["嗜杀", "稳健", "平和"]
const TALENT_NAMES: Array = ["天慧", "坚韧", "贪婪", "探奇", "丹道", "杀伐", "孤僻", "谨慎", "战神"]
const EXP_TO_NEXT: Array = [80.0, 200.0, 400.0, 800.0, 2000.0, 5000.0]

var _selected: bool = false

func _ready() -> void:
	z_index = 10
	var tex = load("res://assets/tombstone.png")
	if tex:
		var sp = Sprite2D.new()
		sp.texture = tex
		sp.centered = true
		sp.scale = Vector2(1.0, 1.0)
		add_child(sp)
	# 连接季节信号
	var gt = get_node_or_null("/root/GameTime")
	if gt and gt.has_signal("tick_advanced"):
		gt.tick_advanced.connect(_on_season)
	queue_redraw()

func _on_season(_year: int, _season: int) -> void:
	lifetime -= 1
	if lifetime <= 0:
		queue_free()

func _draw() -> void:
	if _selected:
		draw_circle(Vector2(0, 0), 22, Color.YELLOW)

func set_selected(s: bool) -> void:
	_selected = s
	queue_redraw()

func get_combat_power() -> float:
	return 0

func try_loot() -> Dictionary:
	if inventory.is_empty() and spirit_stones <= 0:
		return {}
	var result: Dictionary = {}
	if spirit_stones > 0:
		result["stones"] = spirit_stones
		spirit_stones = 0
	elif not inventory.is_empty():
		var key: String = inventory.keys().pick_random()
		var count: int = inventory[key]
		inventory[key] -= 1
		if inventory[key] <= 0: inventory.erase(key)
		result["item"] = key
	return result

func is_alive() -> bool:
	return true

func get_display_name() -> String:
	return cultivator_name + " (墓碑)"
