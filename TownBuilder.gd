extends Spatial

export(Vector2)  var base_extends = Vector2()
export(int)      var town_seed    = 0

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
	
	base()
	var squares = subdivide(Rect2(-base_extends.x, -base_extends.y, 2 * base_extends.x, 2 * base_extends.y), true)
	var boxes = make_3d_boxes(squares)
	draw_scaffolds(squares, boxes)
	

func base():
	for z in range(-base_extends.y, base_extends.y):
		for x in range(-base_extends.x, base_extends.x):
			terrain_layer.set_cell_item(x, 0, z, base_tile)


func subdivide(square, main_road):
	var squares = []
	
	# If main road division, make the road go from a wall to the center, 2 wide
	# Then split up the rest of the square into 3 squares
	if (main_road):
		var centre = (square.end + square.position) / 2
		var road_square = Rect2(centre.x - 1, centre.y - 1, (square.size.x / 2) + 1, 2)
		draw_ground_level_tile_square(road_square, road_tile)
		squares += subdivide(Rect2(square.position.x, square.position.y, (square.size.x / 2) - 1, square.size.y          ), false)
		squares += subdivide(Rect2(centre.x - 1,   square.position.y, (square.size.x / 2) + 1, (square.size.y / 2) - 1), false)
		squares += subdivide(Rect2(centre.x - 1,   centre.y + 1,   (square.size.x / 2) + 1, (square.size.y / 2) - 1), false)
	else:
		# Try cutting on the longest side first, then the shorter side
		if (square.size.x > square.size.y):
			var squares_x = subdivide_by_x(square)
			if squares_x.size() > 1:
				squares += squares_x
			else: 
				squares += subdivide_by_y(square)
		else:
			var squares_y = subdivide_by_y(square)
			if squares_y.size() > 1:
				squares += squares_y
			else:
				squares += subdivide_by_x(square)
	
	return squares

func subdivide_by_x(square):
	# Is there enough space to split it?
	if square.size.x < 7:
		# TODO: allow edge roads for blocks smaller that 7?
		return [square]
	# Do any valid splits have a road at the end?
	var splits = range(square.position.x + 3, square.end.x - 3)
	var road_splits = []
	for split in splits:
		var term_1 = terrain_layer.get_cell_item(split, 0, square.position.y - 1)
		var term_2 = terrain_layer.get_cell_item(split, 0, square.end.y)
		# Add path twice if paved at both ends
		if (term_1 == road_tile):
			road_splits.append(split)
		if (term_2 == road_tile):
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
	if square.size.y < 7:
		# TODO: allow edge roads for blocks smaller that 7?
		return [square]
	# Do any valid splits have a road at the end?
	var splits = range(square.position.y + 3, square.end.y - 3)
	var road_splits = []
	for split in splits:
		var term_1 = terrain_layer.get_cell_item(square.position.x - 1, 0, split)
		var term_2 = terrain_layer.get_cell_item(square.end.x,      0, split)
		# Add path twice if paved at both ends
		if (term_1 == road_tile):
			road_splits.append(split)
		if (term_2 == road_tile):
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
		var height = randi() % 3 + 2
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
	

	
