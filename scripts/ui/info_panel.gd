## info_panel.gd - 统一信息面板（修士/宗门）
extends PanelContainer

@onready var lbl_name: Label = $VBoxContainer/LblName
@onready var lbl_line1: Label = $VBoxContainer/LblLine1
@onready var lbl_line2: Label = $VBoxContainer/LblLine2
@onready var lbl_line3: Label = $VBoxContainer/LblLine3
@onready var lbl_line4: Label = $VBoxContainer/LblLine4

var _target: Node2D

func _ready() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.cultivator_selected.connect(_on_cultivator_selected)
		eb.sect_selected.connect(_on_sect_selected)
	visible = false

func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		visible = false
		return
	if _target.get("sect_name") != null:
		_show_sect()
	elif _target.get("cultivator_name") != null:
		_show_cult()

func _on_cultivator_selected(c: Node) -> void:
	_target = c
	visible = c != null

func _on_sect_selected(s: Node) -> void:
	_target = s
	visible = s != null

func _show_cult() -> void:
	var c = _target
	lbl_name.text = "%s" % c.get("cultivator_name")
	lbl_line1.text = "境界: %s" % c.get("REALM_NAMES")[c.get("realm")]
	lbl_line2.text = "年龄: %d 岁 · %s" % [c.get("age"), c.get("sect") if c.get("sect") else "散修"]
	var next_exp: float = c.get("EXP_TO_NEXT")[c.get("realm")] if c.get("realm") < c.get("EXP_TO_NEXT").size() else -1
	if next_exp > 0:
		lbl_line3.text = "修为: %.0f / %.0f" % [c.get("cultivation_exp"), next_exp]
	else:
		lbl_line3.text = "修为: %.0f (圆满)" % c.get("cultivation_exp")
	lbl_line4.text = "战绩: %d胜 %d败" % [c.get("wins"), c.get("losses")]

func _show_sect() -> void:
	var s = _target
	lbl_name.text = s.get("sect_name")
	lbl_line1.text = "势力: %d" % s.get("power")
	lbl_line2.text = "成员: %d 人" % s.get("member_count")
	lbl_line3.text = "领地: %d 格" % s.get("territory_radius")
	lbl_line4.text = ""
