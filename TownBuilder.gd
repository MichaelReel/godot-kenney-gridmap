extends Spatial

# Configurable parameters
export (Vector2)  var base_extends    = Vector2(10,10)
export (int)      var town_seed       = 0
export (int)      var min_building    = 3
export (int)      var min_height      = 1
export (int)      var max_height      = 3
export (int)      var road_width      = 1
export (int)      var main_road_width = 2

# GridMaps
var terrain_layer
var wall_layer

# Tiles
var base_tile
var road_tile
var scaffold_tile
var floor_tile

func _ready():
	terrain_layer = $TerrainGrid
	wall_layer = $WallMap
	
	base_tile     = terrain_layer.theme.find_item_by_name("Plate_Grass_01")
	road_tile     = terrain_layer.theme.find_item_by_name("Plate_Pavement_01")
	scaffold_tile = terrain_layer.theme.find_item_by_name("Wood_Scaffolding_01")
	floor_tile    = terrain_layer.theme.find_item_by_name("Plate_Wood_01")
	
	rand_seed(town_seed)
	
	var town_base = Rect2(-base_extends.x / 2, -base_extends.y / 2, base_extends.x, base_extends.y)
	draw_ground_level_tile_square(town_base, base_tile)
	var squares = subdivide(town_base, true)
	var boxes = make_3d_boxes(squares)
	draw_scaffolds(squares, boxes)

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
	# Is there enough space to split it?
	if square.size.x < (2 * min_building) + road_width:
		# TODO: allow edge roads for blocks smaller that 7?
		return [square]
	# Do any valid splits have a road at the end?
	var splits = range(square.position.x + min_building, square.end.x - min_building)
	var road_splits = []
	for split in splits:
		var term_1 = terrain_layer.get_cell_item(split, 0, square.position.y - 1)
		var term_2 = terrain_layer.get_cell_item(split, 0, square.end.y)
		# Add path twice if paved at both ends
		if (term_1 == road_tile or term_2 == road_tile):
			road_splits.append(split)
	
	if road_splits.empty():
		return [square]
	
	# Create the path and return the remaining spaces
	var split = road_splits[randi() % road_splits.size()]
	var road_square = Rect2(split, square.position.y, 1, square.size.y)
	draw_ground_level_tile_square(road_square, road_tile)
	var squares = []
	squares += subdivide(Rect2(square.position.x, square.position.y, split - square.position.x, square.size.y), false)
	squares += subdivide(Rect2(split + 1, square.position.y, square.end.x - split - 1, square.size.y), false)
	return squares

func subdivide_by_y(square):
	# Is there enough space to split it?
	if square.size.y < (2 * min_building) + road_width:
		# TODO: allow edge roads for blocks smaller that 7?
		return [square]
	# Do any valid splits have a road at the end?
	var splits = range(square.position.y + min_building, square.end.y - min_building)
	var road_splits = []
	for split in splits:
		var term_1 = terrain_layer.get_cell_item(square.position.x - 1, 0, split)
		var term_2 = terrain_layer.get_cell_item(square.end.x, 0, split)
		# Add path twice if paved at both ends
		if (term_1 == road_tile or term_2 == road_tile):
			road_splits.append(split)
	
	if road_splits.empty():
		return [square]
	
	# Create the path and return the remaining spaces
	var split = road_splits[randi() % road_splits.size()]
	var road_square = Rect2(square.position.x, split, square.size.x, 1)
	draw_ground_level_tile_square(road_square, road_tile)
	var squares = []
	squares += subdivide(Rect2(square.position.x, square.position.y, square.size.x, split - square.position.y), false)
	squares += subdivide(Rect2(square.position.x, split + 1, square.size.x, square.end.y - split - 1), false)
	return squares

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
	

	
