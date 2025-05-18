extends CanvasLayer

@onready var label = $Label
@onready var button = $Button

func _ready():
	button.pressed.connect(_on_play_again)

func show_game_over(victory: bool):
	if victory:
		label.text = "Victory!"
	else:
		label.text = "Defeat"

	visible = true
	get_tree().paused = true

	button.process_mode = Node.PROCESS_MODE_ALWAYS
	label.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_play_again():
	get_tree().paused = false  # Unpause the game
	get_tree().reload_current_scene()  # Restart the current scene
