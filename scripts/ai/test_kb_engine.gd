extends SceneTree

var engine: KBEngine
var passed := 0
var failed := 0

func _init() -> void:
	engine = KBEngine.new()
	call_deferred("_run_tests")

func _run_tests() -> void:
	var seek_buff_percepts := {"npc_element": "Fire", "mc_element": "Water", "npc_stats": {"attack": 30, "defense": 10}, "mc_stats": {"attack": 30, "defense": 10}, "chest_available": true}
	_run_case(
		"NPC kalah elemen & peti tersedia",
		seek_buff_percepts,
		"GOAL_Seek_Buff"
	)
	_run_case(
		"NPC kalah effective damage & peti tersedia",
		{"npc_element": "Fire", "mc_element": "Fire", "npc_effective_damage": 20.0, "mc_effective_damage": 30.0, "chest_available": true},
		"GOAL_Seek_Buff"
	)
	_run_case(
		"Fallback peti diambil MC",
		{"npc_element": "Fire", "mc_element": "Nature", "npc_effective_damage": 20.0, "mc_effective_damage": 30.0, "chest_available": false},
		"GOAL_Direct_Engage"
	)
	_run_case(
		"NPC unggul elemen & effective damage",
		{"npc_element": "Fire", "mc_element": "Nature", "npc_effective_damage": 40.0, "mc_effective_damage": 30.0, "chest_available": true},
		"GOAL_Direct_Engage"
	)
	_run_query_case("ASK goal spesifik", seek_buff_percepts, "GOAL_Seek_Buff", "GOAL_Direct_Engage")

	print("KB Engine tests: %d passed, %d failed" % [passed, failed])
	engine.free()
	quit(1 if failed > 0 else 0)

func _run_case(label: String, percepts: Dictionary, expected: String) -> void:
	engine.tell(percepts)
	var answer := engine.ask("GOAL")
	if answer == expected:
		passed += 1
		print("PASS: %s -> %s" % [label, answer])
	else:
		failed += 1
		push_error("FAIL: %s | expected %s, got %s | facts=%s active=%s" % [label, expected, answer, engine.fact_base, engine.active_rules])

func _run_query_case(label: String, percepts: Dictionary, expected: String, rejected_query: String) -> void:
	engine.tell(percepts)
	var matched_answer := engine.ask(expected)
	var rejected_answer := engine.ask(rejected_query)
	if matched_answer == expected and rejected_answer.is_empty():
		passed += 1
		print("PASS: %s -> %s" % [label, matched_answer])
	else:
		failed += 1
		push_error("FAIL: %s | matched=%s rejected=%s" % [label, matched_answer, rejected_answer])
