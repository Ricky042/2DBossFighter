extends Area2D

# Speed and movement vector for the bullet
var velocity = Vector2.ZERO

# Preload the Player script for type checking on collision
const Player = preload("res://characters/player.gd")

# Reference to the AnimatedSprite2D node (adjust path if needed)
@onready var sprite := $AnimatedSprite2D

# Called to initialize the bullet's direction, speed, and optionally animation
func setup(direction: Vector2, speed: float, anim_name: String = "moving") -> void:
	velocity = direction.normalized() * speed
	if sprite and anim_name != "":
		sprite.play(anim_name)

# Called every physics frame to update bullet position
func _physics_process(delta: float) -> void:
	# Move bullet by velocity scaled by delta time
	position += velocity * delta

# Handle collision with other bodies
func _on_body_entered(body: Node) -> void:
	# Check if the colliding body is the player
	if body is Player:
		# If player is invulnerable, do nothing
		if body.is_invulnerable:
			return
		# Otherwise, deal damage to the player (change damage as needed)
		body.take_damage(1)
	# Remove the bullet from the scene after collision
	queue_free()
