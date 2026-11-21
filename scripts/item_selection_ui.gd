extends CanvasLayer

@export var category: String = "weapon"
@export var title_text: String = "PILIH ITEM"
@export var item_names: PackedStringArray = []

const NEXT_SCENES := {
	"weapon": "res://scenes/ui/ArmorSelectionUI.tscn",
	"armor": "res://scenes/ui/AccessorySelectionUI.tscn",
	"accessory": "res://scenes/ui/VersusPreviewUI.tscn"
}

const ELEMENT_COLORS := {
	"Fire": Color("d97745"),
	"Water": Color("4b91b8"),
	"Nature": Color("6b9c62"),
	"None": Color("7d8586")
}

@onready var card_container: HBoxContainer = $CenterContainer/PanelContainer/Content/ItemCards
@onready var game_state: Node = get_node("/root/GameState")
var weight_summary: Label

func _ready() -> void:
	var content: VBoxContainer = $CenterContainer/PanelContainer/Content
	content.get_node("Title").text = title_text
	weight_summary = Label.new()
	weight_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weight_summary.add_theme_font_size_override("font_size", 17)
	weight_summary.add_theme_color_override("font_color", Color("e6ad62"))
	content.add_child(weight_summary)
	content.move_child(weight_summary, 1)
	_set_map_background()
	_update_weight_summary()
	for index in range(item_names.size()):
		_add_item_card(item_names[index], index)

func _set_map_background() -> void:
	var selected_map: String = str(game_state.get("selected_map")).to_lower()
	var map_file := "map_aqua.jpg"
	if selected_map.contains("forest"):
		map_file = "map_forest.jpg"
	elif selected_map.contains("volcano"):
		map_file = "map_volcano.jpg"
	var background_path := "res://assets/maps/" + map_file
	if not ResourceLoader.exists(background_path):
		background_path = "res://map/" + map_file
	$MapBackground.texture = load(background_path)

func _add_item_card(item_name: String, index: int) -> void:
	var item_data := _make_item_data(item_name)
	var button := Button.new()
	button.name = item_name.replace(" ", "")
	button.custom_minimum_size = Vector2(210, 280)
	button.pivot_offset = button.custom_minimum_size / 2.0
	var projected_weight := _current_loadout_weight(category) + int(item_data.get("weight", 0))
	button.disabled = projected_weight > game_state.MAX_LOADOUT_WEIGHT
	if button.disabled:
		button.tooltip_text = "Melebihi batas bobot %d." % game_state.MAX_LOADOUT_WEIGHT
	var accent: Color = _get_item_color(item_name)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("11191b", 1.0)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 3.0
	normal.content_margin_right = 3.0
	normal.content_margin_top = 3.0
	normal.content_margin_bottom = 3.0
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.55)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var artwork_path := _get_artwork_path(item_name)
	if item_name == "None" or artwork_path.is_empty():
		var none_label := Label.new()
		none_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		none_label.text = item_name
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none_label.add_theme_font_size_override("font_size", 26)
		none_label.add_theme_color_override("font_color", Color("f4f1e8"))
		none_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(none_label)
	else:
		var artwork := TextureRect.new()
		artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		artwork.offset_left = 3.0
		artwork.offset_top = 3.0
		artwork.offset_right = -3.0
		artwork.offset_bottom = -3.0
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.texture = load(artwork_path)
		button.add_child(artwork)
	button.mouse_entered.connect(_on_card_hovered.bind(button, true))
	button.mouse_exited.connect(_on_card_hovered.bind(button, false))
	button.pressed.connect(_on_item_selected.bind(item_name))
	var card_slot := VBoxContainer.new()
	card_slot.custom_minimum_size = Vector2(button.custom_minimum_size.x, button.custom_minimum_size.y + 28.0)
	card_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	card_slot.add_theme_constant_override("separation", 4)
	button.size = button.custom_minimum_size
	card_slot.add_child(button)
	var item_details := Label.new()
	item_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_details.add_theme_font_size_override("font_size", 15)
	item_details.add_theme_color_override("font_color", Color("e6ad62") if not button.disabled else Color("c66b5d"))
	item_details.text = "Berat: %d" % int(item_data.get("weight", 0))
	card_slot.add_child(item_details)
	card_container.add_child(card_slot)
	_animate_card_entry(button, index)

func _animate_card_entry(card: Button, index: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	var resting_position := Vector2.ZERO
	card.position = resting_position + Vector2(0.0, -32.0)
	card.rotation_degrees = -3.0 if index % 2 == 0 else 3.0
	card.scale = Vector2(0.96, 0.96)
	card.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position", resting_position, 0.48).set_delay(index * 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation_degrees", 0.0, 0.42).set_delay(index * 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.4).set_delay(index * 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.24).set_delay(index * 0.09)

func _get_artwork_path(item_name: String) -> String:
	var file_name := item_name
	if item_name == "Berserker Amulet":
		file_name = "Berseker Amulet"
	var category_directory := ""
	match category:
		"weapon": category_directory = "equipment/weapons"
		"armor": category_directory = "equipment/armor"
		"accessory": category_directory = "equipment/accessories"
	var asset_path := "res://assets/%s/%s.jpg" % [category_directory, file_name]
	if ResourceLoader.exists(asset_path):
		return asset_path
	var legacy_path := "res://%s/%s.jpg" % [category.capitalize(), file_name]
	return legacy_path if ResourceLoader.exists(legacy_path) else ""

func _get_item_color(item_name: String) -> Color:
	for element in ELEMENT_COLORS:
		if item_name.to_lower().contains(element.to_lower()):
			return ELEMENT_COLORS[element]
	return Color("7baaa4")

func _on_card_hovered(button: Button, is_hovered: bool) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * (1.05 if is_hovered else 1.0), 0.14)

func _on_item_selected(item_name: String) -> void:
	var loadout: Dictionary = game_state.get("mc_loadout")
	var selected_item := _make_item_data(item_name)
	if _current_loadout_weight(category) + int(selected_item.get("weight", 0)) > game_state.MAX_LOADOUT_WEIGHT:
		return
	loadout[category] = selected_item
	game_state.set("mc_loadout", loadout)

	if category == "accessory":
		game_state.call("choose_npc_loadout")
		game_state.call("replace_draft_ui", self, NEXT_SCENES["accessory"])
		return

	var next_scene_path: String = NEXT_SCENES[category]
	game_state.call("replace_draft_ui", self, next_scene_path)

func _current_loadout_weight(excluded_category: String = "") -> int:
	var loadout: Dictionary = game_state.get("mc_loadout")
	var total_weight := 0
	for item_category in ["weapon", "armor", "accessory"]:
		if item_category == excluded_category:
			continue
		var item: Dictionary = loadout.get(item_category, {})
		total_weight += int(item.get("weight", 0))
	return total_weight

func _update_weight_summary() -> void:
	weight_summary.text = "Bobot terpasang: %d / %d" % [
		_current_loadout_weight(), game_state.MAX_LOADOUT_WEIGHT
	]

func _make_item_data(item_name: String) -> Dictionary:
	for item in game_state.call("get_item_catalog", category):
		if item["name"] == item_name:
			return item.duplicate(true)
	return {"name": item_name, "atk": 0, "power": 0, "def": 0, "defense": 0, "weight": 0, "hp": 0, "element": "Neutral"}
