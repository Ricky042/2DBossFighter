extends Area2D

var velocity = Vector2.ZERO

func setup(direction: Vector2, speed: float) -> void:
	velocity = direction.normalized() * speed
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("moving")

func _physics_process(delta: float) -> void:
	position += velocity * delta

# Collision handling
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Boss"):  # Make sure boss is in this group
		body.take_damage(1)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Boss"):
		var boss = area.get_parent()  # Move up to the main Boss node
		if boss.has_method("take_damage"):
			boss.take_damage(1)
		queue_free()
