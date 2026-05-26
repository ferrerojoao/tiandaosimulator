# tribulation_manager.gd - 雷劫管理
extends Node2D

var active: bool = false
var center: Vector2 = Vector2.ZERO
var radius: float = 192.0  # 6 tiles * 32px
var timer: float = 15.0
var target: Node = null
var _strike_cooldown: float = 0.0
var _warnings: Array = []  # [{pos, timer}]
var _flashes: Array = []   # [{pos, timer}]
var _striking: bool = false
var _prev_speed: int = -1
var _speed_locked: bool = false

func _ready() -> void:
	z_index = 50  # 在一切之上
	visible = false
	set_process(false)

func start_tribulation(cultivator: Node) -> void:
	if active: return
	active = true
	target = cultivator
	center = cultivator.position
	timer = 15.0
	_strike_cooldown = 0.5
	_warnings.clear()
	_flashes.clear()
	
	# 驱逐圈内其他人
	var spawner = cultivator.get_parent()
	if spawner:
		for child in spawner.get_children():
			if child == target: continue
			if not child.get("cultivator_name"): continue
			if child.get("alive") == false: continue
			var d: float = child.position.distance_to(center)
			if d < radius:
				var push: Vector2 = (child.position - center).normalized()
				child.position = center + push * (radius + 30)
	
	# 目标标记
	cultivator.set("in_tribulation", true)
	
	# 速锁
	var gt = get_node_or_null("/root/GameTime")
	if gt:
		_prev_speed = gt.current_speed
		_speed_locked = true
		gt.set_speed(1)  # 强制 1x
	
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not active: return
	
	# 目标死了?
	if not is_instance_valid(target) or target.get("alive") == false:
		end_tribulation(false)
		return
	
	# 速度保持
	var gt = get_node_or_null("/root/GameTime")
	if gt and _speed_locked:
		if gt.current_speed != 1:
			gt.set_speed(1)
	
	# 计时
	timer -= delta
	if timer <= 0:
		end_tribulation(true)
		return
	
	# 随机落雷
	_strike_cooldown -= delta
	if _strike_cooldown <= 0:
		_strike_cooldown = 0.4 + randf() * 0.3
		# 70%概率瞄准目标，30%随机
		var pos: Vector2
		if is_instance_valid(target) and randf() < 0.7:
			pos = target.position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		else:
			pos = center + Vector2(randf_range(-radius*0.8, radius*0.8), randf_range(-radius*0.8, radius*0.8))
		_do_strike(pos)
	
	# 更新预警和闪光
	for i in range(_warnings.size() - 1, -1, -1):
		_warnings[i]["timer"] -= delta
		if _warnings[i]["timer"] <= 0:
			_warnings.remove_at(i)
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i]["timer"] -= delta
		if _flashes[i]["timer"] <= 0:
			_flashes.remove_at(i)
	
	queue_redraw()

func _do_strike(pos: Vector2) -> void:
	if _striking: return
	_striking = true
	# 预警
	_warnings.append({"pos": pos, "timer": 0.08})
	
	# 延迟判定命中
	await get_tree().create_timer(0.08).timeout
	if not active: return
	
	# 判定圈内所有修士
	var spawner = target.get_parent() if is_instance_valid(target) else null
	if spawner:
		for child in spawner.get_children():
			if not child.get("cultivator_name"): continue
			if child.get("alive") == false: continue
			if child.position.distance_to(pos) < 45:
				var dist: float = child.position.distance_to(pos)
				var dmg: int = randi_range(10, 20) if dist > 25 else randi_range(20, 35)
				child.set("injured_ticks", child.get("injured_ticks") + dmg)
				# 检查是否死亡
				if child.get("injured_ticks") >= 60:
					var eb = get_node_or_null("/root/EventBus")
					if eb: eb.event_log_entry.emit("%s 被天雷劈死" % child.get("cultivator_name"), "fight")
					child.die(true, "被天雷劈死")
					if child == target:
						end_tribulation(false)
						return
	
	_flashes.append({"pos": pos, "timer": 0.3, "bolt": _gen_lightning(pos)})
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_thunder()
	_striking = false

func _gen_lightning(hit_pos: Vector2) -> Array:
	"""预生成闪电折线"""
	var top: float = hit_pos.y - 400
	var points: Array = [Vector2(hit_pos.x, top)]
	var y: float = top
	var x: float = hit_pos.x
	var segments: int = randi_range(6, 10)
	for i in segments:
		y += (hit_pos.y - top) / segments
		x += randf_range(-25, 25)
		points.append(Vector2(x, y))
	points.append(hit_pos)
	return points

func strike_at(pos: Vector2) -> void:
	"""玩家手动落雷"""
	if not active: return
	if pos.distance_to(center) > radius: return
	_do_strike(pos)

func end_tribulation(survived: bool) -> void:
	active = false
	visible = false
	set_process(false)
	_warnings.clear()
	_flashes.clear()
	_striking = false
	
	var gt = get_node_or_null("/root/GameTime")
	if gt and _speed_locked:
		_speed_locked = false
		if _prev_speed >= 0:
			gt.set_speed(_prev_speed)
	
	if is_instance_valid(target):
		target.set("in_tribulation", false)
		var eb = get_node_or_null("/root/EventBus")
		if survived:
			# 渡过奖励
			var realm: int = target.get("realm")
			var exp_arr = target.get("EXP_TO_NEXT")
			if exp_arr and realm < exp_arr.size():
				var bonus: float = exp_arr[realm] * 0.5
				target.set("cultivation_exp", mini(target.get("cultivation_exp") + bonus, exp_arr[realm]))
			if target.has_method("_add_event"):
				target._add_event("渡过雷劫")
			if eb: eb.event_log_entry.emit("%s 渡过雷劫！" % target.get("cultivator_name"), "fight")
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_success()
	
	target = null

func _draw() -> void:
	if not active: return
	# 雷劫圈
	draw_circle(center, radius, Color(1.0, 0.7, 0.1, 0.15))
	draw_arc(center, radius, 0, TAU, 64, Color(1.0, 0.7, 0.1, 0.6), 3)
	# 计时环
	var progress: float = 1.0 - timer / 15.0
	draw_arc(center, radius + 4, -PI/2, -PI/2 + progress * TAU, 32, Color(1.0, 0.3, 0.1, 0.8), 4)
	# 预警
	for w in _warnings:
		var a: float = w["timer"] / 0.15
		draw_circle(w["pos"], 10 + a * 30, Color(1, 0.3, 0.1, a))
	# 闪光
	for f in _flashes:
		var a: float = f["timer"] / 0.3
		draw_circle(f["pos"], 45, Color(1, 1, 0.8, a * 0.5))
		var bolt: Array = f.get("bolt", [])
		if bolt.size() >= 2:
			draw_polyline(bolt, Color(1, 1, 0.95, a), 3)
