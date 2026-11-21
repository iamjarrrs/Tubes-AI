extends CanvasLayer

var debug_panel: PanelContainer
var debug_label: Label
var ai_data: Dictionary = {}

func _ready() -> void:
	layer = 120
	visible = false
	debug_panel = PanelContainer.new()
	debug_panel.custom_minimum_size = Vector2(320.0, 0.0)
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.07, 0.08, 0.94)
	panel_style.border_color = Color("62b4a9")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_top = 7.0
	panel_style.content_margin_bottom = 7.0
	debug_panel.add_theme_stylebox_override("panel", panel_style)
	debug_label = Label.new()
	debug_label.add_theme_color_override("font_color", Color("f4f1e8"))
	debug_label.add_theme_font_size_override("font_size", 11)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_panel.add_child(debug_label)
	add_child(debug_panel)
	_position_panel()
	get_viewport().size_changed.connect(_position_panel)

func _position_panel() -> void:
	if not is_instance_valid(debug_panel):
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	debug_panel.position = Vector2(maxf(8.0, viewport_width - 334.0), 14.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()

func set_ai_debug_data(data: Dictionary) -> void:
	ai_data = data.duplicate(true)
	visible = true
	_refresh_text()

func _process(_delta: float) -> void:
	if visible:
		_refresh_text()

func _refresh_text() -> void:
	var lines: Array[String] = [
		"GAMEPLAY DEBUG  [F3]",
		"FPS: %d" % Engine.get_frames_per_second(),
		"AI: CSP + Simulated Annealing",
		"NPC battle policy: Minimax (depth 2)"
	]
	if not ai_data.is_empty():
		lines.append("TELL facts: %s" % str(ai_data.get("facts", [])))
		lines.append("ASK query: %s" % str(ai_data.get("query", "GOAL")))
		lines.append("Answer: %s" % str(ai_data.get("answer", "pending")))
		lines.append("Planner: %s" % str(ai_data.get("plan", [])))
		lines.append("Step: %s" % str(ai_data.get("step", "idle")))
		lines.append("Replanning: %s" % str(ai_data.get("replanning", "no")))
		if not str(ai_data.get("planner_status", "")).is_empty():
			lines.append("Planner status: %s" % str(ai_data["planner_status"]))
		if not str(ai_data.get("planner_error", "")).is_empty():
			lines.append("Planner error: %s" % str(ai_data["planner_error"]))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var npc := get_tree().current_scene.get_node_or_null("BattleNPC") as Node2D
	if player:
		lines.append("MC position: %s" % str(player.global_position.round()))
	if npc:
		lines.append("NPC position: %s" % str(npc.global_position.round()))
		if player:
			lines.append("Distance: %.1f px" % npc.global_position.distance_to(player.global_position))
		var path: Variant = npc.get("current_path")
		var path_count: int = path.size() if path is PackedVector2Array else 0
		lines.append("NPC path points: %d" % path_count)
	debug_label.text = "\n".join(lines)
