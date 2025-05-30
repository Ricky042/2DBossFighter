extends CharacterBody2D

@export var speed := 250.0
@export var explosion_delay := 2.0
@export var bullet_scene: PackedScene

@onready var animated_sprite := $AnimatedSprite2D  # Make sure this path is correct

var exploded := false

func setup(direction: Vector2):
	velocity = direction.normalized() * speed

func _ready():
	start_explosion_timer()

func _physics_process(delta):
	if exploded:
		return

	var collision = move_and_collide(velocity * delta)
	if collision:
		# Check if we hit the player
		var collider = collision.get_collider()
		if collider.is_in_group("Player"):
			collider.take_damage(1)
			explode()
		else:
			velocity = velocity.bounce(collision.get_normal())

func start_explosion_timer() -> void:
	await get_tree().create_timer(explosion_delay).timeout
	explode()

func explode():
	if exploded:
		return
	exploded = true
	velocity = Vector2.ZERO  # stop movement
	
	animated_sprite.play("explode")
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	if bullet_scene:
		var origin = global_position
		for i in range(16):
			var bullet = bullet_scene.instantiate()
			var angle = i * (TAU / 16)
			var dir = Vector2(cos(angle), sin(angle))
			bullet.global_position = origin
			
			# Pass "moving" to play correct animation
			bullet.setup(dir, 400, "moving")
			
			get_tree().current_scene.add_child(bullet)
	queue_free()
