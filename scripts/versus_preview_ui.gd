extends CanvasLayer

@onready var mc_cards: HBoxContainer = $CenterContainer/PanelContainer/Content/MCCards
@onready var npc_cards: HBoxContainer = $CenterContainer/PanelContainer/Content/NPCCards
@onready var game_state: Node = get_node("/root/GameState")

func _ready() -> void:
	_set_map_background()

	# 1. Ambil loadout MC
	var mc_loadout_variant = game_state.mc_loadout if "mc_loadout" in game_state else {}
	var mc_loadout: Dictionary = mc_loadout_variant if mc_loadout_variant is Dictionary else {}

	var mc_elem := str(mc_loadout.get("element", "Fire"))
	if mc_elem.is_empty():
		mc_elem = "Fire"

	var npc_source_variant = game_state.npc_loadout if "npc_loadout" in game_state else {}
	var npc_loadout: Dictionary = npc_source_variant if npc_source_variant is Dictionary else {}
	var npc_elem := str(npc_loadout.get("element", "Water"))
	if npc_elem.is_empty():
		npc_elem = "Water"


	# 5. Tampilkan ke UI
	$CenterContainer/PanelContainer/Content/MCName.text = "MC  |  ELEMENT: " + mc_elem.to_upper()
	$CenterContainer/PanelContainer/Content/NPCName.text = "NPC  |  ELEMENT: " + npc_elem.to_upper()
	_add_loadout_cards(mc_cards, mc_loadout)
	_add_loadout_cards(npc_cards, npc_loadout)
	$CenterContainer/PanelContainer/Content/StatsLabel.text = _make_stats_text(mc_loadout, npc_loadout)
	var start_button := TextureButton.new()
	start_button.custom_minimum_size = Vector2(300.0, 53.0)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	start_button.ignore_texture_size = true
	start_button.stretch_mode = TextureButton.STRETCH_SCALE
	start_button.texture_normal = load("res://assets/maps/btn_lanjut_ke_arena_normal.png") as Texture2D
	start_button.texture_hover = load("res://assets/maps/btn_lanjut_ke_arena_hover.png") as Texture2D
	start_button.texture_pressed = load("res://assets/maps/btn_lanjut_ke_arena_pressed.png") as Texture2D
	start_button.texture_disabled = start_button.texture_normal
	start_button.pressed.connect(_on_start_battle_pressed)
	$CenterContainer/PanelContainer/Content.add_child(start_button)

func _on_start_battle_pressed() -> void:
	game_state.call("start_ai_planning_stage", self)
	queue_free()

func _set_map_background() -> void:
	var selected_map: String = str(game_state.get("selected_map")).to_lower()
	var background_path := "res://assets/maps/map_aqua.jpg"
	if selected_map.contains("forest"):
		background_path = "res://assets/maps/map_forest.jpg"
	elif selected_map.contains("volcano"):
		background_path = "res://assets/maps/map_volcano.jpg"
	$MapBackground.texture = load(background_path)

func _add_loadout_cards(container: HBoxContainer, loadout: Dictionary) -> void:
	for category in ["weapon", "armor", "accessory"]:
		var item: Dictionary = loadout.get(category, {})
		_add_card(container, category.capitalize(), item)

func _make_stats_text(mc_loadout: Dictionary, npc_loadout: Dictionary) -> String:
	var mc_stats := _total_stats(mc_loadout, game_state.mc_base_stats)
	var npc_stats := _total_stats(npc_loadout, game_state.npc_base_stats)
	return "MC [%s]  ATK %d  |  DEF %d  |  HP %d  |  WT %d/%d\nNPC [%s]  ATK %d  |  DEF %d  |  HP %d  |  WT %d/%d" % [
		str(mc_loadout.get("element", "None")).to_upper(), mc_stats["attack"], mc_stats["defense"], mc_stats["hp"],
		_loadout_weight(mc_loadout), game_state.MAX_LOADOUT_WEIGHT,
		str(npc_loadout.get("element", "None")).to_upper(), npc_stats["attack"], npc_stats["defense"],
		npc_stats["hp"], _loadout_weight(npc_loadout), game_state.MAX_LOADOUT_WEIGHT
	]

func _loadout_weight(loadout: Dictionary) -> int:
	var weight := 0
	for category in ["weapon", "armor", "accessory"]:
		var item: Dictionary = loadout.get(category, {})
		weight += int(item.get("weight", 0))
	return weight

func _total_stats(loadout: Dictionary, base_stats: Dictionary) -> Dictionary:
	var totals := {
		"attack": int(base_stats.get("attack", 0)),
		"defense": int(base_stats.get("defense", 0)),
		"hp": int(base_stats.get("hp", 100))
	}
	var equipment_stats := _equipment_stats(loadout)
	totals["attack"] += equipment_stats["attack"]
	totals["defense"] += equipment_stats["defense"]
	for category in ["weapon", "armor", "accessory"]:
		var item: Dictionary = loadout.get(category, {})
		totals["hp"] += int(item.get("hp", 0))
	return totals

func _equipment_stats(loadout: Dictionary) -> Dictionary:
	var totals := {"attack": 0, "defense": 0}
	for category in ["weapon", "armor", "accessory"]:
		var item: Dictionary = loadout.get(category, {})
		totals["attack"] += _item_stat(item, "atk", "power")
		totals["defense"] += _item_stat(item, "def", "defense")
	return totals

func _item_stat(item: Dictionary, primary_key: String, fallback_key: String) -> int:
	return int(item.get(primary_key, item.get(fallback_key, 0)))

func _add_card(container: HBoxContainer, category: String, item: Dictionary) -> void:
	var item_name := str(item.get("name", "Not selected"))
	var item_slot := VBoxContainer.new()
	item_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	item_slot.add_theme_constant_override("separation", 4)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(145, 190)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("11191b", 1.0)
	style.border_color = Color("62b4a9")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	card.add_theme_stylebox_override("panel", style)
	var artwork := TextureRect.new()
	artwork.custom_minimum_size = Vector2(139, 184)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var artwork_path := _get_artwork_path(category.to_lower(), item_name)
	if not artwork_path.is_empty():
		artwork.texture = load(artwork_path)
	card.add_child(artwork)
	item_slot.add_child(card)
	var item_details := Label.new()
	item_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_details.add_theme_font_size_override("font_size", 14)
	item_details.add_theme_color_override("font_color", Color("e6ad62"))
	item_details.text = "Berat: %d" % int(item.get("weight", 0))
	item_slot.add_child(item_details)
	container.add_child(item_slot)

func _get_artwork_path(category: String, item_name: String) -> String:
	var file_name := item_name
	if item_name == "Berserker Amulet":
		file_name = "Berseker Amulet"
	var category_directory := ""
	match category:
		"weapon":
			category_directory = "equipment/weapons"
		"armor":
			category_directory = "equipment/armor"
		"accessory":
			category_directory = "equipment/accessories"
		_:
			return ""
	var path := "res://assets/%s/%s.jpg" % [category_directory, file_name]
	return path if ResourceLoader.exists(path) else ""
