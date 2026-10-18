extends CharacterBody2D
@onready var sprite = $player_sprite


const SPEED = 1200.0

var texture_left = preload("res://assets/player.png")
var texture_right = preload("res://Assets/player_reversed.png")

func _physics_process(delta: float) -> void:
	

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var x_direction := Input.get_axis("ui_left", "ui_right")
	var y_direction := Input.get_axis("ui_up", "ui_down")
	if x_direction:
		velocity.x = x_direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	if y_direction:
		velocity.y = y_direction * SPEED
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED)

	move_and_slide()
	facing_direction(x_direction)
	
	
func facing_direction(direction) -> void:
		if direction < 0:
			sprite.texture = texture_left
		if direction > 0:
			sprite.texture = texture_right
		
