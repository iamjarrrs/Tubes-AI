extends CanvasLayer

var npc: CharacterBody2D = null
var player: CharacterBody2D = null
var controller: Node = null
var buff_item: Area2D = null

var panel: PanelContainer
var content_label: RichTextLabel
var toggle_btn: Button
var ai_data: Dictionary = {}

func _ready() -> void:
	layer = 140
	_build_ui()
	_bind_targets()

func _bind_targets() -> void:
	var root := get_parent()
	if not root:
		return

	npc = root.find_child("BattleNPC", true, false) as CharacterBody2D
	if not npc:
		npc = root.find_child("NPC", true, false) as CharacterBody2D

	player = root.find_child("Player", true, false) as CharacterBody2D
	controller = root.find_child("NPCController", true, false)

	var buffs := get_tree().get_nodes_in_group("buff_items")
	if not buffs.is_empty():
		buff_item = buffs[0] as Area2D
	else:
		buff_item = root.find_child("BuffItem", true, false) as Area2D

func set_ai_debug_data(data: Dictionary) -> void:
	ai_data = data.duplicate(true)
	_refresh_display()

func _build_ui() -> void:
	toggle_btn = Button.new()
	toggle_btn.text = "[F3] AI Debug"
	toggle_btn.custom_minimum_size = Vector2(110.0, 26.0)
	toggle_btn.add_theme_font_size_override("font_size", 11)
	toggle_btn.pressed.connect(_on_toggle_pressed)
	add_child(toggle_btn)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.82)
	style.border_color = Color("4b91b8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

	content_label = RichTextLabel.new()
	content_label.bbcode_enabled = true
	content_label.fit_content = true
	content_label.scroll_active = false
	content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_label.custom_minimum_size = Vector2(300.0, 0.0)
	content_label.add_theme_font_size_override("normal_font_size", 11)
	content_label.add_theme_font_size_override("bold_font_size", 11)
	panel.add_child(content_label)

	add_child(panel)
	_position_panel()
	get_viewport().size_changed.connect(_position_panel)

func _position_panel() -> void:
	if not is_instance_valid(panel):
		return
	var vp_width := get_viewport().get_visible_rect().size.x
	panel.position = Vector2(maxf(10.0, vp_width - 334.0), 40.0)
	if is_instance_valid(toggle_btn):
		toggle_btn.position = Vector2(maxf(10.0, vp_width - 124.0), 10.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_on_toggle_pressed()
		get_viewport().set_input_as_handled()

func _on_toggle_pressed() -> void:
	panel.visible = not panel.visible

func _process(_delta: float) -> void:
	if not panel.visible:
		return
	if not is_instance_valid(npc) or not is_instance_valid(controller):
		_bind_targets()
	_refresh_display()

func _refresh_display() -> void:
	var lines: Array[String] = []

	lines.append("[b][color=#62b4a9]AI DEBUG OVERLAY[/color][/b] [color=#99a2a8]| %d FPS | [F11] Fullscreen[/color]" % Engine.get_frames_per_second())

	# 1. ANGGOTA 1: KBA
	var facts: Array = []
	var query_str: String = "GOAL"
	var answer_str: String = "pending"

	if not ai_data.is_empty():
		facts = ai_data.get("facts", [])
		query_str = str(ai_data.get("query", "GOAL"))
		answer_str = str(ai_data.get("answer", "pending"))
	elif is_instance_valid(controller) and "kb_engine" in controller and controller.kb_engine != null:
		facts = controller.kb_engine.get_facts()
		query_str = controller.kb_engine.last_query
		answer_str = controller.kb_engine.last_answer

	var goal_color := "#6b9c62" if answer_str == "GOAL_Seek_Buff" else "#e6ad62"
	lines.append("[b][color=#e6ad62]KBA:[/color][/b] Goal: [color=%s][b]%s[/b][/color] (Query: %s)" % [goal_color, answer_str, query_str])
	if not facts.is_empty():
		lines.append("[color=#7a8d9a]Facts: %s[/color]" % str(facts))

	# 2. ANGGOTA 2: PLANNER
	var current_plan: Array = []
	var active_step: String = "idle"
	var planner_status: String = "idle"
	var replanning_text: String = "no"

	if not ai_data.is_empty():
		current_plan = ai_data.get("plan", [])
		active_step = str(ai_data.get("step", "idle"))
		planner_status = str(ai_data.get("planner_status", "success"))
		replanning_text = str(ai_data.get("replanning", "no"))
	elif is_instance_valid(controller):
		current_plan = controller.get("current_plan") if "current_plan" in controller else []
		active_step = str(controller.get("current_step")) if "current_step" in controller else "idle"
		replanning_text = str(controller.get("replanning_note")) if "replanning_note" in controller else "no"
		if "planner" in controller and controller.planner != null:
			planner_status = str(controller.planner.last_status)

	lines.append("[b][color=#4b91b8]Planner:[/color][/b] Status: %s | Step: [color=#ffd166][b]%s[/b][/color]" % [planner_status, active_step])
	if not current_plan.is_empty():
		var plan_str := " -> ".join(current_plan)
		lines.append("[color=#7a8d9a]Plan: %s[/color]" % plan_str)
	if replanning_text != "no" and not replanning_text.is_empty():
		lines.append("[color=#e65f45][b]⚡ Replan:[/b] %s[/color]" % replanning_text)

	# 3. ANGGOTA 3: ARENA & MAP STATUS
	if is_instance_valid(npc):
		var dist_text := ""
		if is_instance_valid(player):
			dist_text = "Dist: %.0fpx" % npc.global_position.distance_to(player.global_position)

		var chest_status := "Peti: Ada"
		if not is_instance_valid(buff_item) or not buff_item.get("is_available"):
			chest_status = "Peti: [color=#e65f45]Diambil[/color]"

		var buff_status := "Buff: " + ("[color=#6b9c62]Ya[/color]" if (controller and controller.get("has_npc_buff")) else "Tdk")
		lines.append("[b][color=#62b4a9]Arena:[/color][/b] %s | %s | %s" % [dist_text, chest_status, buff_status])

	content_label.text = "\n".join(lines)
