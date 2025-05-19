extends CharacterBody2D

@export var move_speed := 300.0
@export var charge_speed := 800.0
@export var bullet_speed := 200
@export var bullet_scene: PackedScene
@export var move_interval := 2.0
@export var shoot_interval := 0.15
@export var bomb_scene: PackedScene = preload("res://characters/bomb.tscn")
@export var collision_damage := 3

var target_position: Vector2
var player: Node
var room_bounds: Rect2
var max_hp := 100
var current_hp := 100

var bomb_phase_started := false
var final_phase_started := false
var charging := false
var charge_velocity := Vector2.ZERO
var charge_cooldown := 0.0

@onready var camera := get_node("/root/MainScene/Camera2D")
@onready var shoot_timer := Timer.new()
@onready var move_timer := Timer.new()
@onready var bomb_timer := Timer.new()
@onready var charge_timer := Timer.new()

func _ready():
	room_bounds = Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	)

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
	charge_timer.wait_time = 3.0
	charge_timer.one_shot = false
	charge_timer.timeout.connect(_start_charge)

	player = get_node("/root/MainScene/Player")

	_set_new_target_position()

func _physics_process(delta: float) -> void:
	if final_phase_started and charging:
		var collision = move_and_collide(charge_velocity * delta)
		if collision:
			charge_velocity = charge_velocity.bounce(collision.get_normal())
			# Damage the player if collided
			if collision.get_collider() == player:
				player.take_damage(collision_damage)
	else:
		var direction = (target_position - global_position).normalized()
		velocity = direction * move_speed

		if global_position.distance_to(target_position) < 10.0:
			velocity = Vector2.ZERO

		move_and_slide()

	if not bomb_phase_started and current_hp <= (0.5 * max_hp):
		bomb_phase_started = true
		bomb_timer.start()

	if not final_phase_started and current_hp <= (0.25 * max_hp):
		final_phase_started = true
		charge_timer.start()

func _set_new_target_position():
	var x = randf_range(room_bounds.position.x, room_bounds.position.x + room_bounds.size.x)
	var y = randf_range(room_bounds.position.y, room_bounds.position.y + room_bounds.size.y)
	target_position = Vector2(x, y)

func _shoot():
	if not player:
		return

	var player_pos = player.global_position
	var player_velocity = player.velocity

	var direction := Vector2.ZERO

	if current_hp > (0.75 * max_hp):
		direction = (player_pos - global_position).normalized()
		direction = direction.rotated(randf_range(-0.3, 0.3))
	else:
		var distance = global_position.distance_to(player_pos)
		var travel_time = distance / bullet_speed
		var predicted_position = player_pos + player_velocity * travel_time
		direction = (predicted_position - global_position).normalized()

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	get_tree().current_scene.add_child(bullet)
	bullet.setup(direction, bullet_speed)

func _drop_bomb():
	if not bomb_scene or not player:
		return

	var bomb = bomb_scene.instantiate()
	bomb.global_position = global_position

	var direction = (player.global_position - global_position).normalized()
	bomb.setup(direction)
	get_tree().current_scene.add_child(bomb)

func _start_charge():
	if not is_instance_valid(player):
		return
	var dir = (player.global_position - global_position).normalized()
	charge_velocity = dir * charge_speed
	charging = true

func take_damage(amount: int) -> void:
	current_hp -= amount
	print("Boss HP: ", current_hp)

	if current_hp <= 0:
		die()

func die():
	var game_ui = get_node("/root/MainScene/GameOverUI")
	game_ui.show_game_over(true)
	queue_free()
