
extends CharacterBody2D

const SPEED: float = 360.0

@onready var sprite: Sprite2D = $player_sprite
@onready var interaction_range: Area2D = $InteractionRange
@onready var camera: Camera2D = $"../Camera2D"

func _physics_process(_delta: float) -> void:
	var direction = Input.get_vector(
		"move_left", "move_right",
		"move_up", "move_down"
	)

	velocity = direction * SPEED
	move_and_slide()
	camera.position = position

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
	
	# chunk rendering
	var current_chunk = Vector2i(
	floori(position.x / 1024.0) * 1024,
	floori(position.y / 1024.0) * 1024
)
	var chunks_to_render = [
	current_chunk, 
	current_chunk + Vector2i(1024, 0),
	current_chunk + Vector2i(-1024, 0),
	current_chunk + Vector2i(0, 1024),
	current_chunk + Vector2i(0, -1024),
	current_chunk + Vector2i(1024, 1024),
	current_chunk + Vector2i(-1024, -1024),
	current_chunk + Vector2i(1024, -1024),
	current_chunk + Vector2i(-1024, 1024)
]
	for chunk_pos in chunks_to_render:
		if Game_Data.rendered_chunks.has(chunk_pos):
			pass
		else:
			if Game_Data.loaded_chunks.has(chunk_pos):
				# render the chunk
				render_chunk(Game_Data.loaded_chunks[chunk_pos])
				Game_Data.rendered_chunks[chunk_pos] = Game_Data.loaded_chunks[chunk_pos]
			else:
		
				# generate the chunk, then render it
				Game_Data.loaded_chunks[chunk_pos] = Game_Data.Chunk.new(chunk_pos, Game_Data.seed)
				render_chunk(Game_Data.loaded_chunks[chunk_pos])
				Game_Data.rendered_chunks[chunk_pos] = Game_Data.loaded_chunks[chunk_pos]
				
				
const tree_scene = preload("res://Scenes/Tree.tscn")
const boulder_scene = preload("res://Scenes/Boulder.tscn")
const plant_scene = preload("res://Scenes/Plant.tscn")
func render_chunk(chunk: Game_Data.Chunk):
	print(chunk.terrain.size())
	for terrain in chunk.terrain:
		if terrain.type == "Tree":
			var tree = tree_scene.instantiate()
			tree.position = terrain.position + chunk.position
			get_parent().add_child(tree)
			#render the tree
		if terrain.type == "Boulder":
			var boulder = boulder_scene.instantiate()
			boulder.position = terrain.position + chunk.position
			get_parent().add_child(boulder)
		if terrain.type == "Plant":
			var plant = plant_scene.instantiate()
			plant.position = terrain.position + chunk.position
			get_parent().add_child(plant)
	
	


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
