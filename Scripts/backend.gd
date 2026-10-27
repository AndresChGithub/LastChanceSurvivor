class_name Game_Data
extends RefCounted

const TERRAIN_TYPES = ["Tree", "Boulder", "Plant"]
static var loaded_chunks: Dictionary[Vector2i, Game_Data.Chunk]
static var rendered_chunks: Dictionary[Vector2i, Game_Data.Chunk]

# each player will have an item dictionary to keep track of progress.  Keys are the game's resources,
# values are how many the player has.  
var item_dict: Dictionary[String, int] = {"wood": 0, "stone": 0, "fiber": 0}

# This file contains data structures to keep track of the game state, which will be stored in SQL

# set seed and for random terrain generation
const seed: int = 1234

class User_Account:
	var username: String
	var password_hash: String
	# number of seconds the player has survived
	var score: int
	# each player will have an item dictionary to keep track of progress.  Keys are the game's resources,
	# values are how many the player has.  
	var item_dict: Dictionary[String, int] = {"wood": 0, "stone": 0, "fiber": 0}
	var position: Vector2i
	
	func _init(user: String, hash: String) -> void:
		username = user
		password_hash = hash
		position = Vector2i(0, 0)
		score = 0
		
class Terrain_Item:
	# can be "Tree", "Boulder" or "Plant", etc when we add more
	var type: String
	
	var position: Vector2i
	var durability: int
	
	func _init(t: String, pos: Vector2i):
		type = t
		position = pos
		durability = 100
		
class Chunk:
	# the origin of a chunk is defined as its bottom left corner.
	# the chunk accounts for the square [origin_x, origin_x + 1023] X [origin_y, origin_ + 1023]
	var position: Vector2i
	var rng: RandomNumberGenerator

	var terrain: Array[Terrain_Item] = []
	
	
	func _init(pos: Vector2i, world_seed: int):
		position = pos

		# Create an independent RNG for this chunk
		rng = RandomNumberGenerator.new()
		rng.seed = hash([world_seed, pos])

		# Generate terrain count using a Gaussian distribution
		var mean: float = 100.0
		var std: float = 20.0
		var terrain_count: int = maxi(0, floori(rng.randfn(mean, std)))

		# Generate terrain items
		for i in range(terrain_count):
			var terrain_type: String = TERRAIN_TYPES[
				rng.randi_range(0, TERRAIN_TYPES.size() - 1)
			]

			var x_pos: int = rng.randi_range(0, 1023)
			var y_pos: int = rng.randi_range(0, 1023)

			var terrain_pos = Vector2i(x_pos, y_pos)
			var terrain_item = Terrain_Item.new(terrain_type, terrain_pos)

			terrain.append(terrain_item)
