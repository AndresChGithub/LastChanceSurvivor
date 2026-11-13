
extends StaticBody2D

signal resources_collected(resource_type: String, amount: int)

@export var hits_to_break: int = 3
@export var wood_amount: int = 5

var hits_remaining: int


func _ready() -> void:
	hits_remaining = hits_to_break


func harvest() -> void:
	if hits_remaining <= 0:
		return

	hits_remaining -= 1
	print("Tree hit! Hits remaining: ", hits_remaining)

	if hits_remaining == 0:
		resources_collected.emit("wood", wood_amount)
		queue_free()
