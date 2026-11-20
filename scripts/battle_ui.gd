extends CanvasLayer

const BASE_HP := 100
const SUPER_EFFECTIVE := 1.25
const NOT_VERY_EFFECTIVE := 0.85
const MINIMAX_DEPTH := 2
const HEAL_AMOUNT := 25
const MAX_HEALS := 2

var game_state: Node
var mc_hp := BASE_HP
var npc_hp := BASE_HP
var mc_max_hp := BASE_HP
var npc_max_hp := BASE_HP
var mc_stats: Dictionary = {}
var npc_stats: Dictionary = {}
var guarding := false
var npc_guarding := false
var heals_used := 0
var turn_locked := false
var rng := RandomNumberGenerator.new()

var mc_hp_bar: ProgressBar
var npc_hp_bar: ProgressBar
var mc_hp_text: Label
var npc_hp_text: Label
var status_label: Label
var log_label: Label
var action_row: HBoxContainer
var result_row: HBoxContainer
var result_label: Label
var attack_button: Button
var guard_button: Button
var heal_button: Button

func _ready() -> void:
	layer = 230
	rng.randomize()
	game_state = get_node("/root/GameState")
	var mc_loadout: Dictionary = game_state.mc_loadout
	var npc_loadout: Dictionary = game_state.npc_loadout
	mc_stats = _total_stats(mc_loadout, game_state.mc_base_stats)
	npc_stats = _total_stats(npc_loadout, game_state.npc_base_stats)
	mc_max_hp = int(mc_stats["hp"])
	npc_max_hp = int(npc_stats["hp"])
	mc_hp = mc_max_hp
	npc_hp = npc_max_hp
	_build_ui(mc_loadout, npc_loadout)
	_refresh_health()
	status_label.text = "Giliran MC. Pilih serang atau bertahan."
	log_label.text = "Pertarungan dimulai. MC mendapat giliran pertama."

func _build_ui(mc_loadout: Dictionary, npc_loadout: Dictionary) -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = _map_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.025, 0.04, 0.045, 0.84)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title := _label("PERTARUNGAN", 30, Color("f0e9d2"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var fighters := HBoxContainer.new()
	fighters.add_theme_constant_override("separation", 16)
	content.add_child(fighters)
	fighters.add_child(_fighter_panel("MC", mc_loadout, mc_stats, true))
	var versus := _label("VS", 24, Color("e6ad62"))
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fighters.add_child(versus)
	fighters.add_child(_fighter_panel("NPC", npc_loadout, npc_stats, false))

	status_label = _label("", 18, Color("e8d29e"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status_label)

	log_label = _label("", 16, Color("e5e7df"))
	log_label.custom_minimum_size = Vector2(0.0, 52.0)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(log_label)

	action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	content.add_child(action_row)
	attack_button = _button("Serang", Color("b85e43"))
	attack_button.pressed.connect(_on_attack_pressed)
	action_row.add_child(attack_button)
	guard_button = _button("Bertahan", Color("4b91a0"))
	guard_button.pressed.connect(_on_guard_pressed)
	action_row.add_child(guard_button)
	heal_button = _button("Heal (%d)" % MAX_HEALS, Color("4c9b79"))
	heal_button.pressed.connect(_on_heal_pressed)
	action_row.add_child(heal_button)

	result_label = _label("", 25, Color("f0e9d2"))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.visible = false
	content.add_child(result_label)
	result_row = HBoxContainer.new()
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	result_row.add_theme_constant_override("separation", 12)
	result_row.visible = false
	content.add_child(result_row)
	var rematch_button := _button("Main Lagi", Color("4c9b79"))
	rematch_button.pressed.connect(_on_rematch_pressed)
	result_row.add_child(rematch_button)
	var return_button := _button("Kembali ke Map", Color("51666a"))
	return_button.pressed.connect(_on_return_pressed)
	result_row.add_child(return_button)

func _fighter_panel(fighter_name: String, loadout: Dictionary, stats: Dictionary, is_mc: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _fighter_style(is_mc))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var element := str(loadout.get("element", "Unknown")).to_upper()
	var title := _label("%s  |  %s" % [fighter_name, element], 19, Color("f0e9d2"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var item_names: Array[String] = []
	for category in ["weapon", "armor", "accessory"]:
		var item: Dictionary = loadout.get(category, {})
		var item_description := str(item.get("name", "None"))
		var reduction := int(item.get("damage_reduction", 0))
		if reduction > 0:
			item_description += " (-%d%% damage)" % reduction
		item_names.append(item_description)
	var equipment := _label("%s\n%s\n%s" % item_names, 13, Color("ccd1ca"))
	equipment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(equipment)
	var max_hp := mc_max_hp if is_mc else npc_max_hp
	var hp_text := _label("HP %d / %d" % [max_hp, max_hp], 15, Color("e7e8df"))
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hp_text)
	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = max_hp
	hp_bar.value = max_hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0.0, 16.0)
	content.add_child(hp_bar)
	var stats_text := _label("ATK %d   DEF %d" % [stats["attack"], stats["defense"]], 16, Color("e6ad62"))
	stats_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stats_text)
	if is_mc:
		mc_hp_bar = hp_bar
		mc_hp_text = hp_text
	else:
		npc_hp_bar = hp_bar
		npc_hp_text = hp_text
	return panel

func _on_attack_pressed() -> void:
	if turn_locked or _battle_finished():
		return
	turn_locked = true
	_set_actions_enabled(false)
	var damage := _calculate_damage(mc_stats, npc_stats, "mc")
	if npc_guarding:
		damage = maxi(1, ceili(float(damage) * 0.5))
		npc_guarding = false
	npc_hp = maxi(0, npc_hp - damage)
	_refresh_health()
	log_label.text = "MC menyerang dan memberi %d damage." % damage
	if npc_hp <= 0:
		_finish_battle(true)
		return
	_start_npc_turn()

func _on_guard_pressed() -> void:
	if turn_locked or _battle_finished():
		return
	turn_locked = true
	guarding = true
	_set_actions_enabled(false)
	log_label.text = "MC bersiap bertahan. Damage serangan NPC berikutnya berkurang 50%."
	_start_npc_turn()

func _on_heal_pressed() -> void:
	if turn_locked or _battle_finished() or heals_used >= MAX_HEALS or mc_hp >= mc_max_hp:
		return
	turn_locked = true
	_set_actions_enabled(false)
	var recovered := mini(HEAL_AMOUNT, mc_max_hp - mc_hp)
	mc_hp += recovered
	heals_used += 1
	_refresh_health()
	log_label.text = "MC memulihkan %d HP. Heal tersisa: %d." % [recovered, MAX_HEALS - heals_used]
	_start_npc_turn()

func _start_npc_turn() -> void:
	var npc_action := _choose_npc_action_minimax()
	status_label.text = "NPC memakai Minimax (depth %d)..." % MINIMAX_DEPTH
	var turn_timer := get_tree().create_timer(0.7)
	turn_timer.timeout.connect(_resolve_npc_turn.bind(npc_action), CONNECT_ONE_SHOT)

func _resolve_npc_turn(npc_action: String) -> void:
	if not is_instance_valid(self):
		return
	if npc_action == "guard":
		npc_guarding = true
	var damage := _calculate_damage(npc_stats, mc_stats, "npc")
	if npc_action == "guard":
		damage = maxi(1, roundi(float(damage) * 0.65))
	if guarding:
		damage = maxi(1, ceili(float(damage) * 0.5))
		guarding = false
	mc_hp = maxi(0, mc_hp - damage)
	_refresh_health()
	if npc_action == "guard":
		log_label.text += "\nNPC mengambil stance bertahan sambil counter, memberi %d damage." % damage
	else:
		log_label.text += "\nNPC menyerang dan memberi %d damage." % damage
	if mc_hp <= 0:
		_finish_battle(false)
		return
	status_label.text = "Giliran MC. Pilih serang atau bertahan."
	turn_locked = false
	_set_actions_enabled(true)

func _choose_npc_action_minimax() -> String:
	var best_action := "attack"
	var best_score := -INF
	var attack_score := _minimax_value(mc_hp, npc_hp, MINIMAX_DEPTH, true, guarding, npc_guarding, "attack")
	if attack_score > best_score:
		best_score = attack_score
	var guard_score := _minimax_value(mc_hp, npc_hp, MINIMAX_DEPTH, true, guarding, npc_guarding, "guard")
	if guard_score > best_score:
		best_action = "guard"
	return best_action

func _minimax_value(mc_health: int, npc_health: int, depth: int, npc_turn: bool, mc_guard: bool, npc_guard: bool, forced_npc_action: String = "") -> float:
	if depth <= 0 or mc_health <= 0 or npc_health <= 0:
		return _evaluate_battle_state(mc_health, npc_health, mc_guard, npc_guard)
	if npc_turn:
		var npc_best_score := -INF
		var actions: Array[String] = []
		if forced_npc_action.is_empty():
			actions.append_array(["attack", "guard"])
		else:
			actions.append(forced_npc_action)
		for action in actions:
			if action == "attack":
				var damage := _estimated_damage(npc_stats, mc_stats, "npc")
				if mc_guard:
					damage = maxi(1, ceili(float(damage) * 0.5))
				npc_best_score = maxf(npc_best_score, _minimax_value(mc_health - damage, npc_health, depth - 1, false, false, npc_guard))
			else:
				var counter_damage := maxi(1, roundi(float(_estimated_damage(npc_stats, mc_stats, "npc")) * 0.65))
				if mc_guard:
					counter_damage = maxi(1, ceili(float(counter_damage) * 0.5))
				npc_best_score = maxf(npc_best_score, _minimax_value(mc_health - counter_damage, npc_health, depth - 1, false, false, true))
		return npc_best_score
	var mc_best_score := INF
	for action in ["attack", "guard"]:
		if action == "attack":
			var damage := _estimated_damage(mc_stats, npc_stats, "mc")
			if npc_guard:
				damage = maxi(1, ceili(float(damage) * 0.5))
			mc_best_score = minf(mc_best_score, _minimax_value(mc_health, npc_health - damage, depth - 1, true, mc_guard, false))
		else:
			mc_best_score = minf(mc_best_score, _minimax_value(mc_health, npc_health, depth - 1, true, true, npc_guard))
	return mc_best_score

func _evaluate_battle_state(mc_health: int, npc_health: int, mc_guard: bool, npc_guard: bool) -> float:
	var score := float(npc_health - mc_health)
	if mc_guard:
		score -= float(_estimated_damage(npc_stats, mc_stats, "npc")) * 0.5
	if npc_guard:
		score += float(_estimated_damage(mc_stats, npc_stats, "mc")) * 0.5
	return score

func _estimated_damage(attacker: Dictionary, defender: Dictionary, side: String) -> int:
	var attacker_loadout: Dictionary = game_state.mc_loadout if side == "mc" else game_state.npc_loadout
	var defender_loadout: Dictionary = game_state.npc_loadout if side == "mc" else game_state.mc_loadout
	var multiplier := _element_multiplier(str(attacker_loadout.get("element", "")), str(defender_loadout.get("element", "")))
	var raw_damage := maxf(3.0, float(attacker["attack"]) * multiplier - float(defender["defense"]) * 0.5)
	return maxi(1, roundi(raw_damage * (1.0 - _damage_reduction(defender_loadout) / 100.0)))

func _calculate_damage(attacker: Dictionary, defender: Dictionary, side: String) -> int:
	var attacker_loadout: Dictionary = game_state.mc_loadout if side == "mc" else game_state.npc_loadout
	var defender_loadout: Dictionary = game_state.npc_loadout if side == "mc" else game_state.mc_loadout
	var multiplier := _element_multiplier(str(attacker_loadout.get("element", "")), str(defender_loadout.get("element", "")))
	var raw_damage := maxf(3.0, float(attacker["attack"]) * multiplier - float(defender["defense"]) * 0.5)
	var reduced_damage := raw_damage * (1.0 - _damage_reduction(defender_loadout) / 100.0)
	return maxi(1, roundi(reduced_damage * rng.randf_range(0.9, 1.1)))

func _damage_reduction(loadout: Dictionary) -> float:
	var accessory: Dictionary = loadout.get("accessory", {})
	return clampf(float(accessory.get("damage_reduction", 0)), 0.0, 75.0)

func _element_multiplier(attacker_element: String, defender_element: String) -> float:
	if (attacker_element == "Fire" and defender_element == "Nature") or (attacker_element == "Nature" and defender_element == "Water") or (attacker_element == "Water" and defender_element == "Fire"):
		return SUPER_EFFECTIVE
	if (attacker_element == "Nature" and defender_element == "Fire") or (attacker_element == "Water" and defender_element == "Nature") or (attacker_element == "Fire" and defender_element == "Water"):
		return NOT_VERY_EFFECTIVE
	return 1.0

func _finish_battle(mc_won: bool) -> void:
	turn_locked = true
	_set_actions_enabled(false)
	action_row.visible = false
	status_label.text = "Pertarungan selesai"
	result_label.text = "MC MENANG" if mc_won else "NPC MENANG"
	result_label.visible = true
	result_row.visible = true
	log_label.text += "\n%s." % ("NPC kehabisan HP" if mc_won else "MC kehabisan HP")

func _on_rematch_pressed() -> void:
	mc_hp = mc_max_hp
	npc_hp = npc_max_hp
	guarding = false
	npc_guarding = false
	heals_used = 0
	turn_locked = false
	result_label.visible = false
	result_row.visible = false
	action_row.visible = true
	_refresh_health()
	_set_actions_enabled(true)
	status_label.text = "Giliran MC. Pilih serang atau bertahan."
	log_label.text = "Rematch dimulai. MC mendapat giliran pertama."

func _on_return_pressed() -> void:
	_set_actions_enabled(false)
	var scene_changer := get_node_or_null("/root/SceneChanger")
	if scene_changer == null:
		status_label.text = "SceneChanger tidak tersedia."
		return
	var changed: bool = await scene_changer.call("change_scene_with_fade", "res://Tiled_files/dungeon_1.tscn")
	if changed:
		queue_free()
	else:
		status_label.text = "Tidak dapat kembali ke map utama."

func _refresh_health() -> void:
	if is_instance_valid(mc_hp_bar):
		mc_hp_bar.value = mc_hp
		mc_hp_text.text = "HP %d / %d" % [mc_hp, mc_max_hp]
	if is_instance_valid(npc_hp_bar):
		npc_hp_bar.value = npc_hp
		npc_hp_text.text = "HP %d / %d" % [npc_hp, npc_max_hp]

func _set_actions_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
	guard_button.disabled = not enabled
	heal_button.disabled = not enabled or heals_used >= MAX_HEALS or mc_hp >= mc_max_hp
	heal_button.text = "Heal (%d)" % (MAX_HEALS - heals_used)

func _battle_finished() -> bool:
	return mc_hp <= 0 or npc_hp <= 0

func _total_stats(loadout: Dictionary, base_stats: Dictionary) -> Dictionary:
	var totals := {
		"attack": int(base_stats.get("attack", 0)),
		"defense": int(base_stats.get("defense", 0)),
		"hp": int(base_stats.get("hp", BASE_HP)),
		"damage_reduction": 0
	}
	for category in ["weapon", "armor", "accessory"]:
		var item: Dictionary = loadout.get(category, {})
		totals["attack"] += int(item.get("atk", item.get("power", 0)))
		totals["defense"] += int(item.get("def", item.get("defense", 0)))
		totals["hp"] += int(item.get("hp", 0))
		totals["damage_reduction"] += int(item.get("damage_reduction", 0))
	return totals

func _map_texture() -> Texture2D:
	var map_name := str(game_state.selected_map).to_lower()
	var path := "res://assets/maps/map_aqua.jpg"
	if map_name.contains("forest"):
		path = "res://assets/maps/map_forest.jpg"
	elif map_name.contains("volcano"):
		path = "res://assets/maps/map_volcano.jpg"
	return load(path) as Texture2D

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180.0, 46.0)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("f4f1e8"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.lightened(0.16)
	button.add_theme_stylebox_override("hover", hover)
	return button

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("11191b", 0.97)
	style.border_color = Color("62b4a9")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	return style

func _fighter_style(is_mc: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20282c")
	style.border_color = Color("d97745") if is_mc else Color("4b91b8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	return style