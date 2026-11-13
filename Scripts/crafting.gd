class_name Crafting
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


class craftable_item:
	var name: String = ""
	var recipe: Dictionary[String, int] = {}
	func _init(name_: String, recipe_: Dictionary[String, int]):
		name = name_

var recipe_book: Array[craftable_item]
var knife = craftable_item.new("knife", {"wood": 40, "stone": 100, "fiber": 50})
