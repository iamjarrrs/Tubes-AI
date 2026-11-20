extends CanvasLayer

const WEAPON_SELECTION_SCENE := "res://scenes/ui/WeaponSelectionUI.tscn"
const ELEMENT_COLORS := {
	"Fire": Color("d97745"),
	"Water": Color("4b91b8"),
	"Nature": Color("6b9c62")
}

@onready var game_state: Node = get_node("/root/GameState")

func _ready() -> void:
	_set_map_background()
	for element in ELEMENT_COLORS:
		var card: Button = $CenterContainer/PanelContainer/Content/ElementCards.get_node(element)
		card.pivot_offset = card.custom_minimum_size / 2.0
		_add_element_artwork(card, element)
		card.pressed.connect(_on_element_selected.bind(element))
		card.mouse_entered.connect(_on_card_hovered.bind(card, true))
		card.mouse_exited.connect(_on_card_hovered.bind(card, false))
		_style_card(card, ELEMENT_COLORS[element])

func _add_element_artwork(card: Button, element: String) -> void:
	var texture_path := "res://assets/elements/%s.jpg" % element.to_lower()
	if not ResourceLoader.exists(texture_path):
		return
	card.text = ""
	var artwork := TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.offset_left = 3.0
	artwork.offset_top = 3.0
	artwork.offset_right = -3.0
	artwork.offset_bottom = -3.0
	artwork.texture = load(texture_path)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(artwork)
	var nameplate := Label.new()
	nameplate.anchor_top = 1.0
	nameplate.offset_top = -46.0
	nameplate.offset_left = 3.0
	nameplate.offset_right = -3.0
	nameplate.offset_bottom = -3.0
	nameplate.text = element
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameplate.add_theme_font_size_override("font_size", 24)
	nameplate.add_theme_color_override("font_color", Color("f4f1e8"))
	nameplate.add_theme_color_override("font_outline_color", Color("11191b"))
	nameplate.add_theme_constant_override("outline_size", 4)
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(nameplate)

func _set_map_background() -> void:
	var selected_map: String = str(game_state.get("selected_map")).to_lower()
	var background_path := "res://assets/maps/map_aqua.jpg"
	if selected_map.contains("forest"):
		background_path = "res://assets/maps/map_forest.jpg"
	elif selected_map.contains("volcano"):
		background_path = "res://assets/maps/map_volcano.jpg"
	$MapBackground.texture = load(background_path)

func _style_card(card: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("20282c")
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 18.0
	normal.content_margin_bottom = 18.0
	card.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.58)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_color_override("font_color", Color("f4f1e8"))
	card.add_theme_color_override("font_hover_color", Color.WHITE)
	card.add_theme_font_size_override("font_size", 25)

func _on_card_hovered(card: Button, is_hovered: bool) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * (1.05 if is_hovered else 1.0), 0.14)

func _on_element_selected(element: String) -> void:
	var mc_loadout: Dictionary = game_state.get("mc_loadout")
	mc_loadout["element"] = element
	game_state.set("mc_loadout", mc_loadout)
	game_state.call("replace_draft_ui", self, WEAPON_SELECTION_SCENE)