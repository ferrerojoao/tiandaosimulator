## event_bus.gd - AutoLoad 全局信号总线
extends Node

# 世界/地图事件
signal world_generated()
signal tile_clicked(tile_pos: Vector2i)

# 修士事件
signal cultivator_spawned(cultivator)
signal cultivator_died(cultivator)
signal cultivator_breakthrough(cultivator, old_realm: int, new_realm: int)
signal cultivator_selected(cultivator)
signal tile_selected(tile_x: int, tile_y: int)

# 宗门事件
signal sect_founded(sect)
signal sect_selected(sect)
signal sect_relation_changed(sect_a, sect_b, relation: int)

# 游戏事件
signal game_event_triggered(event_data: Dictionary)

# UI 事件
signal event_log_entry(text: String, category: String)
signal camera_focus_requested(world_pos: Vector2)

# 天道干预事件
signal tiandao_action(action_type: String, target, params: Dictionary)
