extends Node

const PLANNER_SCRIPT := preload("res://scripts/ai/automated_planner.gd")
const KB_ENGINE_SCRIPT := preload("res://scripts/ai/kb_engine.gd")
const BUFF_ITEM_SCRIPT := preload("res://scripts/entities/buff_item.gd")
const ENGAGE_DISTANCE := 36.0

var map_root: Node2D
var player: CharacterBody2D
var npc: CharacterBody2D
var game_state: Node
var kb_engine
var planner
var buff_item: Area2D
var overlay: CanvasLayer
var predicates: Array[String] = []
var current_plan: Array[String] = []
var plan_index := 0
var current_step := "idle"
var goal_answer := ""
var moving_step := false
var has_npc_buff := false
var item_available := true
var ai_started := false
var transition_started := false
var replanning_note := "no"
var item_world_position := Vector2.ZERO
var player_buffed := false
var awaiting_battle_start := false
var battle_prompt: CanvasLayer
var prompt_title_label: Label
var prompt_subtitle_label: Label
var npc_sought_buff := false
var npc_buff_used := false

func _ready() -> void:
	map_root = get_parent() as Node2D
	game_state = get_node_or_null("/root/GameState")
	player = map_root.find_child("Player", true, false) as CharacterBody2D
	npc = map_root.get_node_or_null("BattleNPC") as CharacterBody2D
	overlay = map_root.get_node_or_null("GameplayDebugOverlay") as CanvasLayer
	if player == null or npc == null or game_state == null:
		push_error("NPCController: map requires Player, BattleNPC, and GameState.")
		queue_free()
		return

	if not npc.is_connected("navigation_target_reached", _on_navigation_target_reached):
		npc.connect("navigation_target_reached", _on_navigation_target_reached)

	kb_engine = KB_ENGINE_SCRIPT.new()
	planner = PLANNER_SCRIPT.new()

	var background := _get_map_background()
	if game_state and game_state.has_method("ensure_arena_camera"):
		game_state.call("ensure_arena_camera", player, background)
	item_world_position = background.global_position if background else (player.global_position + Vector2(160.0, -100.0))
	item_world_position += Vector2(0.0, 60.0)

	buff_item = BUFF_ITEM_SCRIPT.new() as Area2D
	buff_item.global_position = item_world_position
	map_root.add_child(buff_item)
	buff_item.connect("collected", _on_item_collected)

	if overlay and overlay.has_method("set_ai_debug_data"):
		overlay.visible = true

	npc.call("begin_planner_control")
	npc.set_physics_process(true)
	player.set_physics_process(true)
	ai_started = true

	_replan("Memulai evaluasi KBA & Perencanaan NPC")

func _process(_delta: float) -> void:
	if not ai_started or transition_started or not is_instance_valid(npc):
		return

	# Deteksi kedekatan dengan peti saat NPC menuju peti
	if moving_step and current_step == "move_to_chest":
		if is_instance_valid(buff_item) and item_available:
			var dist_to_item := npc.global_position.distance_to(buff_item.global_position)
			if dist_to_item <= 45.0:
				npc.call("stop_planner_navigation")
				_on_navigation_target_reached()

	_update_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if awaiting_battle_start and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		_start_battle()
		get_viewport().set_input_as_handled()

func _replan(reason: String) -> void:
	if transition_started:
		return

	npc_buff_used = false
	var percepts := _build_percepts()
	kb_engine.tell(percepts)
	var previous_goal := goal_answer
	goal_answer = kb_engine.ask("GOAL")

	if previous_goal != goal_answer:
		npc_sought_buff = goal_answer == "GOAL_Seek_Buff"

	var goal := "item_used AND at_mc" if goal_answer == "GOAL_Seek_Buff" else "at_mc"

	if goal_answer == "GOAL_Direct_Engage" and not predicates.has("at_mc"):
		predicates = ["at_start"]
	else:
		if predicates.is_empty():
			predicates = ["at_start", "item_available"]
			if not item_available:
				predicates = ["at_start"]

		var clean_predicates: Array[String] = []
		for predicate in predicates:
			if predicate != "item_available" or item_available:
				clean_predicates.append(predicate)
		predicates = clean_predicates

	var state := {
		"predicates": predicates.duplicate(),
		"context": {
			"item_id": "arena_buff",
			"item_position": item_world_position,
			"item_available": item_available,
			"npc_has_item": has_npc_buff
		}
	}

	var old_plan := current_plan.duplicate()
	current_plan = planner.update_request(state, goal)
	plan_index = 0
	moving_step = false
	replanning_note = "%s | %s" % [reason, "plan berubah" if old_plan != current_plan else "plan diperbarui"]

	if planner.last_status != "success":
		push_warning("NPCController planner %s: %s" % [planner.last_status, planner.last_error])

	# SKENARIO 2: NPC TIDAK BUTUH BUFF (GOAL_Direct_Engage)
	# Sesuai instruksi: NPC diam saja di tempatnya, membiarkan MC mengambil buff jika mau,
	# dan menunggu pemain menekan [B] untuk memulai pertarungan.
	if goal_answer == "GOAL_Direct_Engage" and not npc_sought_buff:
		npc.call("stop_planner_navigation")
		moving_step = false
		current_step = "standby_for_player"
		awaiting_battle_start = true
		_show_battle_prompt(
			"⚔️ NPC SIAP BERTARUNG (DIRECT ENGAGE)",
			"NPC merasa tidak butuh buff. Anda dapat mengambil buff di arena, lalu tekan [B] untuk Memulai Pertarungan."
		)
		_update_overlay()
		return

	_run_next_step()

func _run_next_step() -> void:
	if transition_started or plan_index >= current_plan.size():
		return

	current_step = current_plan[plan_index]
	moving_step = current_step in ["move_to_chest", "move_to_mc"]
	_update_overlay()

	if current_step == "move_to_chest":
		if not item_available or not is_instance_valid(buff_item):
			_replan("Item diambil sebelum NPC tiba")
			return
		npc.call("set_planner_target", item_world_position)
	elif current_step == "move_to_mc":
		# Sesuai instruksi: jika NPC butuh buff dan sudah mengambilnya,
		# NPC tidak perlu pathfinding ke MC! NPC diam di tempat dan menunggu [B]
		if npc_sought_buff:
			_standby_after_buff()
			return
		npc.call("set_planner_target", player.global_position)
	else:
		# Aksi instan (take_item, use_item)
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self) or transition_started:
			return
		_execute_instant_action(current_step)

func _on_navigation_target_reached() -> void:
	if not moving_step or transition_started:
		return
	moving_step = false

	if current_step == "move_to_chest":
		if not item_available or not is_instance_valid(buff_item):
			_replan("Item tidak lagi tersedia saat NPC tiba")
			return
		_update_predicates(["at_item"], ["at_start"])
		plan_index += 1
		_run_next_step()
	elif current_step == "move_to_mc":
		_update_predicates(["at_mc"], ["at_item"])
		_finish_navigation()

func _execute_instant_action(action_name: String) -> void:
	if action_name == "take_item":
		if not item_available or not is_instance_valid(buff_item):
			_replan("Item diambil MC sebelum NPC")
			return
		if is_instance_valid(buff_item):
			buff_item.collect(npc)
	elif action_name == "use_item":
		if has_npc_buff:
			has_npc_buff = false
			npc_buff_used = true
			game_state.npc_base_stats["attack"] = int(game_state.npc_base_stats.get("attack", 30)) + 10
		_update_predicates(["item_used"], ["has_item"])

		# SKENARIO 1: NPC SUDAH MENGAMBIL DAN MEMAKAI BUFF
		# Sesuai instruksi: NPC TIDAK PERLU pathfinding ke MC!
		# NPC diam di tempat, dan menunggu MC menekan tombol [B]!
		_standby_after_buff()

func _standby_after_buff() -> void:
	npc.call("stop_planner_navigation")
	moving_step = false
	current_step = "buff_acquired_standby"
	awaiting_battle_start = true
	_show_battle_prompt(
		"✨ NPC SUDAH MENGAMBIL BUFF (+10 ATK)!",
		"NPC telah diperkuat dan siap bertarung di posisinya. Tekan [B] atau klik tombol di bawah untuk Memulai Pertarungan."
	)
	_update_overlay()

func _on_item_collected(by: Node) -> void:
	if transition_started:
		return
	item_available = false

	# Jika NPC yang mengambil buff:
	if by == npc or (is_instance_valid(by) and by.name == "BattleNPC"):
		if not has_npc_buff:
			has_npc_buff = true
			_update_predicates(["has_item"], ["item_available"])
			plan_index += 1
			_run_next_step()
		return

	# Jika MC (Player) yang mengambil buff:
	if by == player and not player_buffed:
		player_buffed = true
		game_state.mc_base_stats["attack"] = int(game_state.mc_base_stats.get("attack", 30)) + 10
		_update_predicates([], ["item_available"])

		# Jika tadinya NPC sedang berniat mencari buff, picu Dynamic Replanning
		if goal_answer == "GOAL_Seek_Buff":
			npc.call("stop_planner_navigation")
			moving_step = false
			current_step = "standby_for_player"
			awaiting_battle_start = true
			_show_battle_prompt(
				"⚡ MC MENGAMBIL BUFF (+10 ATK) DULUAN!",
				"Peti habis! NPC beralih siap bertarung. Tekan [B] untuk Memulai Pertarungan Minimax."
			)
			_replan("MC mengambil buff; KB dan planner beralih direct engage")

func _update_predicates(add: Array[String], remove: Array[String]) -> void:
	for predicate in remove:
		predicates.erase(predicate)
	for predicate in add:
		if not predicates.has(predicate):
			predicates.append(predicate)

func _build_percepts() -> Dictionary:
	var mc_loadout: Dictionary = game_state.mc_loadout
	var npc_loadout: Dictionary = game_state.npc_loadout
	var mc_stats := _total_stats(mc_loadout, game_state.mc_base_stats)
	var npc_stats := _total_stats(npc_loadout, game_state.npc_base_stats)

	var mc_elem := str(mc_loadout.get("element", ""))
	var npc_elem := str(npc_loadout.get("element", ""))

	# Default fallback jika arena dijalankan langsung (testing):
	# Pasang kondisi disadvantage (MC Fire vs NPC Nature) agar NPC butuh buff!
	if mc_elem.is_empty() and npc_elem.is_empty():
		mc_elem = "Fire"
		npc_elem = "Nature"
		mc_stats["attack"] = 35
		npc_stats["attack"] = 30

	return {
		"mc_element": mc_elem,
		"npc_element": npc_elem,
		"mc_stats": mc_stats,
		"npc_stats": npc_stats,
		"chest_available": item_available
	}

func _total_stats(loadout: Dictionary, base_stats: Dictionary) -> Dictionary:
	var totals := {"attack": int(base_stats.get("attack", 30)), "defense": int(base_stats.get("defense", 0)), "hp": int(base_stats.get("hp", 100))}
	for category in ["weapon", "armor", "accessory"]:
		var item: Dictionary = loadout.get(category, {})
		totals["attack"] += int(item.get("atk", item.get("power", 0)))
		totals["defense"] += int(item.get("def", item.get("defense", 0)))
		totals["hp"] += int(item.get("hp", 0))
	return totals

func _finish_navigation() -> void:
	if transition_started:
		return
	transition_started = true
	awaiting_battle_start = true
	moving_step = false
	current_step = "arrived_at_mc"
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	npc.call("stop_planner_navigation")
	npc.set_physics_process(false)
	if overlay:
		overlay.visible = false
	_show_battle_prompt("NPC SIAP BERTARUNG", "Tekan [B] atau klik tombol di bawah untuk Memulai Pertarungan Minimax.")

func _show_battle_prompt(title_text: String = "NPC SIAP BERTARUNG", subtitle_text: String = "Tekan [B] untuk Memulai Pertarungan") -> void:
	if is_instance_valid(battle_prompt):
		if is_instance_valid(prompt_title_label):
			prompt_title_label.text = title_text
		if is_instance_valid(prompt_subtitle_label):
			prompt_subtitle_label.text = subtitle_text
		return

	battle_prompt = CanvasLayer.new()
	battle_prompt.name = "BattleStartPrompt"
	battle_prompt.layer = 220
	battle_prompt.process_mode = Node.PROCESS_MODE_ALWAYS

	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_prompt.add_child(screen)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -170.0
	center.offset_bottom = -20.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500.0, 140.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.075, 0.96)
	panel_style.border_color = Color("e6ad62")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	prompt_title_label = Label.new()
	prompt_title_label.text = title_text
	prompt_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_title_label.add_theme_font_size_override("font_size", 18)
	prompt_title_label.add_theme_color_override("font_color", Color("f0e9d2"))
	content.add_child(prompt_title_label)

	prompt_subtitle_label = Label.new()
	prompt_subtitle_label.text = subtitle_text
	prompt_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_subtitle_label.add_theme_font_size_override("font_size", 12)
	prompt_subtitle_label.add_theme_color_override("font_color", Color("e6ad62"))
	content.add_child(prompt_subtitle_label)

	var start_button := Button.new()
	start_button.name = "StartBattleButton"
	start_button.text = "MULAI PERTARUNGAN  [B]"
	start_button.custom_minimum_size = Vector2(280.0, 42.0)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.add_theme_font_size_override("font_size", 15)
	start_button.pressed.connect(_start_battle)
	content.add_child(start_button)

	get_tree().root.add_child(battle_prompt)

func _start_battle() -> void:
	if not awaiting_battle_start:
		return
	awaiting_battle_start = false
	transition_started = true

	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
	if is_instance_valid(npc):
		npc.call("stop_planner_navigation")
		npc.set_physics_process(false)
	if is_instance_valid(overlay):
		overlay.visible = false

	var battle_script := load("res://scripts/battle_ui.gd") as Script
	if battle_script == null:
		push_error("Could not load battle UI script.")
		awaiting_battle_start = true
		return

	var battle_ui := battle_script.new() as CanvasLayer
	if battle_ui == null:
		push_error("Could not create battle UI.")
		awaiting_battle_start = true
		return
	battle_ui.layer = 230
	get_tree().root.add_child(battle_ui)

	if is_instance_valid(battle_prompt):
		battle_prompt.queue_free()

func _get_map_background() -> Sprite2D:
	for child in map_root.get_children():
		if child is Sprite2D and child.texture:
			return child as Sprite2D
	return null

func _update_overlay() -> void:
	if overlay == null or not overlay.has_method("set_ai_debug_data"):
		return
	overlay.call("set_ai_debug_data", {
		"facts": kb_engine.get_facts() if kb_engine else [],
		"query": kb_engine.last_query if kb_engine else "GOAL",
		"answer": goal_answer,
		"plan": current_plan,
		"step": current_step,
		"replanning": replanning_note,
		"planner_status": planner.last_status if planner else "",
		"planner_error": planner.last_error if planner else ""
	})
