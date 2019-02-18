extends Spatial

# Configurable parameters
export (AABB)    var base_extents    = AABB(Vector3(0, 1, 0), Vector3(5, 2, 5)) # how big to make the building
export (int)     var building_seed   = 0                                        # randomization seed


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

func _ready():
	# GridMaps
	var floor_layer = $FloorGrid
	var wall_layer = $WallGrid
	
	setup(base_extents, building_seed, floor_layer, wall_layer)

func setup(extents, seid, floor_layer, wall_layer):
	
	setup_tiles(floor_layer.theme, wall_layer.theme)
	rand_seed(seid)
	
	draw_tiles_solid_box(floor_layer, extents, floor_tile)
	draw_roof(floor_layer, extents)
	draw_wall_scaffold(wall_layer, extents)
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

func draw_tiles_solid_box(floor_layer, extents, tile):
	var basement = Vector3(0, 1, 0)
	var box = AABB(extents.position - basement, extents.size + basement)
	var pos = box.position
	for z in box.size.z:
		for y in box.size.y:
			for x in box.size.x:
				pos.x = box.position.x + x
				pos.y = box.position.y + y
				pos.z = box.position.z + z
				floor_layer.set_cell_item(pos.x, pos.y, pos.z, tile)

func draw_roof(floor_layer, box):
	var queue = [box]
	while not queue.empty():
		queue += draw_roof_stage(floor_layer, queue.pop_front())

func draw_roof_stage(floor_layer, box):
	# If x and z are both 1, then just a point will do
	if box.size.x == 1 and box.size.z == 1:
		floor_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_point_tile, 0)
		return []

	# If x or z are equal to 1, then we're on straight bits
	if box.size.x == 1:
		floor_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_straight_end_tile, 16)
		floor_layer.set_cell_item(box.position.x, box.end.y, box.end.z - 1, roof_straight_end_tile, 22)
		if box.size.z > 2:
			for z in range (box.position.z + 1, box.end.z - 1):
				floor_layer.set_cell_item(box.position.x, box.end.y, z, roof_straight_tile, 16)
		return []

	if box.size.z == 1:
		floor_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_straight_end_tile, 10)
		floor_layer.set_cell_item(box.end.x - 1, box.end.y, box.position.z, roof_straight_end_tile, 0)
		if box.size.x > 2:
			for x in range (box.position.x + 1, box.end.x - 1):
				floor_layer.set_cell_item(x, box.end.y, box.position.z, roof_straight_tile, 0)
		return []

	var raised_sections = []
	# draw corners - TODO: currently very specific code, may be able to generify:
	floor_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_corner_tile, 16)
	floor_layer.set_cell_item(box.end.x - 1, box.end.y, box.position.z, roof_corner_tile, 0)
	floor_layer.set_cell_item(box.position.x, box.end.y, box.end.z - 1, roof_corner_tile, 10)
	floor_layer.set_cell_item(box.end.x - 1, box.end.y, box.end.z - 1, roof_corner_tile, 22)

	# If x or z are greater than 2 then:
	# we need to insert the slant pieces
	if box.size.x > 2:
		for x in range (box.position.x + 1, box.end.x - 1):
			floor_layer.set_cell_item(x, box.end.y, box.position.z, roof_slant_tile, 16)
			floor_layer.set_cell_item(x, box.end.y, box.end.z - 1, roof_slant_tile, 22)

	if box.size.z > 2:
		for z in range(box.position.z + 1, box.end.z - 1):
			floor_layer.set_cell_item(box.position.x, box.end.y, z, roof_slant_tile, 10)
			floor_layer.set_cell_item(box.end.x - 1, box.end.y, z, roof_slant_tile, 0)

	# If x and y are both greater than 2, then:
	# we need another higher roof box to build roof pieces on
	if box.size.x > 2 and box.size.z > 2:
		raised_sections.append(AABB(Vector3(box.position.x + 1, box.end.y, box.position.z + 1), Vector3(box.size.x - 2, 1, box.size.z - 2)))

	return raised_sections

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
			wall_layer.set_cell_item(x, y, z, wall_scaffold, 16)

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
			wall_layer.set_cell_item(x, y, z, wall_scaffold, 22)

func draw_east_wall(wall_layer, box):
	# The +X facing wall
	var box_x = box.end.x
	for y in range(box.position.y, box.end.y):
		for box_z in range(box.position.z, box.end.z):
			var x = box_x * 2 - 1
			var z = box_z * 2
			wall_layer.set_cell_item(x, y, z, wall_scaffold, 0)

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
			rot = 16
		1: # West wall
			x = box.position.x * 2 - 1
			z = (randi() % int(box.size.z) + box.position.z) * 2
			rot = 10
		2: # South wall
			x = (randi() % int(box.size.x) + box.position.x) * 2
			z = box.end.z * 2 - 1
			rot = 22
		3: # East wall
			x = box.end.x * 2 - 1
			z = (randi() % int(box.size.z) + box.position.z) * 2
			rot = 0

	wall_layer.set_cell_item(x, y, z, external_door, rot)
