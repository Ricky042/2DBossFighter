extends CharacterBody2D

const SPEED := 200 # Speed at which the player moves (in pixels per second)
const BULLET_SPEED := 400 # Speed of allied shots
const DODGE_TIME := 0.1 # Duration of dash movement boost
const INVULN_DURATION := 0.1 
const DODGE_COOLDOWN := 1.0  # Time before dodge can be used again

@export var bullet_scene: PackedScene  # Drag Bullet.tscn into this in the Inspector

var last_input_vector := Vector2.RIGHT  # Default facing direction
var can_dodge := true
var is_dodging := false
var is_invulnerable := false
var max_hp := 4
var current_hp := 4

@onready var boss_arrow := get_node("/root/MainScene/Camera2D/BossArrow")
@onready var camera := get_node("/root/MainScene/Camera2D")
@onready var boss := get_node("/root/MainScene/Boss")
@onready var shoot_timer := Timer.new()

func _physics_process(_delta: float) -> void:
	shoot_timer.wait_time = 0.15
	shoot_timer.one_shot = true
	add_child(shoot_timer)
	
	handle_movement()
	handle_actions()
	update_boss_arrow()
	move_and_slide()

func handle_movement() -> void:
	var input_vector = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)

	if input_vector != Vector2.ZERO:
		last_input_vector = input_vector.normalized()
		
		# Only move if there's input and not dodging
		if not is_dodging:
			velocity = last_input_vector * SPEED
	else:
		if not is_dodging:
			velocity = Vector2.ZERO


func handle_actions() -> void:
	if Input.is_action_pressed("shoot") and shoot_timer.is_stopped():
		shoot()
		shoot_timer.start()

	if Input.is_action_just_pressed("dodge") and can_dodge:
		dodge(last_input_vector)


func shoot():
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = global_position
	
	# Get the global mouse position
	var mouse_pos = get_global_mouse_position()
	
	# Calculate direction vector from player to mouse
	var direction = (mouse_pos - global_position).normalized()
	
	bullet.setup(direction, BULLET_SPEED)
	
func dodge(direction: Vector2) -> void:
	if is_dodging or not can_dodge:
		return

	is_dodging = true
	is_invulnerable = true
	can_dodge = false

	velocity = direction.normalized() * SPEED * 3

	await get_tree().create_timer(DODGE_TIME).timeout
	is_dodging = false
	velocity = Vector2.ZERO

	await get_tree().create_timer(INVULN_DURATION - DODGE_TIME).timeout
	is_invulnerable = false

	await get_tree().create_timer(DODGE_COOLDOWN).timeout
	can_dodge = true
	
func take_damage(amount :int) -> void:
	if is_invulnerable:
		return
	
	current_hp -= amount
	print("Player HP: ", current_hp)
	
	if current_hp <= 0:
		game_over()

func game_over():
	var game_ui = get_node("/root/MainScene/GameOverUI")
	game_ui.show_game_over(false)  # false = defeat
	queue_free()

func update_boss_arrow():
	# Make sure all nodes exist
	if not is_instance_valid(boss) or not is_instance_valid(boss_arrow) or not is_instance_valid(camera):
		return
	
	# Make sure arrow uses global coordinates
	if not boss_arrow.top_level:
		boss_arrow.top_level = true
	
	# Get viewport size
	var viewport_size = get_viewport_rect().size
	
	# IMPORTANT: Calculate camera's actual view rectangle in world space
	var camera_zoom = camera.zoom
	var actual_view_size = Vector2(viewport_size.x / camera_zoom.x, viewport_size.y / camera_zoom.y)
	
	# Camera's top-left corner in world space
	var camera_top_left = camera.global_position - (actual_view_size / 2)
	
	# Create a Rect2 representing the camera's view in world space
	var camera_rect = Rect2(camera_top_left, actual_view_size)

	# Check if boss is in camera view with margin
	var margin = 0  # Margin in world units
	var view_rect_with_margin = Rect2(
		camera_rect.position.x + margin,
		camera_rect.position.y + margin,
		camera_rect.size.x - margin * 2,
		camera_rect.size.y - margin * 2
	)
	
	var boss_in_view = view_rect_with_margin.has_point(boss.global_position)
	
	# If boss is in view, hide the arrow
	if boss_in_view:
		boss_arrow.visible = false
		return
	
	# Boss is not in view, show the arrow
	boss_arrow.visible = true
	
	# Calculate position of arrow in SCREEN coordinates
	# First convert camera and boss positions to screen space
	var screen_center = viewport_size / 2
	
	# Direction from camera to boss in world space
	var to_boss_dir = (boss.global_position - camera.global_position).normalized()
	
	# Calculate intersection with screen edge
	var half_width = viewport_size.x / 2
	var half_height = viewport_size.y / 2
	
	# Find intersection with screen borders
	var border_margin = 25  # Distance from screen edges
	var arrow_pos = Vector2()
	
	# Calculate ray length to each edge
	var scale_x = (half_width - border_margin) / abs(to_boss_dir.x) if abs(to_boss_dir.x) > 0.001 else INF
	var scale_y = (half_height - border_margin) / abs(to_boss_dir.y) if abs(to_boss_dir.y) > 0.001 else INF
	
	# Use smaller scale to find edge intersection
	var edge_dist = min(scale_x, scale_y)
	
	# Calculate arrow position in screen space
	arrow_pos = screen_center + to_boss_dir * edge_dist
	
	# Convert arrow position from screen space to world space
	var arrow_world_pos = camera.global_position + ((arrow_pos - screen_center) / camera_zoom)
	
	# Set arrow position in world space
	boss_arrow.global_position = arrow_world_pos
	
	# Point arrow toward boss
	boss_arrow.rotation = to_boss_dir.angle()
	
	# Calculate distance for scaling and opacity
	var distance = global_position.distance_to(boss.global_position)
	var max_distance = 2000.0
	var min_distance = 300.0
	var distance_factor = 1.0 - clamp((distance - min_distance) / (max_distance - min_distance), 0.0, 1.0)
	
	# Apply scale and opacity
	var scale_factor = lerp(0.01, 0.1, distance_factor)
	boss_arrow.scale = Vector2.ONE * scale_factor
	
	var alpha = lerp(0.4, 1.0, distance_factor)
	boss_arrow.modulate.a = alpha
