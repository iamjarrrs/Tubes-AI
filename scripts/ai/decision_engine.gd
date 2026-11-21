extends RefCounted

const ACTION_SEEK_BUFF := "SEEK_BUFF"
const ACTION_DIRECT_ENGAGE := "DIRECT_ENGAGE"
const DISCOUNT_FACTOR := 0.9
const VALUE_ITERATION_LIMIT := 100
const VALUE_ITERATION_TOLERANCE := 0.0001
const REWARD_SEEK_SUCCESS := 10.0
const REWARD_DIRECT_ENGAGE := -2.0
const REWARD_FAILURE_SAFE := -1.0
const REWARD_FAILURE_MEDIUM := -4.0
const REWARD_FAILURE_RISKY := -8.0

const STATE_ADVANTAGE_OR_EQUAL := "advantage_or_equal"
const STATE_SAFE := "need_buff_safe"
const STATE_MEDIUM := "need_buff_medium"
const STATE_RISKY := "need_buff_risky"
const STATE_BUFF_SECURED := "buff_secured"
const STATE_BUFF_UNAVAILABLE := "buff_unavailable"
const STATE_DIRECT_READY := "direct_ready"

var belief_success := 0.65
var last_observation := "Belum ada observasi"
var current_state := STATE_MEDIUM
var selected_action := ACTION_DIRECT_ENGAGE
var action_values: Dictionary = {}
var policy: Dictionary = {}
var decision_reason := "Menunggu percept KB"
var value_iteration_iterations := 0

var _last_observation_key := ""
var _state_values: Dictionary = {}

func observe(observation: String) -> bool:
	var key := observation.strip_edges().to_lower()
	if key.is_empty() or key == _last_observation_key:
		return false

	var likelihood_if_success := 0.5
	var likelihood_if_failure := 0.5
	match key:
		"mc_far":
			likelihood_if_success = 0.8
			likelihood_if_failure = 0.3
		"mc_medium":
			likelihood_if_success = 0.5
			likelihood_if_failure = 0.5
		"mc_near":
			likelihood_if_success = 0.08
			likelihood_if_failure = 0.9
		"item_taken":
			likelihood_if_success = 0.001
			likelihood_if_failure = 0.999
		_:
			return false

	var success_weight := belief_success * likelihood_if_success
	var failure_weight := (1.0 - belief_success) * likelihood_if_failure
	var evidence_probability := success_weight + failure_weight
	if evidence_probability > 0.0:
		belief_success = clampf(success_weight / evidence_probability, 0.0, 1.0)

	_last_observation_key = key
	last_observation = _observation_label(key)
	return true

func decide(needs_buff: bool, item_available: bool, npc_has_buff: bool) -> Dictionary:
	if not needs_buff:
		current_state = STATE_ADVANTAGE_OR_EQUAL
		selected_action = ACTION_DIRECT_ENGAGE
		decision_reason = "KB menilai NPC tidak membutuhkan buff"
		_run_value_iteration()
		action_values = {ACTION_SEEK_BUFF: -10.0, ACTION_DIRECT_ENGAGE: 0.0}
		return get_debug_data()

	if npc_has_buff:
		current_state = STATE_BUFF_SECURED
		selected_action = ACTION_DIRECT_ENGAGE
		decision_reason = "NPC sudah mengamankan buff; tunggu pemicu battle"
		_run_value_iteration()
		action_values = {ACTION_SEEK_BUFF: -10.0, ACTION_DIRECT_ENGAGE: 0.0}
		return get_debug_data()

	if not item_available:
		current_state = STATE_BUFF_UNAVAILABLE
		selected_action = ACTION_DIRECT_ENGAGE
		decision_reason = "Buff tidak tersedia; pilih direct engage"
		_run_value_iteration()
		action_values = {ACTION_SEEK_BUFF: -10.0, ACTION_DIRECT_ENGAGE: 0.0}
		return get_debug_data()

	current_state = _state_from_observation()
	_run_value_iteration()
	action_values = _action_values_for(current_state)
	selected_action = ACTION_SEEK_BUFF if float(action_values[ACTION_SEEK_BUFF]) > float(action_values[ACTION_DIRECT_ENGAGE]) else ACTION_DIRECT_ENGAGE
	if selected_action == ACTION_SEEK_BUFF:
		decision_reason = "Expected utility mencari buff lebih tinggi"
	else:
		decision_reason = "Risiko gagal mengambil buff membuat direct engage lebih bernilai"
	return get_debug_data()

func get_debug_data() -> Dictionary:
	return {
		"state": current_state,
		"action": selected_action,
		"action_values": action_values.duplicate(true),
		"belief_success": belief_success,
		"observation": last_observation,
		"reason": decision_reason,
		"policy": policy.duplicate(true),
		"transitions": get_transition_model(current_state),
		"rewards": get_reward_model(current_state),
		"discount_factor": DISCOUNT_FACTOR,
		"iterations": value_iteration_iterations
	}

func get_transition_model(state: String) -> Dictionary:
	var failure_state := _failure_state_for(state)
	var success_probability := belief_success if state in [STATE_SAFE, STATE_MEDIUM, STATE_RISKY] else 0.0
	return {
		ACTION_SEEK_BUFF: {
			STATE_BUFF_SECURED: success_probability,
			failure_state: 1.0 - success_probability
		},
		ACTION_DIRECT_ENGAGE: {STATE_DIRECT_READY: 1.0}
	}

func get_reward_model(state: String) -> Dictionary:
	return {
		ACTION_SEEK_BUFF: {
			"success": REWARD_SEEK_SUCCESS,
			"failure": _failure_reward_for(state)
		},
		ACTION_DIRECT_ENGAGE: REWARD_DIRECT_ENGAGE if state in [STATE_SAFE, STATE_MEDIUM, STATE_RISKY] else 0.0
	}

func _state_from_observation() -> String:
	match _last_observation_key:
		"mc_far":
			return STATE_SAFE
		"mc_near":
			return STATE_RISKY
		_:
			return STATE_MEDIUM

func _run_value_iteration() -> void:
	var decision_states := [STATE_SAFE, STATE_MEDIUM, STATE_RISKY]
	_state_values = {
		STATE_SAFE: 0.0,
		STATE_MEDIUM: 0.0,
		STATE_RISKY: 0.0,
		STATE_BUFF_SECURED: 0.0,
		STATE_BUFF_UNAVAILABLE: 0.0,
		STATE_DIRECT_READY: 0.0
	}
	policy.clear()
	value_iteration_iterations = 0

	for iteration in range(VALUE_ITERATION_LIMIT):
		var updated_values: Dictionary = _state_values.duplicate(true)
		var largest_change := 0.0
		for state in decision_states:
			var values := _action_values_for_state(state, _state_values)
			var best_value := maxf(float(values[ACTION_SEEK_BUFF]), float(values[ACTION_DIRECT_ENGAGE]))
			updated_values[state] = best_value
			largest_change = maxf(largest_change, absf(best_value - float(_state_values[state])))
		_state_values = updated_values
		value_iteration_iterations = iteration + 1
		if largest_change <= VALUE_ITERATION_TOLERANCE:
			break

	for state in decision_states:
		var values := _action_values_for_state(state, _state_values)
		policy[state] = ACTION_SEEK_BUFF if float(values[ACTION_SEEK_BUFF]) > float(values[ACTION_DIRECT_ENGAGE]) else ACTION_DIRECT_ENGAGE
	policy[STATE_BUFF_SECURED] = ACTION_DIRECT_ENGAGE
	policy[STATE_BUFF_UNAVAILABLE] = ACTION_DIRECT_ENGAGE
	policy[STATE_DIRECT_READY] = ACTION_DIRECT_ENGAGE

func _action_values_for(state: String) -> Dictionary:
	return _action_values_for_state(state, _state_values)

func _action_values_for_state(state: String, values: Dictionary) -> Dictionary:
	var transitions := get_transition_model(state)
	var seek_transitions: Dictionary = transitions[ACTION_SEEK_BUFF]
	var seek_rewards: Dictionary = get_reward_model(state)[ACTION_SEEK_BUFF]
	var seek_value := 0.0
	for next_state in seek_transitions:
		var reward := float(seek_rewards["success"] if next_state == STATE_BUFF_SECURED else seek_rewards["failure"])
		seek_value += float(seek_transitions[next_state]) * (reward + DISCOUNT_FACTOR * float(values[next_state]))
	var direct_reward := float(get_reward_model(state)[ACTION_DIRECT_ENGAGE])
	var direct_value := direct_reward + DISCOUNT_FACTOR * float(values[STATE_DIRECT_READY])
	return {
		ACTION_SEEK_BUFF: seek_value,
		ACTION_DIRECT_ENGAGE: direct_value
	}

func _failure_state_for(state: String) -> String:
	match state:
		STATE_SAFE:
			return STATE_MEDIUM
		STATE_MEDIUM:
			return STATE_RISKY
		_:
			return STATE_BUFF_UNAVAILABLE

func _failure_reward_for(state: String) -> float:
	match state:
		STATE_MEDIUM:
			return REWARD_FAILURE_MEDIUM
		STATE_RISKY:
			return REWARD_FAILURE_RISKY
		_:
			return REWARD_FAILURE_SAFE

func _observation_label(key: String) -> String:
	match key:
		"mc_far":
			return "MC jauh dari buff"
		"mc_medium":
			return "MC berjarak sedang dari buff"
		"mc_near":
			return "MC dekat dengan buff"
		"item_taken":
			return "Buff sudah diambil"
		_:
			return key