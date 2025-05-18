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


func _physics_process(_delta: float) -> void:
	handle_movement()
	handle_actions()
	
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
	if Input.is_action_just_pressed("shoot"):
		shoot()

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
	print("Player died")
	print("GameOver")
