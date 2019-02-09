extends Spatial

# Configurable parameters
export (Vector2)  var base_extends    = Vector2(50,50)      # how big to make the town
export (int)      var town_seed       = 0                   # randomization seed
export (int)      var min_building    = 3                   # minimum building width
export (int)      var max_building    = 10                  # maximum building width
export (int)      var min_height      = 1                   # minimum building height
export (int)      var max_height      = 3                   # maximum building height
export (int)      var road_width      = 2                   # normal width of roads
export (int)      var main_road_width = 4                   # width of the starting main road
export (int)      var split_rate      = 20                  # how likely should block splitting be

# GridMaps
var terrain_layer
var wall_layer

func _ready():
	terrain_layer = $TerrainGrid
	wall_layer = $WallMap
	setup_tiles()
	
	rand_seed(town_seed)
	
	var town_base = Rect2(-base_extends.x / 2, -base_extends.y / 2, base_extends.x, base_extends.y)
	draw_ground_level_tile_square(town_base, base_tile)
	var squares = subdivide(town_base, true)
	var boxes = make_3d_boxes(squares)
	draw_scaffolds(squares, boxes)
	draw_roofs(boxes)
	
	draw_wall_scaffolds(boxes)

# Tiles
var base_tile
var road_tile
var scaffold_tile
var floor_tile
var roof_corner_tile
var roof_slant_tile
var roof_straight_tile
var roof_straight_end_tile
var roof_point_tile

var wall_scaffold_tile

func setup_tiles():
	# Terrain tiles
	base_tile              = terrain_layer.theme.find_item_by_name("Plate_Grass_01")
	road_tile              = terrain_layer.theme.find_item_by_name("Plate_Pavement_01")
	scaffold_tile          = terrain_layer.theme.find_item_by_name("Wood_Scaffolding_01")
	floor_tile             = terrain_layer.theme.find_item_by_name("Plate_Wood_01")
	roof_corner_tile       = terrain_layer.theme.find_item_by_name("Roof_Corner_Red_02")
	roof_slant_tile        = terrain_layer.theme.find_item_by_name("Roof_Slant_Red_01")
	roof_straight_tile     = terrain_layer.theme.find_item_by_name("Roof_Straight_Red_01")
	roof_straight_end_tile = terrain_layer.theme.find_item_by_name("Roof_Straight_End_Red_01")
	roof_point_tile        = terrain_layer.theme.find_item_by_name("Roof_Point_Red_01")
	
	# Wall Tiles
	wall_scaffold_tile     = wall_layer.theme.find_item_by_name("Wood_Wall_Double_Cross_01")

func subdivide(plot, make_center):
	var plots = []
	
	# If a main road division, make the road go from a wall to the centre, 2 wide
	# Then split up the rest of the plot into 3 plots
	if (make_center):
		
		var main_road_half = main_road_width / 2
		var centre = (plot.end + plot.position) / 2
		var main_square = Rect2(centre.x - main_road_half, centre.y - main_road_half, main_road_width, main_road_width)
		
		#  +------+-+---------+  plot.end.y
		#  |      | |         |
		#  |      | |         |
		#  |      +-+-+-------+  main_square.end.y
		#  |      |_|_|       |
		#  |      | | |       |
		#  |      +-+-+-------+  main_square.position.y
		#  |      | |         |
		#  |      | |         |
		#  +------+-+-+-------+  plot.position.y
		#                  
		#  |      | | |       `- plot.end.x
		#  |      | | `- main_square.end.x
		#  |      | `- centre.x
		#  |      `- main_square.position.x
		#  `- plot.position.x
		
		var part_1 = Rect2(plot.position.x, plot.position.y, main_square.position.x - plot.position.x, plot.size.y)
		var part_2 = Rect2(main_square.position.x + road_width, main_square.end.y, plot.end.x - centre.x, plot.end.y - main_square.end.y)
		var part_3 = Rect2(main_square.position.x + road_width, plot.position.y, plot.end.x - centre.x, main_square.position.y - plot.position.y)
		
		#  +------+-+---------+  ^
		#  |p1    |r|p2       |  | part_2.size.y
		#  |      | |         |  |
		#  |      +-+-+-------+  x
		#  |      |ms |mr     |  | main_road_width
		#  |      |   |       |  |
		#  |      +-+-+-------+  x
		#  |      |r|p3       |  | part_3.size.y
		#  |      | |         |  |
		#  +------+-+-+-------+  v
		#                  
		#  <------x-| |------->
		#     |    |      `- part_3.size.x
		#     |    | 
		#     |    `- road_width
		#     `- part_1.size.x
		
		var main_road    = Rect2(main_square.end.x, main_square.position.y, plot.end.x - main_square.end.x, main_road_width)
		var cross_road_1 = Rect2(main_square.position.x, main_square.end.y, road_width, part_2.size.y)
		var cross_road_2 = Rect2(main_square.position.x, plot.position.y, road_width, part_3.size.y)
		
#		draw_ground_level_tile_square(main_square, road_tile)
		draw_ground_level_tile_square(main_road, road_tile)
		draw_ground_level_tile_square(cross_road_1, road_tile)
		draw_ground_level_tile_square(cross_road_2, road_tile)
		plots += subdivide(part_1, false)
		plots += subdivide(part_2, false)
		plots += subdivide(part_3, false)
	else:
		# Try cutting on the longest side first, then the shorter side
		if (plot.size.x > plot.size.y):
			var plots_x = subdivide_by_x(plot)
			if plots_x.size() > 1:
				plots += plots_x
			else: 
				plots += subdivide_by_y(plot)
		else:
			var plots_y = subdivide_by_y(plot)
			if plots_y.size() > 1:
				plots += plots_y
			else:
				plots += subdivide_by_x(plot)
	return plots

func subdivide_by_x(square):
	# Don't bother splitting if we don't beat the odds
	if (square.size.x < max_building) and (randi() % split_rate) == 0:
		return [square]
	
	# Is there enough space to split it?
	if square.size.x < (2 * min_building) + road_width:
		return [square]
	
	# Do any valid splits have a road covering the end?
	var splits = range(square.position.x + min_building, square.end.x - min_building - (road_width - 1))
	var road_splits = []
	for split in splits:
		var road_end_1 = test_plot_for_tile(Rect2(split, square.position.y - 1, road_width - 1, 0), road_tile)
		var road_end_2 = test_plot_for_tile(Rect2(split, square.end.y, road_width - 1, 0), road_tile)
		if (road_end_1 or road_end_2):
			road_splits.append(split)
	
	if road_splits.empty():
		return [square]
	
	# Create the path and return the remaining spaces
	var split = road_splits[randi() % road_splits.size()]
	var road_square = Rect2(split, square.position.y, road_width, square.size.y)
	draw_ground_level_tile_square(road_square, road_tile)
	var squares = []
	squares += subdivide(Rect2(square.position.x, square.position.y, split - square.position.x, square.size.y), false)
	squares += subdivide(Rect2(split + road_width, square.position.y, square.end.x - split - road_width, square.size.y), false)
	return squares

func subdivide_by_y(square):
	# Don't bother splitting if we're small enough already and we don't beat the odds
	if (square.size.y < max_building) and (randi() % split_rate) == 0:
		return [square]
	
	# Is there enough space to split it?
	if square.size.y < (2 * min_building) + road_width:
		return [square]
	
	# Do any valid splits have a road at the end?
	var splits = range(square.position.y + min_building, square.end.y - min_building - (road_width - 1))
	var road_splits = []
	for split in splits:
		var road_end_1 = test_plot_for_tile(Rect2(square.position.x - 1, split, 0, road_width - 1), road_tile)
		var road_end_2 = test_plot_for_tile(Rect2(square.end.x, split, 0, road_width - 1), road_tile)
		if (road_end_1 or road_end_2):
			road_splits.append(split)
	
	if road_splits.empty():
		return [square]
	
	# Create the path and return the remaining spaces
	var split = road_splits[randi() % road_splits.size()]
	var road_square = Rect2(square.position.x, split, square.size.x, road_width)
	draw_ground_level_tile_square(road_square, road_tile)
	var squares = []
	squares += subdivide(Rect2(square.position.x, square.position.y, square.size.x, split - square.position.y), false)
	squares += subdivide(Rect2(square.position.x, split + road_width, square.size.x, square.end.y - split - road_width), false)
	return squares

func test_plot_for_tile(plot, tile):
	for y in range(plot.position.y, plot.end.y):
		for x in range(plot.position.x, plot.end.x): 
			if terrain_layer.get_cell_item(x, 0, y) != tile:
				return false
	return true

func make_3d_boxes(squares):
	var boxes = []
	for square in squares:
		var height = randi() % (max_height - min_height + 1) + min_height
		boxes.append(AABB(Vector3(square.position.x, 1, square.position.y), Vector3(square.size.x, height, square.size.y)))
	return boxes

func draw_scaffolds(squares, boxes):
	for square in squares:
		draw_ground_level_tile_square(square, floor_tile)
	for box in boxes:
		draw_tiles_solid_box(box, scaffold_tile)

func draw_ground_level_tile_square(square, tile):
	var pos = Vector2()
	for y in square.size.y:
		for x in square.size.x:
			pos.x = square.position.x + x
			pos.y = square.position.y + y
			terrain_layer.set_cell_item(pos.x, 0, pos.y, tile)

func draw_tiles_solid_box(box, tile):
	var pos = Vector3()
	for z in box.size.z:
		for y in box.size.y:
			for x in box.size.x:
				pos.x = box.position.x + x
				pos.y = box.position.y + y
				pos.z = box.position.z + z
				terrain_layer.set_cell_item(pos.x, pos.y, pos.z, tile)

func draw_roofs(boxes):
	var queue = [] + boxes
	while not queue.empty():
		queue += draw_roof(queue.pop_front())

func draw_roof(box):
	# If x and z are both 1, then just a point will do
	if box.size.x == 1 and box.size.z == 1:
		terrain_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_point_tile, 0)
		return []
	
	# If x or z are equal to 1, then we're on straight bits
	if box.size.x == 1:
		terrain_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_straight_end_tile, 16)
		terrain_layer.set_cell_item(box.position.x, box.end.y, box.end.z - 1, roof_straight_end_tile, 22)
		if box.size.z > 2:
			for z in range (box.position.z + 1, box.end.z - 1):
				terrain_layer.set_cell_item(box.position.x, box.end.y, z, roof_straight_tile, 16)
		return []
	
	if box.size.z == 1:
		terrain_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_straight_end_tile, 10)
		terrain_layer.set_cell_item(box.end.x - 1, box.end.y, box.position.z, roof_straight_end_tile, 0)
		if box.size.x > 2:
			for x in range (box.position.x + 1, box.end.x - 1):
				terrain_layer.set_cell_item(x, box.end.y, box.position.z, roof_straight_tile, 0)
		return []
	
	var raised_sections = []
	# draw corners - TODO: currently very specific code, may be able to generify:
	terrain_layer.set_cell_item(box.position.x, box.end.y, box.position.z, roof_corner_tile, 16)
	terrain_layer.set_cell_item(box.end.x - 1, box.end.y, box.position.z, roof_corner_tile, 0)
	terrain_layer.set_cell_item(box.position.x, box.end.y, box.end.z - 1, roof_corner_tile, 10)
	terrain_layer.set_cell_item(box.end.x - 1, box.end.y, box.end.z - 1, roof_corner_tile, 22)
	
	# If x or z are greater than 2 then:
	# we need to insert the slant pieces
	if box.size.x > 2:
		for x in range (box.position.x + 1, box.end.x - 1):
			terrain_layer.set_cell_item(x, box.end.y, box.position.z, roof_slant_tile, 16)
			terrain_layer.set_cell_item(x, box.end.y, box.end.z - 1, roof_slant_tile, 22)
	
	if box.size.z > 2:
		for z in range(box.position.z + 1, box.end.z - 1):
			terrain_layer.set_cell_item(box.position.x, box.end.y, z, roof_slant_tile, 10)
			terrain_layer.set_cell_item(box.end.x - 1, box.end.y, z, roof_slant_tile, 0)
	
	# If x and y are both greater than 2, then:
	# we need another higher roof box to build roof pieces on
	if box.size.x > 2 and box.size.z > 2:
		raised_sections.append(AABB(Vector3(box.position.x + 1, box.end.y, box.position.z + 1), Vector3(box.size.x - 2, 1, box.size.z - 2)))
	
	return raised_sections

func draw_wall_scaffolds(boxes):
	for box in boxes:
		draw_wall_scaffold(box)

func draw_wall_scaffold(box):
	# Draw each external wall indiviually
	draw_north_wall(box)
	draw_west_wall(box)
	draw_south_wall(box)
	draw_east_wall(box)

func draw_north_wall(box):
	# The -Z facing wall
	var box_z = box.position.z
	for y in range(box.position.y, box.end.y):
		for box_x in range(box.position.x, box.end.x):
			var x = box_x * 2
			var z = box_z * 2 - 1
			wall_layer.set_cell_item(x, y, z, wall_scaffold_tile, 16)
	
func draw_west_wall(box):
	# The -X facing wall
	var box_x = box.position.x
	for y in range(box.position.y, box.end.y):
		for box_z in range(box.position.z, box.end.z):
			var x = box_x * 2 - 1
			var z = box_z * 2
			wall_layer.set_cell_item(x, y, z, wall_scaffold_tile, 10)

func draw_south_wall(box):
	# The +Z facing wall
	var box_z = box.end.z
	for y in range(box.position.y, box.end.y):
		for box_x in range(box.position.x, box.end.x):
			var x = box_x * 2
			var z = box_z * 2 - 1
			wall_layer.set_cell_item(x, y, z, wall_scaffold_tile, 22)
	
func draw_east_wall(box):
	# The +X facing wall
	var box_x = box.end.x
	for y in range(box.position.y, box.end.y):
		for box_z in range(box.position.z, box.end.z):
			var x = box_x * 2 - 1
			var z = box_z * 2
			wall_layer.set_cell_item(x, y, z, wall_scaffold_tile, 0)