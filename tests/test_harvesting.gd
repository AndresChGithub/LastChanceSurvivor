extends "res://tests/test_case.gd"
## Verifies harvesting trees, boulders and plants (Scenes/tree.gd).
## Nobody is signed in while tests run, so nothing here touches the save file.

const SCENES = {
	"res://Scenes/Tree.tscn": "wood",
	"res://Scenes/Boulder.tscn": "stone",
	"res://Scenes/Plant.tscn": "fiber",
}

var tree: SceneTree
var spawned: Array[Node] = []
var collected: Array = []


func after_each() -> void:
	for node in spawned:
		if is_instance_valid(node):
			node.free()


func _spawn(scene_path: String) -> StaticBody2D:
	var node: StaticBody2D = load(scene_path).instantiate()
	node.position = Vector2(5000, 5000)
	node.resources_collected.connect(func(type, amount): collected.append([type, amount]))
	tree.root.add_child(node)
	spawned.append(node)
	return node


func test_each_scene_gives_its_own_resource() -> void:
	for scene_path in SCENES:
		collected.clear()
		var node := _spawn(scene_path)
		check(node.is_in_group("harvestable"), "%s should be in the 'harvestable' group" % scene_path.get_file())
		node.harvest()
		check_eq(collected, [[SCENES[scene_path], 1]], "%s first hit" % scene_path.get_file())


func test_one_resource_per_hit_including_the_final_hit() -> void:
	# Regression test: the final hit used to award the resource twice.
	var node := _spawn("res://Scenes/Tree.tscn")
	for i in node.hits_to_break:
		node.harvest()
	check_eq(collected.size(), node.hits_to_break, "one reward per hit")
	var total := 0
	for reward in collected:
		total += reward[1]
	check_eq(total, node.hits_to_break * node.resource_amount, "total wood from one tree")


func test_breaks_after_enough_hits() -> void:
	var node := _spawn("res://Scenes/Boulder.tscn")
	for i in node.hits_to_break - 1:
		node.harvest()
	check(not node.is_queued_for_deletion(), "should survive until the last hit")
	node.harvest()
	check(node.is_queued_for_deletion(), "should be removed on the last hit")
	check_eq(node.hits_remaining, 0, "no hits remaining")


func test_hitting_a_broken_object_gives_nothing() -> void:
	var node := _spawn("res://Scenes/Plant.tscn")
	for i in node.hits_to_break:
		node.harvest()
	var before := collected.size()
	node.harvest()
	node.harvest()
	check_eq(collected.size(), before, "extra hits after breaking should not give resources")
