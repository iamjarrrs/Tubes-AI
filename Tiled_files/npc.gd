extends CharacterBody2D

signal navigation_target_reached

const SPEED = 220.0
var player: Node2D = null
var astar_grid := AStarGrid2D.new()
@export var tile_size := 16
var grid_origin := Vector2.ZERO
var current_path: PackedVector2Array = []
var path_index := 0
var last_target_id := Vector2i(2147483647, 2147483647)
var needs_repath := true
var planner_controlled := false
var planner_target_position := Vector2.ZERO
var planner_target_active := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)

	setup_astar()

func setup_astar():
	var map_sprite := _get_map_background()
	if map_sprite:
		var map_size := Vector2(map_sprite.texture.get_size()) * map_sprite.global_scale
		grid_origin = map_sprite.global_position - map_size * 0.5
		var grid_width := ceili(map_size.x / tile_size)
		var grid_height := ceili(map_size.y / tile_size)
		astar_grid.region = Rect2i(0, 0, grid_width, grid_height)
		astar_grid.offset = grid_origin + Vector2(tile_size, tile_size) * 0.5
	else:
		astar_grid.region = Rect2i(-200, -200, 400, 400)
		grid_origin = Vector2(-200.0, -200.0) * tile_size
		astar_grid.offset = grid_origin + Vector2(tile_size, tile_size) * 0.5
	astar_grid.cell_size = Vector2(tile_size, tile_size)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()

	var collision_shapes := get_tree().current_scene.find_children("*", "CollisionShape2D", true, false)
	for collision_shape in collision_shapes:
		if collision_shape.get_parent() is StaticBody2D:
			_mark_collision_shape_solid(collision_shape as CollisionShape2D)

func _get_map_background() -> Sprite2D:
	var map_scene := get_parent()
	for child in map_scene.get_children():
		if child is Sprite2D and child.texture:
			return child as Sprite2D
	return null

func _mark_collision_shape_solid(collision_shape: CollisionShape2D) -> void:
	if collision_shape.disabled or collision_shape.shape == null:
		return
	var rect := collision_shape.shape.get_rect()
	var local_corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var world_corners: Array[Vector2] = []
	for corner in local_corners:
		world_corners.append(collision_shape.to_global(corner))

	var min_x := world_corners[0].x
	var max_x := world_corners[0].x
	var min_y := world_corners[0].y
	var max_y := world_corners[0].y
	for point in world_corners:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	var clearance := tile_size * 0.75
	min_x -= clearance
	max_x += clearance
	min_y -= clearance
	max_y += clearance
	var first_cell := _world_to_grid_id(Vector2(min_x, min_y))
	var last_cell := _world_to_grid_id(Vector2(max_x, max_y))
	var region := astar_grid.region
	for cell_x in range(first_cell.x, last_cell.x + 1):
		for cell_y in range(first_cell.y, last_cell.y + 1):
			var cell_id := Vector2i(cell_x, cell_y)
			if cell_id.x < region.position.x or cell_id.x >= region.end.x:
				continue
			if cell_id.y < region.position.y or cell_id.y >= region.end.y:
				continue
			var cell_center := astar_grid.get_point_position(cell_id)
			if cell_center.x >= min_x and cell_center.x <= max_x and cell_center.y >= min_y and cell_center.y <= max_y:
				astar_grid.set_point_solid(cell_id, true)

func _world_to_grid_id(position: Vector2) -> Vector2i:
	var map_local_position := position - grid_origin
	return Vector2i(floori(map_local_position.x / tile_size), floori(map_local_position.y / tile_size))

func find_spawn_position(target_position: Vector2) -> Vector2:
	var target_id := _find_nearest_walkable_id(_world_to_grid_id(target_position))
	var region := astar_grid.region
	var map_sprite := _get_map_background()
	var desired_position := target_position + Vector2(480.0, 0.0)
	if map_sprite:
		var map_size := Vector2(map_sprite.texture.get_size()) * map_sprite.global_scale
		var map_left := map_sprite.global_position.x - map_size.x * 0.5
		var map_right := map_sprite.global_position.x + map_size.x * 0.5
		var map_center_y := map_sprite.global_position.y
		desired_position = Vector2(lerpf(map_left, map_right, 0.78), map_center_y)

	var desired_id := _world_to_grid_id(desired_position)
	for radius in range(0, 16):
		var best_position := Vector2.ZERO
		var best_distance := INF
		for offset_x in range(-radius, radius + 1):
			for offset_y in range(-radius, radius + 1):
				if radius > 0 and absi(offset_x) != radius and absi(offset_y) != radius:
					continue
				var candidate_id := desired_id + Vector2i(offset_x, offset_y)
				if candidate_id.x < region.position.x or candidate_id.x >= region.end.x:
					continue
				if candidate_id.y < region.position.y or candidate_id.y >= region.end.y:
					continue
				if astar_grid.is_point_solid(candidate_id):
					continue
				var candidate_position := astar_grid.get_point_position(candidate_id)
				var candidate_distance := candidate_position.distance_squared_to(desired_position)
				if candidate_distance >= best_distance:
					continue
				if not astar_grid.get_id_path(candidate_id, target_id).is_empty():
					best_distance = candidate_distance
					best_position = candidate_position
		if best_distance < INF:
			return best_position
	return desired_position

func _physics_process(delta: float) -> void:
	if planner_controlled:
		_process_planner_navigation(delta)
		return
	if not player:
		return
	var target_id := _find_nearest_walkable_id(_world_to_grid_id(player.global_position))
	if needs_repath or target_id != last_target_id or current_path.is_empty():
		last_target_id = target_id
		path_index = 0
		var start_id := _world_to_grid_id(global_position)
		if astar_grid.is_point_solid(start_id):
			start_id = _find_nearest_walkable_id(start_id)
		current_path = astar_grid.get_point_path(start_id, target_id)
		needs_repath = false
		queue_redraw()
	if current_path.is_empty():
		velocity = Vector2.ZERO
		anim.stop()
		return
	while path_index < current_path.size() - 1 and global_position.distance_to(current_path[path_index]) < maxf(5.0, SPEED * delta * 1.5):
		path_index += 1
	var direction := global_position.direction_to(current_path[path_index])
	velocity = direction * SPEED
	if direction != Vector2.ZERO:
		update_npc_animation(direction)
	else:
		anim.stop()
	move_and_slide()
	if get_slide_collision_count() > 0:
		var blocked_id := _world_to_grid_id(global_position + direction * tile_size)
		var region := astar_grid.region
		if blocked_id.x >= region.position.x and blocked_id.x < region.end.x and blocked_id.y >= region.position.y and blocked_id.y < region.end.y:
			astar_grid.set_point_solid(blocked_id, true)
		needs_repath = true
		current_path.clear()
		velocity = Vector2.ZERO
	queue_redraw()

func begin_planner_control() -> void:
	planner_controlled = true
	planner_target_active = false
	current_path.clear()
	velocity = Vector2.ZERO
	needs_repath = true
	queue_redraw()

func set_planner_target(target_position: Vector2) -> void:
	var next_target_id := _world_to_grid_id(target_position)
	var current_target_id := _world_to_grid_id(planner_target_position)
	if planner_target_active and next_target_id == current_target_id:
		planner_target_position = target_position
		return
	planner_target_position = target_position
	planner_target_active = true
	needs_repath = true
	queue_redraw()

func stop_planner_navigation() -> void:
	planner_target_active = false
	current_path.clear()
	velocity = Vector2.ZERO
	if is_instance_valid(anim):
		anim.stop()
	queue_redraw()

func _process_planner_navigation(delta: float) -> void:
	if not planner_target_active:
		velocity = Vector2.ZERO
		return
	if global_position.distance_to(planner_target_position) <= 20.0:
		stop_planner_navigation()
		navigation_target_reached.emit()
		return
	var target_id := _find_nearest_walkable_id(_world_to_grid_id(planner_target_position))
	if needs_repath or target_id != last_target_id or current_path.is_empty():
		last_target_id = target_id
		path_index = 0
		var start_id := _world_to_grid_id(global_position)
		if astar_grid.is_point_solid(start_id):
			start_id = _find_nearest_walkable_id(start_id)
		current_path = astar_grid.get_point_path(start_id, target_id)
		needs_repath = false
		queue_redraw()
	if current_path.is_empty():
		velocity = Vector2.ZERO
		return
	while path_index < current_path.size() - 1 and global_position.distance_to(current_path[path_index]) < maxf(5.0, SPEED * delta * 1.5):
		path_index += 1
	var direction := global_position.direction_to(current_path[path_index])
	velocity = direction * SPEED
	update_npc_animation(direction)
	move_and_slide()
	if get_slide_collision_count() > 0:
		needs_repath = true
		current_path.clear()
		velocity = Vector2.ZERO
	queue_redraw()

func _find_nearest_walkable_id(origin: Vector2i) -> Vector2i:
	var region := astar_grid.region
	if origin.x >= region.position.x and origin.x < region.end.x and origin.y >= region.position.y and origin.y < region.end.y and not astar_grid.is_point_solid(origin):
		return origin
	for radius in range(1, 8):
		for offset_x in range(-radius, radius + 1):
			for offset_y in range(-radius, radius + 1):
				if absi(offset_x) != radius and absi(offset_y) != radius:
					continue
				var candidate := origin + Vector2i(offset_x, offset_y)
				if candidate.x < region.position.x or candidate.x >= region.end.x:
					continue
				if candidate.y < region.position.y or candidate.y >= region.end.y:
					continue
				if not astar_grid.is_point_solid(candidate):
					return candidate
	return origin

func update_npc_animation(direction: Vector2):
	if abs(direction.y) >= abs(direction.x):
		anim.flip_h = false
		if direction.y > 0:
			if anim.sprite_frames.has_animation("walk_down"):
				anim.play("walk_down")
			else:
				anim.play("default")
		else:
			if anim.sprite_frames.has_animation("walk_up"):
				anim.play("walk_up")
			else:
				anim.play("default")
	else:
		if anim.sprite_frames.has_animation("walk_side"):
			anim.play("walk_side")
		else:
			anim.play("default")
		anim.flip_h = direction.x > 0

# Debug Overlay Grid A*
func _draw():
	var draw_size := Vector2(tile_size, tile_size) / global_scale
	for path_point_index in range(path_index, current_path.size()):
		var point := current_path[path_point_index]
		var local_point = to_local(point)
		var rect = Rect2(local_point - draw_size * 0.5, draw_size)
		
		draw_rect(rect, Color(0, 0.8, 1, 0.3), true)
		draw_rect(rect, Color(0, 0.4, 1, 0.8), false)
