extends CanvasLayer

const MAPS := [
	{"name": "Aqua", "path": "res://scenes/maps/map_aqua.tscn", "preview": "res://assets/maps/map_aqua.jpg", "description": "Dunia bawah laut"},
	{"name": "Forest", "path": "res://scenes/maps/map_forest.tscn", "preview": "res://assets/maps/map_forest.jpg", "description": "Hutan yang rimbun"},
	{"name": "Volcano", "path": "res://scenes/maps/map_volcano.tscn", "preview": "res://assets/maps/map_volcano.jpg", "description": "Gunung berapi"}
]

var player: CharacterBody2D
var portal: Node2D
var error_label: Label

func open_for(source_portal: Node2D, entering_player: CharacterBody2D) -> void:
	layer = 120
	portal = source_portal
	player = entering_player
	player.set_physics_process(false)
	_build_ui()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.07, 0.84)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(800.0, 400.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var heading := Label.new()
	heading.text = "PILIH MAP"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	content.add_child(heading)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	content.add_child(cards)
	for map_data in MAPS:
		cards.add_child(_make_map_card(map_data))

	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.42))
	content.add_child(error_label)

	var close_button := Button.new()
	close_button.text = "Tutup (Esc)"
	close_button.custom_minimum_size = Vector2(140, 38)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close)
	content.add_child(close_button)

func _make_map_card(map_data: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(220.0, 220.0)
	card.clip_contents = true
	card.add_theme_stylebox_override("normal", _make_card_style(Color(0.08, 0.12, 0.20), Color(0.25, 0.40, 0.55)))
	card.add_theme_stylebox_override("hover", _make_card_style(Color(0.12, 0.22, 0.32), Color(0.34, 0.82, 1.0)))
	card.add_theme_stylebox_override("pressed", _make_card_style(Color(0.10, 0.18, 0.28), Color(0.55, 0.88, 1.0)))
	card.mouse_entered.connect(_set_card_hover.bind(card, true))
	card.mouse_exited.connect(_set_card_hover.bind(card, false))
	card.pressed.connect(_select_map.bind(map_data))

	var preview := TextureRect.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 6.0
	preview.offset_top = 6.0
	preview.offset_right = -6.0
	preview.offset_bottom = -6.0
	preview.texture = load(map_data["preview"])
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(preview)

	var caption := ColorRect.new()
	caption.anchor_top = 1.0
	caption.offset_top = -64.0
	caption.offset_left = 6.0
	caption.offset_right = -6.0
	caption.offset_bottom = -6.0
	caption.color = Color(0.03, 0.06, 0.10, 0.92)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caption)

	var title := Label.new()
	title.text = map_data["name"]
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_top = -58.0
	title.offset_left = 8.0
	title.offset_right = -8.0
	title.offset_bottom = -32.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)

	var description := Label.new()
	description.text = map_data["description"]
	description.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	description.offset_top = -32.0
	description.offset_left = 8.0
	description.offset_right = -8.0
	description.offset_bottom = -8.0
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.72, 0.82, 0.90))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(description)
	return card

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, 0.98)
	style.border_color = Color(0.20, 0.63, 0.83, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	return style

func _make_card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(5)
	return style

func _set_card_hover(card: Button, hovering: bool) -> void:
	card.pivot_offset = card.size / 2.0
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2.ONE * (1.04 if hovering else 1.0), 0.12)

func _select_map(map_data: Dictionary) -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		error_label.text = "GameState belum tersedia."
		return
	game_state.call("start_map_draft", map_data["name"], map_data["path"])

func _close() -> void:
	if is_instance_valid(portal):
		portal.call("close_selector")
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()