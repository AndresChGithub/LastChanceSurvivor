extends "res://tests/test_case.gd"
## Verifies chunk terrain generation (Game_Data.Chunk in Scripts/backend.gd).
## Worlds are only saved as a seed, so the same seed MUST always rebuild the
## same terrain, or broken trees/boulders would reappear in the wrong places.

const CHUNK_SIZE = 1024

var tree: SceneTree


## Turns a chunk's terrain into plain data so two chunks can be compared.
func _layout(chunk: Game_Data.Chunk) -> Array:
	var items := []
	for item in chunk.terrain:
		items.append([item.type, item.position])
	return items


func test_same_seed_and_position_gives_identical_terrain() -> void:
	var first := Game_Data.Chunk.new(Vector2i(1024, -2048), 1234)
	var second := Game_Data.Chunk.new(Vector2i(1024, -2048), 1234)
	check(not first.terrain.is_empty(), "chunk should contain terrain")
	check(_layout(first) == _layout(second), "same seed + position should regenerate the same terrain")


func test_different_seeds_give_different_terrain() -> void:
	var a := Game_Data.Chunk.new(Vector2i.ZERO, 1234)
	var b := Game_Data.Chunk.new(Vector2i.ZERO, 98765)
	check(_layout(a) != _layout(b), "two worlds with different seeds should not look the same")


func test_different_chunks_in_one_world_differ() -> void:
	var here := Game_Data.Chunk.new(Vector2i.ZERO, 1234)
	var next_door := Game_Data.Chunk.new(Vector2i(CHUNK_SIZE, 0), 1234)
	check(_layout(here) != _layout(next_door), "neighbouring chunks should not be copies of each other")


func test_terrain_stays_inside_its_chunk() -> void:
	for chunk_pos in [Vector2i.ZERO, Vector2i(-CHUNK_SIZE, CHUNK_SIZE), Vector2i(5 * CHUNK_SIZE, -3 * CHUNK_SIZE)]:
		var chunk := Game_Data.Chunk.new(chunk_pos, 777)
		check_eq(chunk.position, chunk_pos, "chunk remembers its position")
		for item in chunk.terrain:
			# Terrain positions are local offsets from the chunk origin.
			if item.position.x < 0 or item.position.x >= CHUNK_SIZE \
					or item.position.y < 0 or item.position.y >= CHUNK_SIZE:
				check(false, "terrain at %s is outside chunk %s" % [item.position, chunk_pos])
				break


func test_terrain_types_are_known() -> void:
	var seen := {}
	for seed_value in [1, 2, 3]:
		for item in Game_Data.Chunk.new(Vector2i.ZERO, seed_value).terrain:
			check(item.type in Game_Data.TERRAIN_TYPES, "unknown terrain type '%s'" % item.type)
			seen[item.type] = true
	for type in Game_Data.TERRAIN_TYPES:
		check(seen.has(type), "'%s' never generated across three chunks" % type)


func test_terrain_count_is_reasonable() -> void:
	# Count comes from a Gaussian with mean 100 and std 20; 6 std away is
	# essentially impossible, so anything outside means the generator changed.
	for seed_value in range(10):
		var count := Game_Data.Chunk.new(Vector2i.ZERO, seed_value).terrain.size()
		check(count >= 0 and count <= 220, "seed %d produced %d terrain items" % [seed_value, count])
