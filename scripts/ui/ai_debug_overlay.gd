extends CanvasLayer

var npc: CharacterBody2D = null
var player: CharacterBody2D = null
var controller: Node = null
var panel: PanelContainer
var content_label: RichTextLabel
var toggle_btn: Button
var menu_panel: PanelContainer
var menu_buttons: Dictionary = {}
var ai_data: Dictionary = {}
var active_section := ""
var menu_animation: Tween

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

func set_ai_debug_data(data: Dictionary) -> void:
	ai_data = data.duplicate(true)
	_refresh_display()

func _build_ui() -> void:
	toggle_btn = Button.new()
	toggle_btn.custom_minimum_size = Vector2(38.0, 38.0)
	toggle_btn.tooltip_text = "Menu debug AI [F3]"
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.pressed.connect(_toggle_menu)

	var toggle_tex := load("res://assets/ui/btn_menu_toggle.png") as Texture2D
	if toggle_tex:
		var empty_style := StyleBoxEmpty.new()
		toggle_btn.add_theme_stylebox_override("normal", empty_style)
		toggle_btn.add_theme_stylebox_override("hover", empty_style)
		toggle_btn.add_theme_stylebox_override("pressed", empty_style)
		toggle_btn.icon = toggle_tex
		toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		toggle_btn.expand_icon = true
	else:
		toggle_btn.add_theme_stylebox_override("normal", _button_style(Color("11191b"), Color("4b91b8")))
		toggle_btn.add_theme_stylebox_override("hover", _button_style(Color("20282c"), Color("62b4a9")))
		toggle_btn.add_theme_stylebox_override("pressed", _button_style(Color("20282c"), Color("e6ad62")))
		for index in range(3):
			var line := ColorRect.new()
			line.position = Vector2(11.0, 9.0 + index * 7.0)
			line.size = Vector2(16.0, 2.0)
			line.color = Color("e5e7df")
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			toggle_btn.add_child(line)
	add_child(toggle_btn)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())

	content_label = RichTextLabel.new()
	content_label.bbcode_enabled = true
	content_label.fit_content = true
	content_label.scroll_active = false
	content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_label.custom_minimum_size = Vector2(300.0, 0.0)
	content_label.add_theme_font_size_override("normal_font_size", 12)
	content_label.add_theme_font_size_override("bold_font_size", 12)
	panel.add_child(content_label)
	add_child(panel)
	panel.visible = false

	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(148.0, 0.0)
	menu_panel.add_theme_stylebox_override("panel", _menu_panel_style())
	var menu_content := VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 4)
	menu_panel.add_child(menu_content)
	add_child(menu_panel)
	menu_panel.visible = false
	menu_panel.pivot_offset = Vector2(148.0, 0.0)
	_add_menu_button(menu_content, "KB", "kb")
	_add_menu_button(menu_content, "Planner", "planner")
	_add_menu_button(menu_content, "Decision", "decision")

	_position_panel()
	get_viewport().size_changed.connect(_position_panel)

func _position_panel() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(toggle_btn):
		return
	var vp_width := get_viewport().get_visible_rect().size.x
	var panel_width := minf(390.0, vp_width - 20.0)
	panel.custom_minimum_size = Vector2(panel_width, 180.0)
	content_label.custom_minimum_size = Vector2(panel_width - 76.0, 0.0)
	toggle_btn.position = Vector2(maxf(10.0, vp_width - 48.0), 8.0)
	panel.position = Vector2(maxf(10.0, vp_width - panel_width - 10.0), 48.0)
	menu_panel.position = Vector2(maxf(10.0, vp_width - 158.0), 48.0)
	menu_panel.size = Vector2(148.0, menu_panel.get_combined_minimum_size().y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if menu_panel.visible:
			_hide_menu()
		elif active_section.is_empty():
			_toggle_menu()
		else:
			panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _add_menu_button(container: VBoxContainer, title: String, section: String) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(128.0, 34.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("e5e7df"))
	button.pressed.connect(_select_section.bind(section))
	container.add_child(button)
	menu_buttons[section] = button
	_style_menu_button(button, section == active_section)

func _style_menu_button(button: Button, selected: bool) -> void:
	var tex := load("res://assets/ui/btn_tab_normal.png") as Texture2D
	if tex:
		var normal := StyleBoxTexture.new()
		normal.texture = tex
		normal.texture_margin_left = 20.0
		normal.texture_margin_right = 20.0
		normal.texture_margin_top = 12.0
		normal.texture_margin_bottom = 12.0
		normal.modulate_color = Color(1.15, 1.15, 1.0) if selected else Color(0.85, 0.85, 0.85, 0.92)

		var hover := StyleBoxTexture.new()
		hover.texture = tex
		hover.texture_margin_left = 20.0
		hover.texture_margin_right = 20.0
		hover.texture_margin_top = 12.0
		hover.texture_margin_bottom = 12.0
		hover.modulate_color = Color(1.3, 1.25, 0.8)

		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		return

	var accent := Color("62b4a9") if selected else Color("344247")
	button.add_theme_stylebox_override("normal", _button_style(Color("182124"), accent))
	button.add_theme_stylebox_override("hover", _button_style(Color("253236"), Color("e6ad62")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("253236"), Color("e6ad62")))

func _select_section(section: String) -> void:
	active_section = section
	panel.visible = true
	_hide_menu()
	for key in menu_buttons:
		_style_menu_button(menu_buttons[key], key == active_section)
	_refresh_display()
	panel.reset_size()

func _toggle_menu() -> void:
	if menu_panel.visible:
		_hide_menu()
		return
	menu_panel.visible = true
	menu_panel.scale = Vector2(1.0, 0.02)
	menu_panel.modulate.a = 0.0
	menu_animation = create_tween().set_parallel(true)
	menu_animation.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	menu_animation.tween_property(menu_panel, "scale", Vector2.ONE, 0.18)
	menu_animation.tween_property(menu_panel, "modulate:a", 1.0, 0.18)

func _hide_menu() -> void:
	if is_instance_valid(menu_animation):
		menu_animation.kill()
	menu_panel.visible = false
	menu_panel.scale = Vector2.ONE
	menu_panel.modulate = Color.WHITE

func _process(_delta: float) -> void:
	if active_section.is_empty():
		return
	if not is_instance_valid(npc) or not is_instance_valid(controller):
		_bind_targets()
	if panel.visible:
		_refresh_display()

func _refresh_display() -> void:
	if active_section.is_empty():
		return
	var lines: Array[String] = []
	var section_title := "KB"
	match active_section:
		"kb":
			section_title = "KB"
			_append_kb(lines)
		"planner":
			section_title = "Planner"
			_append_planner(lines)
		"decision":
			section_title = "Decision"
			_append_decision(lines)
	lines.push_front("[b][color=#62b4a9]%s[/color][/b] [color=#99a2a8]%d FPS[/color]" % [section_title, Engine.get_frames_per_second()])
	_append_arena(lines)
	content_label.text = "\n".join(lines)

func _append_kb(lines: Array[String]) -> void:
	var facts: Array = ai_data.get("facts", [])
	var answer := str(ai_data.get("answer", "pending"))
	var goal_color := "#6b9c62" if answer == "GOAL_Seek_Buff" else "#e6ad62"
	lines.append("Goal  [color=%s][b]%s[/b][/color]" % [goal_color, answer])
	if not facts.is_empty():
		var clean_facts: Array[String] = []
		for f in facts:
			clean_facts.append(str(f))
		lines.append("Fakta  [color=#8a9ba8]%s[/color]" % ", ".join(clean_facts))

func _append_planner(lines: Array[String]) -> void:
	var status := str(ai_data.get("planner_status", "idle"))
	var status_color := "#6b9c62" if status == "success" else ("#e65f45" if status in ["unreachable", "domain_error"] else "#e6ad62")
	lines.append("Status  [color=%s][b]%s[/b][/color]" % [status_color, status.to_upper()])
	lines.append("Langkah  [b][color=#ffd166]%s[/color][/b]" % str(ai_data.get("step", "idle")))

	var plan: Array = ai_data.get("plan", [])
	if not plan.is_empty():
		lines.append("Rencana  [color=#6b9c62]%s[/color]" % " -> ".join(plan))

	var pddl_predicates: Array = ai_data.get("predicates", [])
	if not pddl_predicates.is_empty():
		lines.append("Predikat  [color=#62b4a9][%s][/color]" % ", ".join(pddl_predicates))

	var replanning := str(ai_data.get("replanning", "no"))
	if replanning != "no" and not replanning.is_empty():
		lines.append("Replan  [color=#e65f45]%s[/color]" % replanning)
	var planner_error := str(ai_data.get("planner_error", ""))
	if not planner_error.is_empty():
		lines.append("Error  [color=#e65f45]%s[/color]" % planner_error)

func _append_decision(lines: Array[String]) -> void:
	var decision: Dictionary = ai_data.get("decision", {})
	if decision.is_empty():
		lines.append("Menunggu keputusan")
		return
	var values: Dictionary = decision.get("action_values", {})
	var state := str(decision.get("state", "unknown"))
	lines.append("Policy  [b]%s[/b]" % str(decision.get("action", "pending")))
	lines.append("State  %s" % state)
	lines.append("Utility  Buff %.2f  |  Direct %.2f" % [float(values.get("SEEK_BUFF", 0.0)), float(values.get("DIRECT_ENGAGE", 0.0))])
	lines.append("Belief  %.1f%%" % (float(decision.get("belief_success", 0.0)) * 100.0))
	if state in ["need_buff_safe", "need_buff_medium", "need_buff_risky"]:
		var transitions: Dictionary = decision.get("transitions", {})
		var seek_transitions: Dictionary = transitions.get("SEEK_BUFF", {})
		var success_probability := float(seek_transitions.get("buff_secured", 0.0))
		var failure_target := "buff_unavailable"
		for target in seek_transitions:
			if target != "buff_secured" and float(seek_transitions[target]) > 0.0:
				failure_target = str(target)
		var rewards: Dictionary = decision.get("rewards", {})
		var seek_rewards: Dictionary = rewards.get("SEEK_BUFF", {})
		lines.append("Transisi  Sukses %.0f%%  |  Gagal %.0f%% ke %s" % [success_probability * 100.0, (1.0 - success_probability) * 100.0, failure_target])
		lines.append("Reward  +%.0f  |  Gagal %.0f  |  Direct %.0f" % [float(seek_rewards.get("success", 0.0)), float(seek_rewards.get("failure", 0.0)), float(rewards.get("DIRECT_ENGAGE", 0.0))])
	lines.append("Observasi  %s" % str(decision.get("observation", "Belum ada")))
	var mc_distance := float(decision.get("mc_buff_distance", -1.0))
	var npc_distance := float(decision.get("npc_buff_distance", -1.0))
	if mc_distance >= 0.0 and npc_distance >= 0.0:
		lines.append("Jarak buff  MC %.0f  |  NPC %.0f" % [mc_distance, npc_distance])
	lines.append("Gamma %.2f  |  Iterasi %d" % [float(decision.get("discount_factor", 0.0)), int(decision.get("iterations", 0))])
	lines.append("Alasan  %s" % str(decision.get("reason", "-")))

func _append_arena(lines: Array[String]) -> void:
	if not is_instance_valid(npc):
		return
	var details: Array[String] = []
	if is_instance_valid(player):
		details.append("Jarak %.0fpx" % npc.global_position.distance_to(player.global_position))
	if is_instance_valid(controller):
		var item_avail: bool = bool(controller.get("item_available"))
		var player_took: bool = bool(controller.get("player_buffed"))
		var npc_used: bool = bool(controller.get("npc_buff_used"))
		var npc_has: bool = bool(controller.get("has_npc_buff"))

		if item_avail:
			details.append("[color=#6b9c62]Peti: Ada[/color]")
			details.append("[color=#7a8d9a]Buff: Belum Diambil[/color]")
		elif player_took:
			details.append("[color=#ffd166]Peti: Diambil MC[/color]")
			details.append("[color=#e65f45]NPC: Tanpa Buff[/color]")
		elif npc_used:
			details.append("[color=#62b4a9]Peti: Diambil NPC[/color]")
			details.append("[color=#6b9c62]NPC: Buff Aktif (+10)[/color]")
		elif npc_has:
			details.append("[color=#62b4a9]Peti: Diambil NPC[/color]")
			details.append("[color=#ffd166]NPC: Bawa Buff[/color]")
		else:
			details.append("[color=#7a8d9a]Peti: Diambil[/color]")
			details.append("[color=#7a8d9a]NPC: Tanpa Buff[/color]")
	lines.append("[color=#62b4a9]Arena[/color]  %s" % "  |  ".join(details))

func _panel_style() -> StyleBox:
	var tex := load("res://assets/ui/debug_panel_frame.png") as Texture2D
	if tex:
		var style := StyleBoxTexture.new()
		style.texture = tex
		style.texture_margin_left = 34.0
		style.texture_margin_right = 34.0
		style.texture_margin_top = 58.0
		style.texture_margin_bottom = 58.0
		style.content_margin_left = 38.0
		style.content_margin_right = 38.0
		style.content_margin_top = 58.0
		style.content_margin_bottom = 58.0
		return style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.94)
	style.border_color = Color("4b91b8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _menu_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.94)
	style.border_color = Color("9e7d3b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	return style
