extends Area2D

signal collected(by: Node)

var is_available := true
var anim_time := 0.0
var particles: Array[Dictionary] = []
var is_picked_up := false
var pickup_anim_time := 0.0

@onready var shape_node: CollisionShape2D

func _ready() -> void:
	name = "BuffItem"
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	shape_node = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	shape_node.shape = shape
	add_child(shape_node)

	body_entered.connect(_on_body_entered)

	# Inisialisasi partikel bintang mengambang di sekitar buff
	for i in range(8):
		particles.append({
			"pos": Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0)),
			"speed": randf_range(12.0, 24.0),
			"alpha": randf_range(0.3, 1.0),
			"size": randf_range(2.0, 4.0),
			"phase": randf_range(0.0, TAU)
		})

func _process(delta: float) -> void:
	anim_time += delta

	if is_picked_up:
		pickup_anim_time += delta * 3.5
		if pickup_anim_time >= 1.0:
			queue_free()
		queue_redraw()
		return

	# Animasi partikel melayang ke atas
	for p in particles:
		p["pos"].y -= p["speed"] * delta
		p["alpha"] = 0.4 + 0.6 * sin(anim_time * 3.0 + p["phase"])
		if p["pos"].y < -28.0:
			p["pos"].y = 24.0
			p["pos"].x = randf_range(-20.0, 20.0)

	queue_redraw()

func collect(by: Node) -> bool:
	if not is_available:
		return false
	is_available = false
	is_picked_up = true
	monitoring = false
	collected.emit(by)
	return true

func _on_body_entered(body: Node2D) -> void:
	if not is_available:
		return
	if body == null:
		return
	if body.is_in_group("player") or body.name == "BattleNPC" or body.is_in_group("npc"):
		collect(body)

func _draw() -> void:
	if is_picked_up:
		# Animasi burst saat buff terambil
		var ring_radius := 20.0 + pickup_anim_time * 45.0
		var ring_alpha := maxf(0.0, 1.0 - pickup_anim_time)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color(1.0, 0.88, 0.35, ring_alpha), 3.0)
		draw_circle(Vector2.ZERO, 14.0 * (1.0 - pickup_anim_time), Color(0.4, 0.95, 0.65, ring_alpha))
		return

	if not is_available:
		return

	var bob_y := sin(anim_time * 3.5) * 5.0
	var center := Vector2(0.0, bob_y)

	var pulse := 0.5 + 0.5 * sin(anim_time * 4.0)

	# 1. Bayangan tanah di bawah item
	var shadow_scale := 1.0 - (bob_y / 15.0)
	_draw_custom_shadow(Vector2(0, 20), Vector2(18 * shadow_scale, 6 * shadow_scale), Color(0.0, 0.0, 0.0, 0.35))

	# 2. Glowing Outer Aura
	var outer_radius := 26.0 + pulse * 6.0
	draw_circle(center, outer_radius, Color(0.2, 0.9, 0.5, 0.15))
	draw_circle(center, outer_radius * 0.75, Color(0.9, 0.8, 0.2, 0.22))

	# 3. Rotating Magic Runes / Aksen Berlian
	var rot := anim_time * 1.8
	for i in range(4):
		var angle := rot + i * (TAU / 4.0)
		var rune_pos := center + Vector2(cos(angle), sin(angle)) * 22.0
		draw_rect(Rect2(rune_pos - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.88, 0.35, 0.85), true)

	# 4. Partikel Bintang Naik
	for p in particles:
		var p_pos: Vector2 = p.get("pos", Vector2.ZERO)
		var p_size: float = float(p.get("size", 2.0))
		var p_alpha: float = float(p.get("alpha", 1.0))
		draw_circle(center + p_pos, p_size, Color(1.0, 0.95, 0.6, p_alpha))

	# 5. Badan Botol Elixir Ajaib (Magical Potion Flask)
	# Cincin Luar
	draw_circle(center, 16.0, Color(0.08, 0.16, 0.12, 0.95))
	draw_circle(center, 14.0, Color(0.15, 0.45, 0.30, 0.95))

	# Cairan Elixir Berpendar
	var liquid_radius := 11.0 + pulse * 1.5
	draw_circle(center, liquid_radius, Color("76d6a0"))
	draw_circle(center, liquid_radius * 0.6, Color("d5f4a8"))

	# Leher & Sumbat Botol Emas
	draw_rect(Rect2(center + Vector2(-5, -19), Vector2(10, 6)), Color("e6ad62"), true)
	draw_rect(Rect2(center + Vector2(-3, -23), Vector2(6, 4)), Color("c4883b"), true)

	# Kilau Kaca (Glass Highlight)
	draw_arc(center, 9.0, -PI * 0.75, -PI * 0.25, 12, Color(1.0, 1.0, 1.0, 0.8), 2.0)

	# Simbol Petir / Bintang di Tengah Botol
	draw_line(center + Vector2(1, -7), center + Vector2(-2, 1), Color("f0e9d2"), 2.0)
	draw_line(center + Vector2(-2, 1), center + Vector2(3, 1), Color("f0e9d2"), 2.0)
	draw_line(center + Vector2(3, 1), center + Vector2(-1, 8), Color("f0e9d2"), 2.0)

	# 6. Overhead Badge Label yang Cantik
	var label_pos := center + Vector2(-60, -32)
	# Background tag gelap
	draw_rect(Rect2(label_pos + Vector2(0, -2), Vector2(120, 18)), Color(0.04, 0.08, 0.10, 0.88), true)
	draw_rect(Rect2(label_pos + Vector2(0, -2), Vector2(120, 18)), Color("e6ad62"), false, 1.5)
	# Teks label
	draw_string(ThemeDB.fallback_font, label_pos + Vector2(6, 11), "★ BUFF (+10 ATK) ★", HORIZONTAL_ALIGNMENT_CENTER, 108, 11, Color(1.0, 0.92, 0.45, 1.0))

func _draw_custom_shadow(pos: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = []
	for i in range(24):
		var angle := i * (TAU / 24.0)
		points.append(pos + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
