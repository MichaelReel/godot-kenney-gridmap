extends Spatial

# Configurable parameters
export (AABB)    var base_extents    = AABB(Vector3(0, 1, 0), Vector3(5, 1, 5)) # how big to make the building
export (int)     var building_seed   = 1                                        # randomization seed

# Tiles
var base_tile
var road_tile
var floor_tile
var roof_corner_tile
var roof_slant_tile
var roof_straight_tile
var roof_straight_end_tile
var roof_point_tile

var wall_scaffold
var external_door
var stairs
var keep_clear

# Rotations
const NORTH = 16
const SOUTH = 22
const EAST = 0
const WEST = 10

func _ready():
	# GridMaps
	var floor_layer = $FloorGrid
	var wall_layer = $WallGrid
	
	setup(base_extents, building_seed, floor_layer, wall_layer)

func setup(extents, seid, floor_layer, wall_layer):
	
	setup_tiles(floor_layer.theme, wall_layer.theme)
	rand_seed(seid)
	
#	draw_tiles_solid_box(floor_layer, extents, floor_tile)
	var all_floors = draw_roof(floor_layer, wall_layer, extents)
	all_floors = split_levels(all_floors)
	draw_wall_scaffold(wall_layer, extents)
	draw_floor_bases(floor_layer, all_floors)
	create_stairwell(floor_layer, wall_layer, all_floors)
	define_building_features(wall_layer, extents)

func setup_tiles(floor_theme, wall_theme):
	
	# Terrain tiles
	base_tile              = floor_theme.find_item_by_name("Plate_Grass_01")
	road_tile              = floor_theme.find_item_by_name("Plate_Pavement_01")
	floor_tile             = floor_theme.find_item_by_name("Plate_Wood_01")
	roof_corner_tile       = floor_theme.find_item_by_name("Roof_Corner_Red_02")
	roof_slant_tile        = floor_theme.find_item_by_name("Roof_Slant_Red_01")
	roof_straight_tile     = floor_theme.find_item_by_name("Roof_Straight_Red_01")
	roof_straight_end_tile = floor_theme.find_item_by_name("Roof_Straight_End_Red_01")
	roof_point_tile        = floor_theme.find_item_by_name("Roof_Point_Red_01")
	
	# Wall Tiles
	wall_scaffold     = wall_theme.find_item_by_name("Wood_Wall_Double_Cross_01")
	external_door     = wall_theme.find_item_by_name("Wood_Door_Round_01")
	stairs            = wall_theme.find_item_by_name("Stairs_Wood_01")
	keep_clear        = 2000

func draw_tiles_solid_box(floor_layer, extents, tile):
	var box = AABB(extents.position - Vector3(0, 1, 0), extents.size)
	var pos = box.position
	for z in box.size.z:
		for y in box.size.y:
			for x in box.size.x:
				pos.x = box.position.x + x
				pos.y = box.position.y + y
				pos.z = box.position.z + z
				floor_layer.set_cell_item(pos.x, pos.y, pos.z, tile)

func draw_roof(floor_layer, wall_layer, box):
	var queue = [box]
	var living_space = []
	while not queue.empty():
		var top_box = queue.pop_front()
		queue += draw_roof_stage(floor_layer, wall_layer, top_box)
		living_space.append(top_box)
	return living_space

func draw_roof_stage(floor_layer, wall_layer, box):
	# If x and z are both 1, then just a point will do
	if box.size.x == 1 and box.size.z == 1:
		floor_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_point_tile, EAST)
		return []

	# If x or z are equal to 1, then we're on straight bits
	if box.size.x == 1:
		floor_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_straight_end_tile, NORTH)
		floor_layer.set_cell_item(box.position.x, box.end.y, box.end.z - 1, roof_straight_end_tile, SOUTH)
		if box.size.z > 2:
			for z in range (box.position.z + 1, box.end.z - 1):
				floor_layer.set_cell_item(box.position.x, box.end.y, z, roof_straight_tile, NORTH)
		return []

	if box.size.z == 1:
		floor_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_straight_end_tile, 10)
		floor_layer.set_cell_item(box.end.x - 1, box.end.y, box.position.z, roof_straight_end_tile, EAST)
		if box.size.x > 2:
			for x in range (box.position.x + 1, box.end.x - 1):
				floor_layer.set_cell_item(x, box.end.y, box.position.z, roof_straight_tile, EAST)
		return []

	var raised_sections = []
	# draw corners - TODO: currently very specific code, may be able to generify:
	floor_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_corner_tile, NORTH)
	floor_layer.set_cell_item(box.end.x - 1, box.end.y, box.position.z, roof_corner_tile, EAST)
	floor_layer.set_cell_item(box.position.x, box.end.y, box.end.z - 1, roof_corner_tile, 10)
	floor_layer.set_cell_item(box.end.x - 1, box.end.y, box.end.z - 1, roof_corner_tile, SOUTH)

	# If x or z are greater than 2 then:
	# we need to insert the slant pieces
	if box.size.x > 2:
		for x in range (box.position.x + 1, box.end.x - 1):
			floor_layer.set_cell_item(x, box.end.y, box.position.z, roof_slant_tile, NORTH)
			floor_layer.set_cell_item(x, box.end.y, box.end.z - 1, roof_slant_tile, SOUTH)

	if box.size.z > 2:
		for z in range(box.position.z + 1, box.end.z - 1):
			floor_layer.set_cell_item(box.position.x, box.end.y, z, roof_slant_tile, 10)
			floor_layer.set_cell_item(box.end.x - 1, box.end.y, z, roof_slant_tile, EAST)

	# If x and y are both greater than 2, then:
	# we need another higher roof box to build roof pieces on
	if box.size.x > 2 and box.size.z > 2:
		raised_sections.append(AABB(Vector3(box.position.x + 1, box.end.y, box.position.z + 1), Vector3(box.size.x - 2, 1, box.size.z - 2)))

	return raised_sections

func split_levels(all_boxes):
	var all_floors = []
	while not all_boxes.empty():
		var box = all_boxes.pop_front()
		if box.size.y > 1:
			for y in range (box.position.y, box.end.y):
				all_floors.append(AABB(Vector3(box.position.x, y, box.position.z), Vector3(box.size.x, 1, box.size.z)))
		else:
			all_floors.append(box)
	all_floors.sort_custom(self, "top_down")
	return all_floors

func top_down(a, b):
	return a.position.y > b.position.y

func draw_wall_scaffold(wall_layer, box):
	# Draw each external wall indiviually
	draw_north_wall(wall_layer, box)
	draw_west_wall(wall_layer, box)
	draw_south_wall(wall_layer, box)
	draw_east_wall(wall_layer, box)

func draw_north_wall(wall_layer, box):
	# The -Z facing wall
	var box_z = box.position.z
	for y in range(box.position.y, box.end.y):
		for box_x in range(box.position.x, box.end.x):
			var x = box_x * 2
			var z = box_z * 2 - 1
			wall_layer.set_cell_item(x, y, z, wall_scaffold, NORTH)

func draw_west_wall(wall_layer, box):
	# The -X facing wall
	var box_x = box.position.x
	for y in range(box.position.y, box.end.y):
		for box_z in range(box.position.z, box.end.z):
			var x = box_x * 2 - 1
			var z = box_z * 2
			wall_layer.set_cell_item(x, y, z, wall_scaffold, 10)

func draw_south_wall(wall_layer, box):
	# The +Z facing wall
	var box_z = box.end.z
	for y in range(box.position.y, box.end.y):
		for box_x in range(box.position.x, box.end.x):
			var x = box_x * 2
			var z = box_z * 2 - 1
			wall_layer.set_cell_item(x, y, z, wall_scaffold, SOUTH)

func draw_east_wall(wall_layer, box):
	# The +X facing wall
	var box_x = box.end.x
	for y in range(box.position.y, box.end.y):
		for box_z in range(box.position.z, box.end.z):
			var x = box_x * 2 - 1
			var z = box_z * 2
			wall_layer.set_cell_item(x, y, z, wall_scaffold, EAST)

func draw_floor_bases(floor_layer, all_floors):
	for floor_level in all_floors:
		draw_tiles_solid_box(floor_layer, floor_level, floor_tile)

func create_stairwell(floor_layer, wall_layer, all_floors):
	for floor_ind in range(1, all_floors.size()):
		var lower_level = all_floors[floor_ind]
		# If there is no space for a landing, then skip this flight
		if lower_level.size.x <= 1 and lower_level.size.z <= 1:
			continue
		# Find a square with an empty floor tile beside it which is opposite another empty floor tile on the next (lower) level
		var found = false
		var position = Vector3()
		var rot = EAST
		for z in range(lower_level.position.z, lower_level.end.z):
			if found: break
			for x in range(lower_level.position.x, lower_level.end.x):
				if found: break
				for roty in [EAST, NORTH, WEST, SOUTH]:
					if found: break
					position.x = x
					position.y = lower_level.position.y
					position.z = z
					rot = roty
					found = is_viable_stair_flight(floor_layer, wall_layer, position, rot)
		if found:
			floor_layer.set_cell_item(position.x, position.y, position.z, -1, rot)
			var x = position.x * 2
			var z = position.z * 2
			wall_layer.set_cell_item(x, position.y,     z, stairs, rot)
			wall_layer.set_cell_item(x, position.y + 1, z, keep_clear)
			# Set markers at the foot and landing so we don't get feature collisions
			var offset = get_rotation_offsets(rot)
			mark_foot_and_landing(wall_layer, position, offset)
			

func is_viable_stair_flight(floor_layer, wall_layer, position, rot):
	# Check this floor and upper floor are solid floor first and not occupied by 'walls'
	if !check_clear_for_stairs(floor_layer, wall_layer, position, Vector3()):
		return false
	var offset = get_rotation_offsets(rot)
	# Check foot and landing are floored and not blocked by 'walls'
	return check_clear_for_stairs(floor_layer, wall_layer, position, offset)

func get_rotation_offsets(rotation):
	var offset = Vector3()
	# This part is dependent on the orientation of the model
	# Currently the stair model is naturally orientated to match these rotations
	match rotation:
		NORTH:
			offset.z = -1
		SOUTH:
			offset.z = 1
		EAST:
			offset.x = 1
		WEST:
			offset.x = -1
	return offset

func check_clear_for_stairs(floor_layer, wall_layer, position, offset):
	if floor_layer.get_cell_item(position.x + offset.x,      position.y - 1,  position.z + offset.z) != floor_tile:
		return false
	if floor_layer.get_cell_item(position.x - offset.x,      position.y,      position.z - offset.z) != floor_tile:
		return false
	if wall_layer.get_cell_item((position.x + offset.x) * 2, position.y,     (position.z + offset.z) * 2) != GridMap.INVALID_CELL_ITEM:
		return false
	if wall_layer.get_cell_item((position.x - offset.x) * 2, position.y + 1, (position.z - offset.z) * 2) != GridMap.INVALID_CELL_ITEM:
		return false
	return true

func mark_foot_and_landing(wall_layer, position, offset):
	wall_layer.set_cell_item((position.x + offset.x) * 2, position.y,     (position.z + offset.z) * 2, keep_clear)
	wall_layer.set_cell_item((position.x - offset.x) * 2, position.y + 1, (position.z - offset.z) * 2, keep_clear)

func define_building_features(wall_layer, box):
	# For now, pick a random wall and put a door in it
	var y = box.position.y
	var x = 0
	var z = 0
	var rot = 0
	var wall = randi() % 4
	match wall:
		0: # North wall
			x = (randi() % int(box.size.x) + box.position.x) * 2
			z = box.position.z * 2 - 1
			rot = NORTH
		1: # West wall
			x = box.position.x * 2 - 1
			z = (randi() % int(box.size.z) + box.position.z) * 2
			rot = WEST
		2: # South wall
			x = (randi() % int(box.size.x) + box.position.x) * 2
			z = box.end.z * 2 - 1
			rot = SOUTH
		3: # East wall
			x = box.end.x * 2 - 1
			z = (randi() % int(box.size.z) + box.position.z) * 2
			rot = EAST

	wall_layer.set_cell_item(x, y, z, external_door, rot)
