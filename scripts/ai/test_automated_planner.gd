extends SceneTree

const PLANNER_SCRIPT := preload("res://scripts/ai/automated_planner.gd")

var planner
var passed := 0
var failed := 0

func _init() -> void:
	planner = PLANNER_SCRIPT.new()
	call_deferred("_run_tests")

func _run_tests() -> void:
	var initial_state := {"predicates": ["at_start", "item_available"]}
	_assert_plan(
		"GOAL_Seek_Buff menghasilkan rencana item lalu MC",
		initial_state,
		"GOAL_Seek_Buff",
		["move_to_chest", "take_item", "use_item", "move_to_mc"]
	)
	_assert_plan(
		"GOAL_Direct_Engage dapat dicapai langsung",
		initial_state,
		"GOAL_Direct_Engage",
		["move_to_mc"]
	)
	_assert_replanning(initial_state)

	print("Automated Planner tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _assert_plan(label: String, initial_state: Dictionary, goal: String, expected: Array[String]) -> void:
	var actual: Array[String] = planner.request_plan(initial_state, goal)
	if actual == expected and planner.last_status == "success":
		passed += 1
		print("PASS: %s -> %s" % [label, actual])
	else:
		failed += 1
		push_error("FAIL: %s | expected %s, got %s | status=%s error=%s" % [label, expected, actual, planner.last_status, planner.last_error])

func _assert_replanning(initial_state: Dictionary) -> void:
	planner.request_plan(initial_state, "GOAL_Seek_Buff")
	var previous_revision: int = planner.plan_revision
	var latest_state := {"predicates": ["at_start"]}
	var replanned: Array[String] = planner.update_request(latest_state, "GOAL_Direct_Engage")
	var revision_after_change: int = planner.plan_revision
	var unchanged: Array[String] = planner.update_request(latest_state, "GOAL_Direct_Engage")
	if replanned == ["move_to_mc"] and revision_after_change > previous_revision and unchanged == replanned and planner.plan_revision == revision_after_change:
		passed += 1
		print("PASS: perubahan item/goal memicu replanning sekali")
	else:
		failed += 1
		push_error("FAIL: replanning | plan=%s unchanged=%s revision=%d->%d" % [replanned, unchanged, previous_revision, revision_after_change])