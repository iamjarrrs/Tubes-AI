@tool
class_name KBEngine
extends Node

const KB_PATH := "res://data/npc_kb.json"

var fact_base: Array[String] = []
var last_query: String = "GOAL"
var last_answer: String = "GOAL_Direct_Engage"
var active_rules: Array[String] = []

var _rules: Array[Dictionary] = []
var _load_error: String = ""

func _init() -> void:
	_load_knowledge_base()

func tell(percepts: Dictionary) -> void:
	fact_base.clear()
	active_rules.clear()
	last_answer = "GOAL_Direct_Engage"

	var mc_stats: Dictionary = _dict_from(percepts, "mc_stats", "mc")
	var npc_stats: Dictionary = _dict_from(percepts, "npc_stats", "npc")

	var mc_element := _get_element(percepts, "mc")
	var npc_element := _get_element(percepts, "npc")
	var relation := _element_relation(npc_element, mc_element)
	if relation == "advantage":
		fact_base.append("element_advantage")
		fact_base.append("element_advantage_or_equal")
	elif relation == "disadvantage":
		fact_base.append("element_disadvantage")
	else:
		fact_base.append("element_equal")
		fact_base.append("element_advantage_or_equal")

	var npc_effective_damage := _effective_damage(percepts, npc_stats, mc_stats, "npc_effective_damage", npc_element, mc_element)
	var mc_effective_damage := _effective_damage(percepts, mc_stats, npc_stats, "mc_effective_damage", mc_element, npc_element)
	if npc_effective_damage < mc_effective_damage:
		fact_base.append("effective_damage_disadvantage")
	elif npc_effective_damage > mc_effective_damage:
		fact_base.append("effective_damage_advantage")
		fact_base.append("effective_damage_advantage_or_equal")
	else:
		fact_base.append("effective_damage_equal")
		fact_base.append("effective_damage_advantage_or_equal")

	var chest_available := true
	if percepts.has("chest_available"):
		chest_available = bool(percepts["chest_available"])
	elif percepts.has("item_available"):
		chest_available = bool(percepts["item_available"])
	if chest_available:
		fact_base.append("chest_available")
	else:
		fact_base.append("chest_unavailable")

	_remove_duplicates()

func ask(query: String = "GOAL") -> String:
	last_query = query.strip_edges()
	if last_query.is_empty():
		last_query = "GOAL"
	active_rules.clear()

	if not _load_error.is_empty():
		push_error("KBEngine: " + _load_error)
		last_answer = "GOAL_Direct_Engage"
		return last_answer

	var changed := true
	while changed:
		changed = false
		for rule in _rules:
			var premises: Array = rule.get("if", [])
			if not _premises_match(premises):
				continue
			var conclusion := str(rule.get("then", ""))
			if conclusion.is_empty():
				continue
			var rule_id := str(rule.get("id", "unnamed_rule"))
			if not active_rules.has(rule_id):
				active_rules.append(rule_id)
			if conclusion.begins_with("GOAL_"):
				if not fact_base.has(conclusion):
					fact_base.append(conclusion)
					changed = true
			elif conclusion == "need_buff" and not fact_base.has(conclusion):
				fact_base.append(conclusion)
				changed = true

	var inferred_goal := _select_goal_from_rules()
	var requested_goal := last_query.to_upper()
	if requested_goal == "GOAL":
		last_answer = inferred_goal
	elif requested_goal == inferred_goal.to_upper():
		last_answer = inferred_goal
	else:
		last_answer = ""
	return last_answer

func _select_goal_from_rules() -> String:
	for rule in _rules:
		var conclusion := str(rule.get("then", ""))
		if not conclusion.begins_with("GOAL_"):
			continue
		if _premises_match(rule.get("if", [])):
			return conclusion
	return "GOAL_Direct_Engage"

func get_facts() -> Array[String]:
	return fact_base.duplicate()

func get_active_rules() -> Array[String]:
	return active_rules.duplicate()

func _load_knowledge_base() -> void:
	_rules.clear()
	_load_error = ""
	if not FileAccess.file_exists(KB_PATH):
		_load_error = "Knowledge base file not found: " + KB_PATH
		return
	var file := FileAccess.open(KB_PATH, FileAccess.READ)
	if file == null:
		_load_error = "Could not open knowledge base: " + KB_PATH
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("rules", null) is Array:
		_load_error = "Knowledge base must contain a top-level rules array."
		return
	for raw_rule in parsed["rules"]:
		if not raw_rule is Dictionary:
			_load_error = "Every KB rule must be a JSON object."
			return
		var rule: Dictionary = raw_rule
		if not rule.get("if", null) is Array or not rule.get("then", null) is String:
			_load_error = "Every KB rule requires if-array and then-string."
			return
		_rules.append(rule)
	_rules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0)))

func _premises_match(premises: Array) -> bool:
	for premise in premises:
		if not premise is String or not fact_base.has(str(premise)):
			return false
	return true

func _dict_from(percepts: Dictionary, primary: String, short_name: String) -> Dictionary:
	var value: Variant = percepts.get(primary, percepts.get(short_name, {}))
	return value if value is Dictionary else {}

func _get_element(percepts: Dictionary, side: String) -> String:
	var stats: Dictionary = _dict_from(percepts, side + "_stats", side)
	var element := str(percepts.get(side + "_element", stats.get("element", "")))
	if element.is_empty():
		var loadout: Dictionary = percepts.get(side + "_loadout", {})
		if loadout is Dictionary:
			element = str(loadout.get("element", ""))
	return element.strip_edges().capitalize()

func _element_relation(attacker_element: String, defender_element: String) -> String:
	if attacker_element.is_empty() or defender_element.is_empty() or attacker_element == "Neutral" or defender_element == "Neutral":
		return "equal"
	if (attacker_element == "Fire" and defender_element == "Nature") or (attacker_element == "Nature" and defender_element == "Water") or (attacker_element == "Water" and defender_element == "Fire"):
		return "advantage"
	if (attacker_element == "Nature" and defender_element == "Fire") or (attacker_element == "Water" and defender_element == "Nature") or (attacker_element == "Fire" and defender_element == "Water"):
		return "disadvantage"
	return "equal"

func _effective_damage(percepts: Dictionary, attacker: Dictionary, defender: Dictionary, explicit_key: String, attacker_element: String, defender_element: String) -> float:
	if percepts.has(explicit_key):
		return float(percepts[explicit_key])
	var attack := float(attacker.get("attack", attacker.get("atk", attacker.get("power", 20))))
	var defense := float(defender.get("defense", defender.get("def", 10)))
	var relation := _element_relation(attacker_element, defender_element)
	var multiplier := 1.0
	if relation == "advantage":
		multiplier = 1.5
	elif relation == "disadvantage":
		multiplier = 0.8
	return maxf(1.0, attack * multiplier - defense * 0.5)

func _remove_duplicates() -> void:
	var unique: Array[String] = []
	for fact in fact_base:
		if not unique.has(fact):
			unique.append(fact)
	fact_base = unique
