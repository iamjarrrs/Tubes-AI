extends CharacterBody2D

const WALK_SPEED = 120.0
const RUN_SPEED = 200.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta):
	# Mengecek tombol Shift untuk lari
	var is_running = Input.is_key_pressed(KEY_SHIFT)
	var current_speed = RUN_SPEED if is_running else WALK_SPEED

	# Membaca input arah (WASD / Panah)
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * current_speed
	
	update_animation(direction, is_running)
	
	move_and_slide()

func _ready():
	add_to_group("player")
	_setup_camera_limits()

func _setup_camera_limits() -> void:
	var cam: Camera2D = get_node_or_null("Camera2D")
	if not cam:
		return
	var parent_node := get_parent()
	if not parent_node:
		return
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	var found_tilemap := false
	for child in parent_node.get_children():
		if child is TileMapLayer:
			var rect: Rect2i = child.get_used_rect()
			if rect.size == Vector2i.ZERO:
				continue
			var tile_size: Vector2i = child.tile_set.tile_size if child.tile_set else Vector2i(16, 16)
			var world_min := Vector2(rect.position * tile_size)
			var world_max := Vector2((rect.position + rect.size) * tile_size)
			min_pos.x = minf(min_pos.x, world_min.x)
			min_pos.y = minf(min_pos.y, world_min.y)
			max_pos.x = maxf(max_pos.x, world_max.x)
			max_pos.y = maxf(max_pos.y, world_max.y)
			found_tilemap = true
	if found_tilemap:
		cam.limit_left = floori(min_pos.x)
		cam.limit_top = floori(min_pos.y)
		cam.limit_right = ceili(max_pos.x)
		cam.limit_bottom = ceili(max_pos.y)

func update_animation(direction: Vector2, is_running: bool):
	if direction == Vector2.ZERO:
		anim.stop()
		return

	var suffix = "_run" if is_running else ""

	# Cek ketersediaan animasi melalui sprite_frames di Godot 4
	if abs(direction.x) > abs(direction.y):
		if anim.sprite_frames.has_animation("walk_side" + suffix):
			anim.play("walk_side" + suffix)
		elif anim.sprite_frames.has_animation("walk_side"):
			anim.play("walk_side")
		else:
			anim.play("default")
			
		# Diubah menjadi arah sebaliknya agar tidak terbalik
		anim.flip_h = direction.x > 0
	else:
		anim.flip_h = false
		if direction.y > 0:
			if anim.sprite_frames.has_animation("walk_down" + suffix):
				anim.play("walk_down" + suffix)
			elif anim.sprite_frames.has_animation("walk_down"):
				anim.play("walk_down")
			else:
				anim.play("default")
		else:
			if anim.sprite_frames.has_animation("walk_up" + suffix):
				anim.play("walk_up" + suffix)
			elif anim.sprite_frames.has_animation("walk_up"):
				anim.play("walk_up")
			else:
				anim.play("default")
