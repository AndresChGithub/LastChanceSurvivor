class_name Game_Data
extends RefCounted


const TERRAIN_TYPES = ["Tree", "Boulder", "Plant"]
var loaded_chunks: Dictionary[Vector2i, Game_Data.Chunk]

# This file contains data structures to keep track of the game state, which will be stored in SQL
#TODO: Store player/user information
#TODO: Create JSON file
#TODO: send file to SQL using godot-sqlite addon (or another method)

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
	
	var terrain: Array[Terrain_Item] = []
	
	var north: Chunk
	var east: Chunk
	var south: Chunk
	var west: Chunk
	
	func _init(pos: Vector2i):
		position = pos
		
		# Now randomly generate terrain in this chunk.  Each terrain item has coordinates defined with repect to the 
		# chunk center.  global_pos = chunk_center + relative_pos
		
		# selects the amount of terrain items that will spawn from a Gaussian distribution, change the mean
		# and std to tweak the random generation
		var mean: float
		var std: float
		var terrain_count: int = floor(randfn(mean, std))
		
		for i in range(terrain_count):
			var terrain_type: String = TERRAIN_TYPES.pick_random()
			var x_pos: int = randi_range(0, 1023)
			var y_pos: int = randi_range(0, 1023)
			position.x = x_pos
			position.y = y_pos
			
			var terrain_item = Terrain_Item.new(terrain_type, position)
			terrain.append(terrain_item)
		
			
		
