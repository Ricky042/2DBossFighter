extends CharacterBody2D

# === EXPORT VARIABLES ===

@export var move_speed := 200.0         # Speed for regular movement
@export var charge_speed := 500.0       # Speed during charge phases
@export var bullet_speed := 200         # Speed at which bullets travel
@export var bullet_scene: PackedScene   # Scene for regular bullets
@export var move_interval := 2.0        # Time between choosing new movement targets
@export var shoot_interval := 0.15      # Time between each bullet shot
@export var bomb_scene: PackedScene     # Scene for bomb objects

# === STATE VARIABLES ===

var target_position: Vector2            # Target position for movement
var player: Node                        # Reference to player node
var room_bounds: Rect2                  # Boundaries within which the boss can move
var max_hp := 150                       # Maximum HP of the boss
var current_hp := 150                    # Current HP, starts below threshold for testing

var bomb_phase_started := false         # Tracks if bomb phase has begun
var final_phase_started := false        # Tracks if final phase (charging) has begun
var charging := false                   # True if currently charging
var float_shooting := false             # True if in float phase where it shoots while floating
var charge_velocity := Vector2.ZERO     # Direction and speed while charging
var bounce_count := 0                   # Number of bounces the boss can do during this charge phase
var bounces_left := 0                   # Bounces remaining for current charge
var float_shoot_timer := 0.0            # Timer for shooting during float phase (unused here)
var float_shoot_interval := 0.05        # Interval between shots in float phase

# === NODES & TIMERS ===

@onready var camera := get_node("/root/MainScene/Camera2D")  # Reference to main camera to determine room bounds
@onready var shoot_timer := Timer.new()                      # Timer to handle shooting
@onready var move_timer := Timer.new()                       # Timer to update movement target
@onready var bomb_timer := Timer.new()                       # Timer to drop bombs during mid-phase
@onready var charge_timer := Timer.new()                     # Triggers the start of charge phases
@onready var float_timer := Timer.new()                      # Handles duration of float phases between charges
@onready var hp_bar = $HPBar

func _ready():
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	
	# Initialize movement bounds based on camera limits
	room_bounds = Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	)

	# Setup timers with their respective intervals and connect to callback functions
	add_child(shoot_timer)
	shoot_timer.wait_time = shoot_interval
	shoot_timer.timeout.connect(_shoot)
	shoot_timer.start()

	add_child(move_timer)
	move_timer.wait_time = move_interval
	move_timer.timeout.connect(_set_new_target_position)
	move_timer.start()

	add_child(bomb_timer)
	bomb_timer.wait_time = 2.0
	bomb_timer.one_shot = false
	bomb_timer.timeout.connect(_drop_bomb)

	add_child(charge_timer)
	charge_timer.wait_time = 1.0
	charge_timer.one_shot = true
	charge_timer.timeout.connect(_start_charge)

	add_child(float_timer)
	float_timer.wait_time = 2.0
	float_timer.one_shot = true
	float_timer.timeout.connect(_end_float_phase)

	player = get_node("/root/MainScene/Player")
	_set_new_target_position()

func _physics_process(delta: float) -> void:
	# If in final phase (charging behavior, stop all shooting)
	if final_phase_started:
		shoot_timer.stop()
		bomb_timer.stop()

		if charging:
			# Move using charge velocity and handle collisions
			var collision = move_and_collide(charge_velocity * delta)
			if collision:
				_fire_bullet_wave()  # On collision, fire radial bullets

				# Bounce off walls if bounces remain
				if bounces_left > 0:
					bounces_left -= 1
					charge_velocity = charge_velocity.bounce(collision.get_normal()).normalized() * charge_speed
				else:
					# End charge and start float phase
					charging = false
					charge_velocity = Vector2.ZERO
					_start_float_phase()

		elif float_shooting:
			# Float around near the player and shoot at a higher frequency
			move_speed = 100
			var offset = (global_position - player.global_position).normalized() * 100
			var float_target = player.global_position + offset
			var float_dir = float_target - global_position

			if float_dir.length() > 5:
				velocity = float_dir.normalized() * move_speed
				move_and_slide()
			else:
				velocity = Vector2.ZERO

			# Handle float shooting
			float_shoot_timer += delta
			if float_shoot_timer >= float_shoot_interval:
				_shoot()
				float_shoot_timer = 0.0

	else:
		# Normal movement logic
		var direction = (target_position - global_position).normalized()
		velocity = direction * move_speed

		if global_position.distance_to(target_position) < 10.0:
			velocity = Vector2.ZERO

		move_and_slide()

	# === Phase triggers based on HP ===
	if not bomb_phase_started and current_hp <= (0.75 * max_hp):
		bomb_phase_started = true
		bomb_timer.start()

	if not final_phase_started and current_hp <= (0.5 * max_hp):
		final_phase_started = true
		charge_timer.start()

func _set_new_target_position():
	# Choose a new random point within the room bounds to move toward
	var x = randf_range(room_bounds.position.x, room_bounds.position.x + room_bounds.size.x)
	var y = randf_range(room_bounds.position.y, room_bounds.position.y + room_bounds.size.y)
	target_position = Vector2(x, y)

func _shoot():
	# Handle shooting logic. Predicts player motion during certain HP phases.
	if (final_phase_started and not float_shooting) or not player:
		return

	var player_pos = player.global_position
	var player_velocity = player.velocity
	var direction := Vector2.ZERO

	# If above 75% HP or in float-shooting phase, shoot with some random variance
	if (current_hp > (0.75 * max_hp)) or ((current_hp < (0.25 * max_hp)) and float_shooting):
		direction = (player_pos - global_position).normalized()
		direction = direction.rotated(randf_range(-0.3, 0.3))
	else:
		# Predictive aiming based on player movement
		var distance = global_position.distance_to(player_pos)
		var travel_time = distance / bullet_speed
		var predicted_position = player_pos + player_velocity * travel_time
		direction = (predicted_position - global_position).normalized()

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	get_tree().current_scene.add_child(bullet)
	bullet.setup(direction, bullet_speed)

func _drop_bomb():
	# Drop a bomb that bounces and explodes if in bomb phase
	if final_phase_started or not bomb_scene or not player:
		return

	var bomb = bomb_scene.instantiate()
	bomb.global_position = global_position

	var direction = (player.global_position - global_position).normalized()
	bomb.setup(direction)
	get_tree().current_scene.add_child(bomb)

func _start_charge():
	# Initiates a straight-line charge toward the player, bouncing off walls
	if not is_instance_valid(player):
		return

	charging = true
	float_shooting = false
	bounce_count += 1
	bounces_left = bounce_count

	var dir = (player.global_position - global_position).normalized()
	charge_velocity = dir * charge_speed

func _start_float_phase():
	# Enters floating phase after charging, boss floats and fires rapidly
	float_shooting = true
	float_timer.start()

func _end_float_phase():
	# Ends the floating phase and prepares for another charge
	float_shooting = false
	charge_timer.start()

func _fire_bullet_wave():
	# Fires a full-circle radial burst of bullets (e.g., 36 bullets)
	for i in range(90):
		var angle = i * (TAU / 90)  # TAU is 2*PI in Godot
		var direction = Vector2(cos(angle), sin(angle))
		
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		
		# Play the "wave" animation for these bullets
		bullet.setup(direction, bullet_speed, "wave")
		
		get_tree().current_scene.add_child(bullet)


func take_damage(amount: int) -> void:
	# Decrease HP and check for death
	current_hp -= amount
	hp_bar.value = current_hp

	if current_hp <= 0:
		die()

func die():
	# Handles boss death sequence and triggers game over screen
	var game_ui = get_node("/root/MainScene/GameOverUI")
	game_ui.show_game_over(true)
	queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	# Called when colliding with another body, applies damage to the player if valid
	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			body.take_damage(3)
