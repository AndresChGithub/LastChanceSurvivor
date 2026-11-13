class_name Crafting
extends RefCounted

class CraftableItem:
	var name: String
	var recipe: Dictionary[String, int]

	func _init(name_: String, recipe_: Dictionary[String, int]):
		name = name_
		recipe = recipe_


var recipe_book: Array[CraftableItem] = [
	CraftableItem.new("knife", {
		"wood": 40,
		"stone": 100,
		"fiber": 50
	}),
	CraftableItem.new("axe", {
		"wood": 100,
		"stone": 200,
		"fiber": 50
	}),
	CraftableItem.new("string", {
		"fiber": 100
	}),
	CraftableItem.new("bow", {
		"string": 5,
		"wood": 100
	}),
	CraftableItem.new("pickaxe", {
		"wood": 150,
		"stone": 300,
		"fiber": 100
	}),
	CraftableItem.new("hoe", {
		"wood": 150,
		"stone": 300,
		"fiber": 100
	})
]

func get_recipe(item_name: String) -> CraftableItem:
	for item in recipe_book:
		if item.name == item_name:
			return item
	return null


func can_craft(item_name: String, inventory: Dictionary) -> bool:
	var item := get_recipe(item_name)
	if item == null:
		return false

	for ingredient in item.recipe:
		if int(inventory.get(ingredient, 0)) < item.recipe[ingredient]:
			return false
	return true


func craft(item_name: String, inventory: Dictionary) -> bool:
	var item := get_recipe(item_name)
	if item == null or not can_craft(item_name, inventory):
		return false

	for ingredient in item.recipe:
		inventory[ingredient] = int(inventory.get(ingredient, 0)) - item.recipe[ingredient]
	inventory[item.name] = int(inventory.get(item.name, 0)) + 1
	return true


func craftable(inventory: Dictionary) -> Array[String]:
	var craftable_items: Array[String] = []
	for item in recipe_book:
		if can_craft(item.name, inventory):
			craftable_items.append(item.name)
	return craftable_items
