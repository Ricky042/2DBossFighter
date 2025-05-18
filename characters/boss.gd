extends CharacterBody2D

@export var move_speed := 300.0
@export var bullet_speed := 200
@export var bullet_scene: PackedScene
@export var move_interval := 2.0
@export var shoot_interval := 0.15

var target_position: Vector2
var player: Node
var room_bounds: Rect2
var max_hp := 100
var current_hp := 100


@onready var camera := get_node("/root/MainScene/Camera2D")
@onready var shoot_timer := Timer.new()
@onready var move_timer := Timer.new()

func _ready():
	# Set up room bounds based on camera limits
	room_bounds = Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	)

	# Locate player
	player = get_node("/root/MainScene/Player")

	# Initialize and start timers
	add_child(shoot_timer)
	shoot_timer.wait_time = shoot_interval
	shoot_timer.timeout.connect(_shoot)
	shoot_timer.start()

	add_child(move_timer)
	move_timer.wait_time = move_interval
	move_timer.timeout.connect(_set_new_target_position)
	move_timer.start()

	_set_new_target_position()

func _physics_process(_delta: float) -> void:
	var direction = (target_position - global_position).normalized()
	velocity = direction * move_speed

	# Stop if close to the target
	if global_position.distance_to(target_position) < 10.0:
		velocity = Vector2.ZERO

	move_and_slide()

func _set_new_target_position():
	# Choose a random position within the room bounds
	var x = randf_range(room_bounds.position.x, room_bounds.position.x + room_bounds.size.x)
	var y = randf_range(room_bounds.position.y, room_bounds.position.y + room_bounds.size.y)
	target_position = Vector2(x, y)

func _shoot():
	if not player:
		return

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	
	# Get base direction toward player
	var base_direction = (player.global_position - global_position).normalized()

	# Add a small random angle (in radians)
	var spread_angle = deg_to_rad(randf_range(-15, 15))  # Spread of ±5 degrees
	var direction = base_direction.rotated(spread_angle)
	bullet.setup(direction, bullet_speed)

func take_damage(amount: int) -> void:
	current_hp -= amount
	print("Boss HP: ", current_hp)

	if current_hp <= 0:
		die()

func die():
	print("Boss Defeated")
	queue_free()  # Or trigger victory state
