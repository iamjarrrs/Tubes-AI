extends RefCounted

const DOMAIN_PATH := "res://data/domain_planning.json"

const STATUS_SUCCESS := "success"
const STATUS_UNKNOWN_GOAL := "unknown_goal"
const STATUS_UNREACHABLE := "unreachable"
const STATUS_INVALID_INITIAL_STATE := "invalid_initial_state"
const STATUS_DOMAIN_ERROR := "domain_error"
const STATUS_INVALIDATED := "invalidated"

var current_plan: Array[String] = []
var last_status: String = STATUS_INVALIDATED
var last_error: String = ""
var plan_revision: int = 0

var _domain_error: String = ""
var _valid_predicates: Dictionary = {}
var _actions: Array[Dictionary] = []
var _last_request_state: Dictionary = {}
var _last_request_goal: String = ""
var _has_last_request: bool = false

func _init() -> void:
	_load_domain()

func request_plan(initial_state: Dictionary, goal: String) -> Array[String]:
	invalidate_plan()
	_remember_request(initial_state, goal)
	last_status = "planning"

	if not _domain_error.is_empty():
		return _fail(STATUS_DOMAIN_ERROR, _domain_error)

	var normalized_state := _normalize_initial_state(initial_state)
	if normalized_state == null:
		return _fail(STATUS_INVALID_INITIAL_STATE, "Expected a predicates array containing known state predicates.")

	var goal_predicates := _parse_goal(goal)
	if goal_predicates == null:
		return _fail(STATUS_UNKNOWN_GOAL, "Goal must contain one or more known predicates joined by AND, &&, or commas.")

	var result := _search(normalized_state, goal_predicates)
	if result == null:
		return _fail(STATUS_UNREACHABLE, "No reachable state satisfies the requested goal.")

	current_plan = result
	last_status = STATUS_SUCCESS
	last_error = ""
	return current_plan.duplicate()

func update_request(initial_state: Dictionary, goal: String) -> Array[String]:
	var normalized_state := _normalize_initial_state(initial_state)
	var normalized_goal := goal.strip_edges().to_lower()
	if _has_last_request and normalized_state != null and initial_state == _last_request_state and normalized_goal == _last_request_goal:
		return current_plan.duplicate()
	return request_plan(initial_state, goal)

func invalidate_plan() -> void:
	current_plan.clear()
	_last_request_state.clear()
	_last_request_goal = ""
	_has_last_request = false
	plan_revision += 1
	last_status = STATUS_INVALIDATED
	last_error = ""

func get_current_plan() -> Array[String]:
	return current_plan.duplicate()

func _remember_request(initial_state: Dictionary, goal: String) -> void:
	if _normalize_initial_state(initial_state) == null:
		return
	_last_request_state = initial_state.duplicate(true)
	_last_request_goal = goal.strip_edges().to_lower()
	_has_last_request = true

func _load_domain() -> void:
	if not FileAccess.file_exists(DOMAIN_PATH):
		_domain_error = "Planning domain file not found: " + DOMAIN_PATH
		return

	var file := FileAccess.open(DOMAIN_PATH, FileAccess.READ)
	if file == null:
		_domain_error = "Could not open planning domain file."
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_domain_error = "Planning domain must contain a JSON object."
		return

	var predicate_list: Variant = parsed.get("state_predicates", null)
	var action_list: Variant = parsed.get("actions", null)
	if not predicate_list is Array or not action_list is Array:
		_domain_error = "Planning domain requires state_predicates and actions arrays."
		return

	for predicate in predicate_list:
		if not predicate is String or str(predicate).is_empty():
			_domain_error = "Every state predicate must be a non-empty string."
			return
		_valid_predicates[str(predicate)] = true

	for action_variant in action_list:
		if not action_variant is Dictionary or not _is_valid_action(action_variant):
			_domain_error = "Every action must define name, parameters, precondition, effect.add, effect.del, and a positive cost."
			return
		_actions.append(action_variant)

func _is_valid_action(action: Dictionary) -> bool:
	if not action.get("name", "") is String or not action.get("parameters", null) is Array:
		return false
	if not action.get("precondition", null) is Array or not action.get("effect", null) is Dictionary:
		return false
	var effect: Dictionary = action["effect"]
	if not effect.get("add", null) is Array or not effect.get("del", null) is Array:
		return false
	if int(action.get("cost", 0)) <= 0:
		return false
	for predicate in action["precondition"] + effect["add"] + effect["del"]:
		if not predicate is String or not _valid_predicates.has(str(predicate)):
			return false
	return true

func _normalize_initial_state(initial_state: Dictionary) -> Variant:
	var raw_predicates: Variant = initial_state.get("predicates", null)
	if not raw_predicates is Array:
		return null

	var normalized: Array[String] = []
	for predicate in raw_predicates:
		if not predicate is String or not _valid_predicates.has(str(predicate)):
			return null
		if not normalized.has(str(predicate)):
			normalized.append(str(predicate))
	normalized.sort()
	return normalized

func _parse_goal(goal: String) -> Variant:
	var normalized_text := goal.strip_edges().to_lower()
	if normalized_text.begins_with("goal:"):
		normalized_text = normalized_text.trim_prefix("goal:").strip_edges()
	normalized_text = normalized_text.replace("&&", " and ").replace(",", " and ")
	var goals: Array[String] = []
	for token in normalized_text.split(" and ", false):
		var predicate := token.strip_edges()
		if predicate.is_empty() or not _valid_predicates.has(predicate):
			return null
		if not goals.has(predicate):
			goals.append(predicate)
	return goals if not goals.is_empty() else null

func _search(initial_state: Array[String], goals: Array[String]) -> Variant:
	var initial_key := _state_key(initial_state)
	var open_set: Array[Dictionary] = [{
		"key": initial_key,
		"state": initial_state,
		"g": 0,
		"f": _heuristic(initial_state, goals)
	}]
	var g_score: Dictionary = {initial_key: 0}
	var parents: Dictionary = {}
	var closed: Dictionary = {}

	while not open_set.is_empty():
		var best_index := 0
		for index in range(1, open_set.size()):
			if int(open_set[index]["f"]) < int(open_set[best_index]["f"]):
				best_index = index
		var current: Dictionary = open_set.pop_at(best_index)
		var current_key: String = current["key"]
		if closed.has(current_key):
			continue

		var current_state: Array[String] = current["state"]
		if _satisfies_goal(current_state, goals):
			return _reconstruct_plan(parents, current_key)
		closed[current_key] = true

		for action in _actions:
			if not _is_applicable(action, current_state):
				continue
			var next_state := _apply_action(action, current_state)
			var next_key := _state_key(next_state)
			var tentative_g := int(current["g"]) + int(action["cost"])
			if g_score.has(next_key) and tentative_g >= int(g_score[next_key]):
				continue

			g_score[next_key] = tentative_g
			parents[next_key] = {"previous": current_key, "action": str(action["name"])}
			closed.erase(next_key)
			open_set.append({
				"key": next_key,
				"state": next_state,
				"g": tentative_g,
				"f": tentative_g + _heuristic(next_state, goals)
			})
	return null

func _heuristic(state: Array[String], goals: Array[String]) -> int:
	var unsatisfied := 0
	for goal in goals:
		if not state.has(goal):
			unsatisfied += 1
	return unsatisfied

func _satisfies_goal(state: Array[String], goals: Array[String]) -> bool:
	for goal in goals:
		if not state.has(goal):
			return false
	return true

func _is_applicable(action: Dictionary, state: Array[String]) -> bool:
	for predicate in action["precondition"]:
		if not state.has(str(predicate)):
			return false
	return true

func _apply_action(action: Dictionary, state: Array[String]) -> Array[String]:
	var next_state := state.duplicate()
	var effect: Dictionary = action["effect"]
	for predicate in effect["del"]:
		next_state.erase(str(predicate))
	for predicate in effect["add"]:
		if not next_state.has(str(predicate)):
			next_state.append(str(predicate))
	next_state.sort()
	return next_state

func _state_key(state: Array[String]) -> String:
	var sorted_state := state.duplicate()
	sorted_state.sort()
	return "|".join(sorted_state)

func _reconstruct_plan(parents: Dictionary, goal_key: String) -> Array[String]:
	var result: Array[String] = []
	var current_key := goal_key
	while parents.has(current_key):
		var parent: Dictionary = parents[current_key]
		result.push_front(str(parent["action"]))
		current_key = str(parent["previous"])
	return result

func _fail(status: String, message: String) -> Array[String]:
	current_plan.clear()
	last_status = status
	last_error = message
	return []