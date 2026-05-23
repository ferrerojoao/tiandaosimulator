## game_time.gd - AutoLoad 世界时间系统
extends Node

enum Speed { PAUSE = 0, NORMAL = 1, FAST = 2, ULTRA = 5, ULTRA2 = 10 }

const BASE_TICKS_PER_SECOND: float = 1.0 / 15.0
const SEASON_NAMES: Array = ["春", "夏", "秋", "冬"]

var speed_multipliers: Dictionary = {
	Speed.PAUSE:  0.0,
	Speed.NORMAL: 1.0,
	Speed.FAST:   2.0,
	Speed.ULTRA:  5.0,
	Speed.ULTRA2: 10.0,
}

var current_year: int = 1
var current_season: int = 0
var current_speed: int = Speed.NORMAL
var heavenly_mechanism: int = 50
var _tick_accumulator: float = 0.0

signal season_changed(year: int, season: int, season_name: String)
signal year_changed(year: int)
signal speed_changed(new_speed: int)
signal tick_advanced(year: int, season: int)
signal hm_changed(amount: int)

func _ready() -> void:
	season_changed.emit(current_year, current_season, get_season_name())

func _process(delta: float) -> void:
	if current_speed == Speed.PAUSE:
		return
	var multiplier: float = speed_multipliers.get(current_speed, 1.0)
	_tick_accumulator += delta * BASE_TICKS_PER_SECOND * multiplier
	while _tick_accumulator >= 1.0:
		_tick_accumulator -= 1.0
		_advance_tick()

func _advance_tick() -> void:
	tick_advanced.emit(current_year, current_season)
	current_season += 1
	if current_season >= 4:
		current_season = 0
		current_year += 1
		year_changed.emit(current_year)
	season_changed.emit(current_year, current_season, get_season_name())

func set_speed(new_speed: int) -> void:
	if current_speed != new_speed:
		current_speed = new_speed
		speed_changed.emit(current_speed)

func toggle_pause() -> void:
	set_speed(Speed.PAUSE if current_speed != Speed.PAUSE else Speed.NORMAL)

func add_hm(amount: int) -> void:
	heavenly_mechanism += amount
	hm_changed.emit(heavenly_mechanism)

func spend_hm(amount: int) -> bool:
	if heavenly_mechanism >= amount:
		heavenly_mechanism -= amount
		hm_changed.emit(heavenly_mechanism)
		return true
	return false

func is_paused() -> bool:
	return current_speed == Speed.PAUSE

func get_season_name() -> String:
	return SEASON_NAMES[current_season]

func get_time_string() -> String:
	return "第 %d 年 · %s季" % [current_year, get_season_name()]
