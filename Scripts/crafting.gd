class_name Crafting

var current_player = get_node("res://Scripts/DatabaseManager.gd/current_player")

class CraftableItem:
	var name: String
	var recipe: Dictionary[String, int]

	func _init(name_: String, recipe_: Dictionary[String, int]):
		name = name_
		recipe = recipe_


var recipe_book: Array[CraftableItem] = []

var knife = CraftableItem.new("knife", {
	"wood": 40,
	"stone": 100,
	"fiber": 50
})

var axe = CraftableItem.new("axe", {
	"wood": 100,
	"stone": 200,
	"fiber": 50
})

var string = CraftableItem.new("string", {
	"fiber": 100
})

var bow = CraftableItem.new("bow", {
	"string": 5,
	"wood": 100
})

var pickaxe = CraftableItem.new("pickaxe", {
	"wood": 150,
	"stone": 300,
	"fiber": 100
})

var hoe = CraftableItem.new("hoe", {
	"wood": 150,
	"stone": 300,
	"fiber": 100
})

func _ready() -> void:
	recipe_book.append(knife)
	recipe_book.append(axe)
	recipe_book.append(string)
	recipe_book.append(bow)
	recipe_book.append(pickaxe)
	recipe_book.append(hoe)

# returns an array of all items that can be crafted
func craftable():
	var craftable_items: Array[String] = []
	for item in recipe_book:
		if 
		pass
