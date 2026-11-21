extends SceneTree

const DECISION_ENGINE_SCRIPT := preload("res://scripts/ai/decision_engine.gd")

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var engine = DECISION_ENGINE_SCRIPT.new()
	var prior_belief: float = engine.belief_success
	_check(engine.observe("mc_far"), "Observasi baru diproses")
	_check(engine.belief_success > prior_belief, "MC jauh meningkatkan belief keberhasilan")
	var safe_result: Dictionary = engine.decide(true, true, false)
	_check(safe_result["action"] == DECISION_ENGINE_SCRIPT.ACTION_SEEK_BUFF, "Policy aman memilih mencari buff")
	_check(int(safe_result["iterations"]) > 0, "Value Iteration berjalan")
	_check(safe_result["policy"].has("need_buff_risky"), "Policy memuat state risiko")
	_check(safe_result["action_values"].has(DECISION_ENGINE_SCRIPT.ACTION_SEEK_BUFF), "Utility mencari buff tersedia")
	var safe_transitions: Dictionary = safe_result["transitions"]
	var safe_seek_transitions: Dictionary = safe_transitions[DECISION_ENGINE_SCRIPT.ACTION_SEEK_BUFF]
	var safe_probability_total := 0.0
	for probability in safe_seek_transitions.values():
		safe_probability_total += float(probability)
	_check(is_equal_approx(safe_probability_total, 1.0), "Probabilitas transisi safe berjumlah satu")
	_check(safe_seek_transitions.has("need_buff_medium"), "Kegagalan di state safe menuju risiko medium")
	var direct_transitions: Dictionary = safe_transitions[DECISION_ENGINE_SCRIPT.ACTION_DIRECT_ENGAGE]
	_check(is_equal_approx(float(direct_transitions.get("direct_ready", 0.0)), 1.0), "Direct engage menuju state siap secara deterministik")
	var safe_rewards: Dictionary = safe_result["rewards"][DECISION_ENGINE_SCRIPT.ACTION_SEEK_BUFF]
	_check(is_equal_approx(float(safe_rewards["success"]), 10.0), "Reward sukses buff sesuai model")

	var belief_before_near: float = engine.belief_success
	_check(engine.observe("mc_near"), "Observasi jarak dekat diproses")
	_check(engine.belief_success < belief_before_near, "MC mendekat menurunkan belief keberhasilan")
	var risky_result: Dictionary = engine.decide(true, true, false)
	_check(risky_result["action"] == DECISION_ENGINE_SCRIPT.ACTION_DIRECT_ENGAGE, "Risiko tinggi mengubah policy ke direct engage")
	_check(float(risky_result["action_values"][DECISION_ENGINE_SCRIPT.ACTION_SEEK_BUFF]) < float(risky_result["action_values"][DECISION_ENGINE_SCRIPT.ACTION_DIRECT_ENGAGE]), "Expected utility menjelaskan pergantian policy")
	var risky_transitions: Dictionary = risky_result["transitions"][DECISION_ENGINE_SCRIPT.ACTION_SEEK_BUFF]
	_check(risky_transitions.has("buff_unavailable"), "Kegagalan di state risky mengarah ke buff unavailable")
	var risky_rewards: Dictionary = risky_result["rewards"][DECISION_ENGINE_SCRIPT.ACTION_SEEK_BUFF]
	_check(is_equal_approx(float(risky_rewards["failure"]), -8.0), "Reward gagal di state risky mencerminkan risiko tinggi")

	var unchanged_belief: float = engine.belief_success
	_check(not engine.observe("mc_near"), "Observasi bucket yang sama tidak dihitung berulang")
	_check(is_equal_approx(engine.belief_success, unchanged_belief), "Observasi berulang tidak mengubah belief")
	_check(not engine.observe("unknown_observation"), "Observasi yang tidak dikenal ditolak")
	_check(is_equal_approx(engine.belief_success, unchanged_belief), "Observasi invalid tidak mengubah belief")
	_check(engine.observe("item_taken"), "Item diambil diproses sebagai evidence")
	_check(engine.belief_success < unchanged_belief, "Item diambil menurunkan belief keberhasilan")
	var unavailable_result: Dictionary = engine.decide(true, false, false)
	_check(unavailable_result["action"] == DECISION_ENGINE_SCRIPT.ACTION_DIRECT_ENGAGE, "Item yang tidak tersedia memilih direct engage")
	var secured_result: Dictionary = engine.decide(true, false, true)
	_check(secured_result["state"] == "buff_secured", "State buff NPC tercatat sebagai secured")
	var no_buff_needed: Dictionary = engine.decide(false, true, false)
	_check(no_buff_needed["action"] == DECISION_ENGINE_SCRIPT.ACTION_DIRECT_ENGAGE, "Keunggulan KB memilih direct engage")

	print("Decision Engine tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)