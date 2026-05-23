## save_manager.gd - AutoLoad 存档管理器 (Phase 1 占位)
extends Node

const SAVE_PATH: String = "user://save_world.json"

func save_game() -> void:
	pass

func load_game() -> bool:
	return false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
