extends CharacterBody2D

@export var speed := 250.0
@export var explosion_delay := 2.0
@export var bullet_scene: PackedScene

func setup(direction: Vector2):
	velocity = direction.normalized() * speed
	# Removed start_explosion_timer() from here

func _ready():
	start_explosion_timer()

func _physics_process(delta):
	# Move and bounce
	var collision = move_and_collide(velocity * delta)
	if collision:
		# Reflect velocity over the surface normal to simulate a bounce
		velocity = velocity.bounce(collision.get_normal())

func start_explosion_timer():
	await get_tree().create_timer(explosion_delay).timeout
	explode()

func explode():
	if not bullet_scene:
		queue_free()
		return

	var origin = global_position
	for i in range(8):
		var bullet = bullet_scene.instantiate()
		var angle = i * (PI * 2 / 8)
		var dir = Vector2(cos(angle), sin(angle))
		bullet.global_position = origin
		bullet.setup(dir, 400)  # Adjust speed if needed
		get_tree().current_scene.add_child(bullet)

	queue_free()
