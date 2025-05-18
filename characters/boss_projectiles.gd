extends Area2D

var velocity = Vector2.ZERO
const Player = preload("res://characters/player.gd")


func setup(direction: Vector2, speed: float) -> void:
	velocity = direction.normalized() * speed
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("moving")

func _physics_process(delta: float) -> void:
	position += velocity * delta

# Collision handling
func _on_body_entered(body: Node) -> void:
	if body is Player:
		if body.is_invulnerable:
			return
		body.take_damage(1)
	queue_free()
