# audio_manager.gd - 音效+音乐管理
extends Node

var _pool: Array = []
const POOL_SIZE: int = 4
var _bgm: AudioStreamPlayer

func _ready() -> void:
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Master"
	add_child(_bgm)
	# 开局放菜单音乐
	play_bgm("开始菜单.ogg")

func _get_free() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	_pool[0].stop()
	return _pool[0]

func play_bgm(path: String) -> void:
	var stream = load("res://assets/audio/" + path)
	if stream:
		if _bgm.playing: _bgm.stop()
		_bgm.stream = stream
		_bgm.play()

func play(path: String) -> void:
	var stream = load("res://assets/audio/" + path)
	if stream:
		var p = _get_free()
		p.stream = stream
		p.play()

func play_thunder() -> void: play("雷声.ogg")
func play_kill() -> void: play("斩杀.ogg")
func play_success() -> void: play("成功.ogg")
func play_loot() -> void: play("获得.ogg")
func play_click() -> void: play("点击.ogg")
