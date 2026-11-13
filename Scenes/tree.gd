
extends StaticBody2D

signal resources_collected(resource_type: String, amount: int)

@export var hits_to_break: int = 3
@export var resource_type: String = "wood"
@export var resource_amount: int = 1

var hits_remaining: int


func _ready() -> void:
	hits_remaining = hits_to_break

	# This player already broke this one on an earlier visit - don't show it.
	if DatabaseManager.is_terrain_broken(_world_key()):
		queue_free()


# The world is generated from a fixed seed, so an object's position
# identifies it across sessions.
func _world_key() -> Vector2i:
	return Vector2i(global_position.round())


func harvest() -> void:
	if hits_remaining <= 0:
		return

	hits_remaining -= 1
	print("Tree hit! Hits remaining: ", hits_remaining)
	resources_collected.emit(resource_type, resource_amount)

	if hits_remaining == 0:
		DatabaseManager.mark_terrain_broken(_world_key())
		queue_free()
