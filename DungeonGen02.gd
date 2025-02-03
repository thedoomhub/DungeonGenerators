class_name DungeonGen02 

extends Node

"""
Dungeon Generation with corridor overlap allowed and uses the entire space of the dungeon. Does not allow dead ends. Corridors do not loop back to first room.
"""

#Constants
const WALL: Vector2i = Vector2i(1, 0)
const FLOOR: Vector2i = Vector2i(2, 0)
const CORRIDOR: Vector2i = Vector2i(3, 0)
const BORDER: Vector2i = Vector2i(4, 0)
const PLAYER_SPAWN = Vector2i(5, 0)
const EXIT: Vector2i = Vector2i(6, 0)
const ROOM_EXIT: Vector2i = Vector2i(7, 0)

var random: RandomNumberGenerator = RandomNumberGenerator.new()

var tileMap: TileMapLayer

var sizeX: int
var sizeY: int
var useableArea: Rect2i
var maxSizeX: int
var maxSizeY: int
var rooms: Array[Rect2i]
var oneByOneRooms: Array[Rect2i]
var dungeonName: String
var adjacentWalls: Dictionary
var corridors: Array[Vector2i]
var roomNum: int

var astar = AStarGrid2D.new()
var pathfindingAstar = AStarGrid2D.new()
var visited = {}
var corners = []

var curAttempt = 0
const MAXIMUM_ATTEMPTS = 10

var playerSpawn: Vector2
var exit: Vector2

func _init(tiles: TileMapLayer, size: Vector2i, maxSize: Vector2i, numberOfRooms: int, dName: String = "") -> void:
	tileMap = tiles
	sizeX = size.x
	sizeY = size.y
	maxSizeX = maxSize.x
	maxSizeY = maxSize.y
	dungeonName = dName
	roomNum = numberOfRooms

	useableArea = Rect2i(0, 0, sizeX - 2, sizeY - 2)
	tileMap.clear()

	randomize()

func generateDungeon() -> bool:
	for y in sizeY:
		for x in sizeX:
			tileMap.set_cell(Vector2i(x, y), 0, WALL)

	initialiseAstar()
	initialiseGrid()

	for i in range(roomNum):
		generateRooms(roomNum)
	
	generateCorridors()
	markRoomExits()

	playerSpawn = setPlayerSpawn()
	exit = setPlayerSpawn()

	tileMap.set_cell(tileMap.local_to_map(playerSpawn), 0, PLAYER_SPAWN)
	tileMap.set_cell(tileMap.local_to_map(exit), 0 , EXIT)

	initPathFinding()

	check()

	return true

func initialiseAstar() -> void:
	astar.set_diagonal_mode(astar.DIAGONAL_MODE_NEVER)
	astar.set_default_estimate_heuristic(astar.HEURISTIC_MANHATTAN)
	astar.set_region(Rect2i(0, 0, sizeX, sizeY))

	astar.update()

func initialiseGrid() -> void:
	for y in sizeY:
		for x in sizeX:
			if y == 0 || y == sizeY - 1 || x == 0 || x == sizeX - 1:
				tileMap.set_cell(Vector2i(x, y), 0, BORDER)

func initPathFinding() -> void:
	pathfindingAstar.set_region(Rect2i(0, 0, sizeX, sizeY))

	pathfindingAstar.set_diagonal_mode(astar.DIAGONAL_MODE_NEVER)
	pathfindingAstar.set_default_estimate_heuristic(astar.HEURISTIC_MANHATTAN)

	pathfindingAstar.update()
	

	for y in range(sizeY):
		for x in range(sizeX):
			if tileMap.get_cell_atlas_coords(Vector2i(x, y)) in [WALL, BORDER]:
				pathfindingAstar.set_point_solid(Vector2i(x, y))

func generateRooms(num: int) -> void:
	var attempt = 0
	var MAX_ATTEMPTS = num * 100

	var room = generateRoom()

	for r in rooms:
		var modifiedR = r.grow_individual(4, 4, 4, 4)
		var overlaps = room.position.x <= modifiedR.position.x + modifiedR.size.x && \
		room.size.x + room.position.x >= modifiedR.position.x && \
		room.position.y <= modifiedR.size.y + modifiedR.position.y && \
		room.size.y + room.position.y >= modifiedR.position.y
		
		while room.intersects(modifiedR) || overlaps:
			attempt += 1

			room = generateRoom()

			if attempt == MAX_ATTEMPTS:
				print("Unable to create room.")
				return
	
	attempt = 0

	rooms.append(room)

	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			tileMap.set_cell(Vector2i(x, y), 0, FLOOR)

func generateRoom() -> Rect2i:
	var roomPos = Vector2i(random.randi_range(2, useableArea.size.x), random.randi_range(2, useableArea.size.y))
	var roomSize = Vector2i(random.randi_range(2, maxSizeX), random.randi_range(2, maxSizeY))

	while roomPos.x + roomSize.x > useableArea.size.x - 2 || roomPos.y + roomSize.y > useableArea.size.y - 2:
		roomPos = Vector2i(random.randi_range(2, useableArea.size.x), random.randi_range(2, useableArea.size.y))
		roomSize = Vector2i(random.randi_range(2, maxSizeX), random.randi_range(2, maxSizeY))

	return Rect2i(roomPos, roomSize)

func setPlayerSpawn() -> Vector2:

	var validTiles = []

	for x in tileMap.get_used_rect().size.x:
		for y in tileMap.get_used_rect().size.y:
			var tilePos: Vector2i = Vector2i(
				x + tileMap.get_used_rect().position.x, 
				y + tileMap.get_used_rect().position.y
				)

			var tileData = tileMap.get_cell_tile_data(tilePos)

			if tileData == null:
				assert(false, "Tile data is null.")

			if tileData.get_custom_data("Type") == "Floor":
				validTiles.append(tilePos)

	var player := tileMap.map_to_local(validTiles[random.randi_range(0, len(validTiles) - 1)]) if !(validTiles.is_empty()) else tileMap.map_to_local(Vector2i.ZERO)

	return player

func generateCorridors() -> void:
	rooms.sort()
	getAdjacentWalls()

	for i in range(len(rooms) - 1):

		var room1 = rooms[i]

		var room2 = rooms[(i + 1) % rooms.size()]

		var wall1: Vector2i = adjacentWalls[room1].pick_random()
		var wall2: Vector2i = adjacentWalls[room2].pick_random()

		print("First: ", wall1, " Second: ", wall2)

		astar.set_point_solid(wall1, false)
		astar.set_point_solid(wall2, false)

		var idPath = astar.get_id_path(
			wall1,
			wall2
		)

		if !idPath.is_empty():
			for point in idPath:
				if tileMap.get_cell_atlas_coords(point) != FLOOR: 
					tileMap.set_cell(point, 0, CORRIDOR)
					corridors.append(point)
					astar.set_point_weight_scale(point, 3)

					astar.set_point_weight_scale(point + Vector2i.DOWN, 3)
					astar.set_point_weight_scale(point + Vector2i.UP, 3)
					astar.set_point_weight_scale(point + Vector2i.RIGHT, 3)
					astar.set_point_weight_scale(point + Vector2i.LEFT, 3)

					astar.set_point_weight_scale(point + Vector2i.DOWN + Vector2i.RIGHT, 3)
					astar.set_point_weight_scale(point + Vector2i.UP + Vector2i.LEFT, 3)
					astar.set_point_weight_scale(point + Vector2i.RIGHT + Vector2i.UP, 3)
					astar.set_point_weight_scale(point + Vector2i.LEFT + Vector2i.DOWN, 3)

		astar.set_point_solid(wall1, true)
		astar.set_point_solid(wall2, true)

		if adjacentWalls[room1].has(wall1 + Vector2i.UP):
			adjacentWalls[room1].erase(wall1 + Vector2i.UP)

		elif adjacentWalls[room1].has(wall1 + Vector2i.DOWN):
			adjacentWalls[room1].erase(wall1 + Vector2i.DOWN)

		elif adjacentWalls[room1].has(wall1 + Vector2i.RIGHT):
			adjacentWalls[room1].erase(wall1 + Vector2i.RIGHT)

		elif adjacentWalls[room1].has(wall1 + Vector2i.LEFT):
			adjacentWalls[room1].erase(wall1 + Vector2i.LEFT)

		if adjacentWalls[room2].has(wall2 + Vector2i.UP):
			adjacentWalls[room2].erase(wall2 + Vector2i.UP)

		elif adjacentWalls[room2].has(wall2 + Vector2i.DOWN):
			adjacentWalls[room2].erase(wall2 + Vector2i.DOWN)

		elif adjacentWalls[room2].has(wall2 + Vector2i.RIGHT):
			adjacentWalls[room2].erase(wall2 + Vector2i.RIGHT)

		elif adjacentWalls[room2].has(wall2 + Vector2i.LEFT):
			adjacentWalls[room2].erase(wall2 + Vector2i.LEFT)

func markRoomExits() -> void:
	var tileSet: TileSet = tileMap.get_tile_set()

	for corridor in corridors:
			if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(corridor, tileSet.CELL_NEIGHBOR_BOTTOM_SIDE)) == FLOOR:
				tileMap.set_cell(corridor + Vector2i.DOWN, 0, ROOM_EXIT)
			elif tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(corridor, tileSet.CELL_NEIGHBOR_TOP_SIDE)) == FLOOR:
				tileMap.set_cell(corridor + Vector2i.UP, 0, ROOM_EXIT)
			elif tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(corridor, tileSet.CELL_NEIGHBOR_RIGHT_SIDE)) == FLOOR:
				tileMap.set_cell(corridor + Vector2i.RIGHT, 0, ROOM_EXIT)
			elif tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(corridor, tileSet.CELL_NEIGHBOR_LEFT_SIDE)) == FLOOR:
				tileMap.set_cell(corridor + Vector2i.LEFT, 0, ROOM_EXIT)

func getAdjacentWalls() -> void:
	var walls = []


	for r in rooms:
		for y in range(r.position.y, r.position.y + r.size.y):
			for x in range(r.position.x, r.position.x + r.size.x):
				var cell: Vector2i = Vector2i(x, y)
				var tileSet: TileSet = tileMap.get_tile_set()

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_LEFT_SIDE)) == WALL:
					walls.append(Vector2i(x - 1, y))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_RIGHT_SIDE)) == WALL:
					walls.append(Vector2i(x + 1, y))
				
				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_TOP_SIDE)) == WALL:
					walls.append(Vector2i(x, y - 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_BOTTOM_SIDE)) == WALL:
					walls.append(Vector2i(x, y + 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER)) == WALL:
					corners.append(Vector2i(x - 1, y - 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER)) == WALL:
					corners.append(Vector2i(x + 1, y + 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER)) == WALL:
					corners.append(Vector2i(x - 1, y + 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER)) == WALL:
					corners.append(Vector2i(x + 1, y - 1))

		adjacentWalls[r] = walls

		walls = []

	setSolidPoints()

	print(adjacentWalls)

func setSolidPoints() -> void:
	for wall in adjacentWalls:
		for w in adjacentWalls[wall]:
			astar.set_point_solid(w, true)
			astar.update()

	for r in rooms:
		for y in range(r.position.y, r.position.y + r.size.y):
			for x in range(r.position.x, r.position.x + r.size.x):
				astar.set_point_solid(Vector2i(x, y))
				astar.update()

	for corner in corners:
		astar.set_point_solid(corner, true)
		astar.update()

	for y in sizeY:
		for x in sizeX:
			if y == 0 || y == sizeY - 1 || x == 0 || x == sizeX - 1:
				astar.set_point_solid(Vector2i(x, y))
				astar.update()

func growSides(rect: Rect2i, amount: int) -> Rect2i:
	return rect.grow_side(SIDE_LEFT, amount)\
	.grow_side(SIDE_RIGHT, amount).\
	grow_side(SIDE_TOP, amount).\
	grow_side(SIDE_BOTTOM,  amount)

func shrinkSides(rect: Rect2i, amount: int) -> Rect2i:
	return rect.grow_side(SIDE_LEFT, -amount)\
	.grow_side(SIDE_RIGHT, -amount).\
	grow_side(SIDE_TOP, -amount).\
	grow_side(SIDE_BOTTOM, -amount)

func distance(x1: int, y1: int, x2: int, y2: int) -> int:
	return round(sqrt(abs(x2 - x1) + abs(y2 - y1)))

func findPath() -> bool:
	var start = tileMap.local_to_map(playerSpawn)
	var end = tileMap.local_to_map(exit)

	var path = pathfindingAstar.get_id_path(start, end)

	return !(path.is_empty())

func check() -> void:
	var connectedRooms = 0

	for adjacentWall in adjacentWalls:
		for wall in adjacentWalls[adjacentWall]:
			if tileMap.get_cell_atlas_coords(wall) == CORRIDOR:
				connectedRooms += 1
				break

	if connectedRooms == len(rooms) && findPath():
		return

	print("Failed")

	curAttempt += 1

	if curAttempt == MAXIMUM_ATTEMPTS:
		DungeonGenFAILSAFE.new(tileMap)

	randomize()

	for y in sizeY:
		for x in sizeX:
			tileMap.set_cell(Vector2i(x, y), 0, WALL)

	initialiseAstar()
	initialiseGrid()

	for i in range(roomNum):
		generateRooms(roomNum)

	generateCorridors()
	markRoomExits()

	playerSpawn = setPlayerSpawn()
	exit = setPlayerSpawn()

	tileMap.set_cell(tileMap.local_to_map(playerSpawn), 0, PLAYER_SPAWN)
	tileMap.set_cell(tileMap.local_to_map(exit), 0 , EXIT)

	initPathFinding()

	check()

func getPlayerSpawn() -> Vector2:
	return playerSpawn
