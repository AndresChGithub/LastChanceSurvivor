
extends CharacterBody2D

const SPEED: float = 360.0

@onready var sprite: Sprite2D = $player_sprite
@onready var interaction_range: Area2D = $InteractionRange


func _physics_process(_delta: float) -> void:
	var direction = Input.get_vector(
		"move_left", "move_right",
		"move_up", "move_down"
	)

	velocity = direction * SPEED
	move_and_slide()

func _process(delta: float) -> void:
	var mouse_direction = get_global_mouse_position() - sprite.global_position

	if mouse_direction.length_squared() < 1.0:
		return

	var target_angle = mouse_direction.angle() + PI

	sprite.global_rotation = lerp_angle(
		sprite.global_rotation,
		target_angle,
		12.0 * delta
	)



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("harvest"):
		try_harvest()


func try_harvest() -> void:
	var closest_resource: Node2D = null
	var closest_distance: float = INF

	for body in interaction_range.get_overlapping_bodies():
		if not body.is_in_group("harvestable"):
			continue

		if not body.has_method("harvest"):
			continue

		var distance = global_position.distance_to(body.global_position)

		if distance < closest_distance:
			closest_distance = distance
			closest_resource = body

	if closest_resource != null:
		closest_resource.harvest()
