## items.gd - 物品数据表
extends Node

# 灵石：修士用 int spirit_stones 存储，通用货币

# === 丹药 ===
static var PILLS = [
	{id="pill_qi", name="培元丹", grade=0, desc="加快修炼速度", effect="cult_speed", value=0.10, duration=10},
	{id="pill_build_foundation", name="筑基丹", realm_target=0, bonus=1.0, desc="炼气→筑基 100%成功率"},
	{id="pill_form_core", name="结丹丹", realm_target=1, bonus=0.15, desc="筑基→金丹 +15%成功率"},
	{id="pill_nascent", name="婴变丹", realm_target=2, bonus=0.07, desc="金丹→元婴 +7%成功率"},
	{id="pill_divine", name="化神丹", realm_target=3, bonus=0.02, desc="元婴→化神 +2%成功率"},
	{id="pill_trib", name="渡劫丹", realm_target=4, bonus=0.02, desc="化神→渡劫 +2%成功率"},
	{id="pill_heal", name="疗伤丹", grade=0, desc="恢复部分伤势", effect="cure_injury", value=5, duration=0},
	{id="pill_life", name="延寿丹", grade=2, desc="延长寿命 50 年", effect="extend_life", value=50, duration=0},
]

# === 功法 ===
enum TechType { CULT, COMBAT, MOVEMENT }

static var TECHNIQUES = [
	# 修炼类
	{id="tech_cult_mortal", name="吐纳术", type=TechType.CULT, grade=0, desc="凡品修炼法"},
	{id="tech_cult_yellow", name="纯阳心法", type=TechType.CULT, grade=1, desc="黄品修炼法"},
	{id="tech_cult_mystic", name="紫府秘典", type=TechType.CULT, grade=2, desc="玄品修炼法"},
	{id="tech_cult_earth", name="大衍天书", type=TechType.CULT, grade=3, desc="地品修炼法"},
	{id="tech_cult_heaven", name="混沌真解", type=TechType.CULT, grade=4, desc="天品修炼法"},
	# 战斗类
	{id="tech_combat_mortal", name="碎石拳", type=TechType.COMBAT, grade=0, desc="凡品拳法"},
	{id="tech_combat_yellow", name="疾风剑诀", type=TechType.COMBAT, grade=1, desc="黄品剑法"},
	{id="tech_combat_mystic", name="天罡战气", type=TechType.COMBAT, grade=2, desc="玄品战技"},
	{id="tech_combat_earth", name="破苍穹", type=TechType.COMBAT, grade=3, desc="地品战技"},
	{id="tech_combat_heaven", name="灭世诀", type=TechType.COMBAT, grade=4, desc="天品战技"},
]

# === 特殊物品 ===
static var SPECIALS = [
	{id="spec_life_talisman", name="替死符", desc="陨落时自动消耗，免死一次"},
	{id="spec_spirit_marrow", name="灵髓", desc="元婴→化神突破必备"},
	{id="spec_boundary_stone", name="破界石", desc="化神→渡劫突破必备"},
	{id="spec_spirit_orb", name="聚灵珠", desc="当前位置灵气拉满 1.0，持续 50 tick"},
]
