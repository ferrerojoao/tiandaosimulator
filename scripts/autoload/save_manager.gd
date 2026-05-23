## save_manager.gd - AutoLoad 存档管理器
extends Node

const SAVE_PATH: String = "user://save.json"

func save_game(data: Dictionary) -> bool:
	var json: String = JSON.stringify(data)
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f: return false
	f.store_string(json)
	f.close()
	return true

func load_game() -> Dictionary:
	if not has_save(): return {}
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f: return {}
	var json: String = f.get_as_text()
	f.close()
	var data = JSON.parse_string(json)
	if data == null: return {}
	return data

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
