## info_panel.gd - 统一小面板（修士/宗门/圣地/空地）
extends PanelContainer

@onready var lbl_name: Label = $VBoxContainer/LblName
@onready var lbl_line1: Label = $VBoxContainer/LblLine1
@onready var lbl_line2: Label = $VBoxContainer/LblLine2
@onready var lbl_line3: Label = $VBoxContainer/LblLine3
@onready var lbl_line4: Label = $VBoxContainer/LblLine4

var _target: Node2D
var _tile_x: int = -1
var _tile_y: int = -1

func _ready() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.cultivator_selected.connect(_on_cultivator_selected)
		eb.sect_selected.connect(_on_sect_selected)
		eb.tile_selected.connect(_on_tile_selected)
	visible = false

func _on_detail_pressed() -> void:
	print("[InfoPanel] 详情按钮被点击")
	var eb = get_node_or_null("/root/EventBus")
	if eb and is_instance_valid(_target) and _target.get("cultivator_name") != null:
		print("[InfoPanel] 发射信号")
		eb.request_cultivator_detail.emit(_target)
	else:
		print("[InfoPanel] 条件不满足: eb=%s target=%s" % [eb != null, is_instance_valid(_target)])

func _process(_delta: float) -> void:
	if _tile_x >= 0:
		_show_tile()
		return
	if not is_instance_valid(_target):
		_target = null
		visible = false
		return
	if _target.get("sect_name") != null:
		_show_sect()
	elif _target.get("site_name") != null:
		_show_sacred_site()
	elif _target.get("cultivator_name") != null:
		_show_cult()

func _on_cultivator_selected(c: Node) -> void:
	_target = c
	_tile_x = -1
	visible = c != null

func _on_sect_selected(s: Node) -> void:
	_target = s
	_tile_x = -1
	visible = s != null

func _on_tile_selected(tx: int, ty: int) -> void:
	_target = null
	_tile_x = tx
	_tile_y = ty
	visible = true

func _show_cult() -> void:
	var c = _target
	lbl_name.text = "%s" % c.get("cultivator_name")
	lbl_line1.text = "%s · %s" % [c.get("REALM_NAMES")[c.get("realm")], c.get("sect") if c.get("sect") else "散修"]
	var status: String = ""
	if c.get("is_breaking_through"): status = "闭关中"
	elif c.get("injured_ticks") > 0: status = "受伤"
	else: status = "游历"
	lbl_line2.text = "状态: %s" % status
	lbl_line3.text = ""
	lbl_line4.text = ""

func _show_sect() -> void:
	var s = _target
	lbl_name.text = s.get("sect_name")
	lbl_line1.text = "势力: %d" % s.get("power")
	lbl_line2.text = "成员: %d 人" % s.get("member_count")
	lbl_line3.text = "领地: %d 格" % s.get("territory_radius")
	lbl_line4.text = ""

func _show_sacred_site() -> void:
	var s = _target
	var e_names = ["无", "金", "木", "水", "火", "土"]
	lbl_name.text = s.get("site_name")
	lbl_line1.text = "属性: %s 系圣地" % e_names[s.get("element")]
	lbl_line2.text = "灵气浓度: 100%"
	lbl_line3.text = "在此修炼大幅加成"
	lbl_line4.text = ""

func _show_tile() -> void:
	var wm = get_node_or_null("/root/main/WorldMap")
	if not wm: return
	var density: float = wm.get_spirit_density(_tile_x, _tile_y)
	var elem: int = wm.get_spirit_element(_tile_x, _tile_y)
	lbl_name.text = "坐标 (%d, %d)" % [_tile_x, _tile_y]
	lbl_line1.text = "灵气: %s" % ("▮".repeat(int(density * 10)) if density > 0 else "无")
	lbl_line2.text = "属性: %s" % wm.ELEMENT_NAMES[elem]
	lbl_line3.text = "浓度: %.0f%%" % (density * 100)
	lbl_line4.text = ""
