class_name DungeonGen01

"""
Dungeon Generation with corridor overlap allowed and uses the entire space of the dungeon. Allows dead ends. Corridors loop back to first room. Does not allow the same side of a room to be used again. Generates rectangular rooms.
"""


extends Node2D

#Constants
const WALL: Vector2i = Vector2i(1, 0)
const FLOOR: Vector2i = Vector2i(2, 0)
const CORRIDOR: Vector2i = Vector2i(3, 0)
const BORDER: Vector2i = Vector2i(4, 0)
const PLAYER_SPAWN: Vector2i = Vector2i(5, 0)
const EXIT: Vector2i = Vector2i(6, 0)
const ROOM_EXIT: Vector2i = Vector2i(7, 0)

#Variables
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
var corridors: Dictionary
var roomNum: int

var astar: AStarGrid2D = AStarGrid2D.new()
var pathfindingAstar: AStarGrid2D = AStarGrid2D.new()
var visited = {}
var corners = []
var nonEditedRooms
var playerSpawn: Vector2
var exit: Vector2

var curAttempt = 0
const MAXIMUM_ATTEMPTS = 20

#Functions
func _init(tiles: TileMapLayer, size: Vector2i, maxSize: Vector2i, numberOfRooms: int, dName: String = "") -> void:
	tileMap = tiles
	sizeX = size.x
	sizeY = size.y
	maxSizeX = maxSize.x
	maxSizeY = maxSize.y
	dungeonName = dName
	roomNum = numberOfRooms

	tileMap.clear()

	useableArea = Rect2i(0, 0, sizeX - 2, sizeY - 2)

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

func initPathFinding() -> void:
	pathfindingAstar.set_region(Rect2i(0, 0, sizeX, sizeY))

	pathfindingAstar.set_diagonal_mode(astar.DIAGONAL_MODE_NEVER)
	pathfindingAstar.set_default_estimate_heuristic(astar.HEURISTIC_MANHATTAN)

	pathfindingAstar.update()
	

	for y in range(sizeY):
		for x in range(sizeX):
			if tileMap.get_cell_atlas_coords(Vector2i(x, y)) in [WALL, BORDER]:
				pathfindingAstar.set_point_solid(Vector2i(x, y))

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

func initialiseGrid() -> void:
	for y in sizeY:
		for x in sizeX:
			if y == 0 || y == sizeY - 1 || x == 0 || x == sizeX - 1:
				tileMap.set_cell(Vector2i(x, y), 0, BORDER)

func generateRooms(num: int) -> void:
	var attempt = 0
	var MAX_ATTEMPTS = num * 10000
	const DEAD_ZONE = 3

	var room = generateRoom()

	if room.size.x == 1 || room.size.y == 1:
		room.size = Vector2i(1, 1)

	for r in rooms:
		var modifiedR = r.grow_individual(DEAD_ZONE, DEAD_ZONE, DEAD_ZONE, DEAD_ZONE)

		var overlaps = room.position.x <= modifiedR.position.x + modifiedR.size.x && \
		room.size.x + room.position.x >= modifiedR.position.x && \
		room.position.y <= modifiedR.size.y + modifiedR.position.y && \
		room.size.y + room.position.y >= modifiedR.position.y
		
		while room.intersects(modifiedR) || oneByOneRooms.size() == num - 2 || overlaps:
			attempt += 1

			room = generateRoom()

			if room.size.x == 1 || room.size.y == 1:
				room.size = Vector2i(1, 1)

			if attempt == MAX_ATTEMPTS:
				print("Unable to create room.")
				return
	
	attempt = 0

	rooms.append(room)
	
	if room.size == Vector2i(1, 1):
		oneByOneRooms.append(room)

	if room.size != Vector2i(1, 1):
		for y in range(room.position.y, room.position.y + room.size.y):
			for x in range(room.position.x, room.position.x + room.size.x):
				tileMap.set_cell(Vector2i(x, y), 0, FLOOR)
	else:
		tileMap.set_cell(room.position, 0, CORRIDOR)

func generateRoom() -> Rect2i:
	var roomPos = Vector2i(random.randi_range(2, useableArea.size.x), random.randi_range(2, useableArea.size.y))
	var roomSize = Vector2i(random.randi_range(1, maxSizeX), random.randi_range(1, maxSizeY))

	while roomPos.x + roomSize.x > useableArea.size.x - 2 || roomPos.y + roomSize.y > useableArea.size.y - 2:
		roomPos = Vector2i(random.randi_range(2, useableArea.size.x), random.randi_range(2, useableArea.size.y))
		roomSize = Vector2i(random.randi_range(1, maxSizeX), random.randi_range(1, maxSizeY))

	return Rect2i(roomPos, roomSize)

func generateCorridors() -> void:
	rooms.sort()
	getAdjacentWalls()

	for i in range(len(rooms) - 1):
		var wall1
		var wall2

		var room1 = rooms[i % rooms.size()]

		var room2 = rooms[(i + 1) % rooms.size()]

		var key1 = adjacentWalls[room1].keys().pick_random()
		wall1 = adjacentWalls[room1][key1].pick_random()

		var key2 = adjacentWalls[room2].keys().pick_random()
		wall2 = adjacentWalls[room2][key2].pick_random()

		adjacentWalls[room1].erase(key1)
		adjacentWalls[room2].erase(key2)

		astar.set_point_solid(wall1, false)
		astar.set_point_solid(wall2, false)

		var idPath: Array[Vector2i] = astar.get_id_path(
			wall1,
			wall2
		)

		corridors[str(room1) + " -> " + str(room2)] = []

		if !idPath.is_empty():
			for point in idPath:
				if tileMap.get_cell_atlas_coords(point) != FLOOR: 
					tileMap.set_cell(point, 0, CORRIDOR)
					corridors[str(room1) + " -> " + str(room2)].append(point)
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

func getAdjacentWalls() -> void:

	for r in rooms:
		adjacentWalls[r] = {"Left": [], "Right": [], "Top": [], "Bottom": []}
		if r.size == Vector2i(1, 1):
			adjacentWalls[r] = {"Left": [], "Right": [], "Top": [], "Bottom": []}
			
			for direction in adjacentWalls[r]:
				adjacentWalls[r][direction] = [r.position]
				
			continue

		for y in range(r.position.y, r.position.y + r.size.y):
			for x in range(r.position.x, r.position.x + r.size.x):
				var cell: Vector2i = Vector2i(x, y)
				var tileSet: TileSet = tileMap.get_tile_set()

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_LEFT_SIDE)) == WALL:
					adjacentWalls[r]["Left"].append(Vector2i(x - 1, y))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_RIGHT_SIDE)) == WALL:
					adjacentWalls[r]["Right"].append(Vector2i(x + 1, y))
				
				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_TOP_SIDE)) == WALL:
					adjacentWalls[r]["Top"].append(Vector2i(x, y - 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_BOTTOM_SIDE)) == WALL:
					adjacentWalls[r]["Bottom"].append(Vector2i(x, y + 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER)) == WALL:
					corners.append(Vector2i(x - 1, y - 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER)) == WALL:
					corners.append(Vector2i(x + 1, y + 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER)) == WALL:
					corners.append(Vector2i(x - 1, y + 1))

				if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(cell, tileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER)) == WALL:
					corners.append(Vector2i(x + 1, y - 1))

	setSolidPoints()

func markRoomExits() -> void:
	var tileSet: TileSet = tileMap.get_tile_set()

	for key in corridors.keys():
		for corridor in corridors[key]:
			if tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(corridor, tileSet.CELL_NEIGHBOR_BOTTOM_SIDE)) == FLOOR:
				tileMap.set_cell(corridor + Vector2i.DOWN, 0, ROOM_EXIT)
			elif tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(corridor, tileSet.CELL_NEIGHBOR_TOP_SIDE)) == FLOOR:
				tileMap.set_cell(corridor + Vector2i.UP, 0, ROOM_EXIT)
			elif tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(corridor, tileSet.CELL_NEIGHBOR_RIGHT_SIDE)) == FLOOR:
				tileMap.set_cell(corridor + Vector2i.RIGHT, 0, ROOM_EXIT)
			elif tileMap.get_cell_atlas_coords(tileMap.get_neighbor_cell(corridor, tileSet.CELL_NEIGHBOR_LEFT_SIDE)) == FLOOR:
				tileMap.set_cell(corridor + Vector2i.LEFT, 0, ROOM_EXIT)

func setSolidPoints() -> void:
	for r in adjacentWalls:
		if r.size == Vector2i(1, 1):
			continue
		else:
			for direction in adjacentWalls[r]:
				for wall in adjacentWalls[r][direction]:
					astar.set_point_solid(wall, true)
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

func findPath() -> bool:
	var start = tileMap.local_to_map(playerSpawn)
	var end = tileMap.local_to_map(exit)

	var path = pathfindingAstar.get_id_path(start, end)

	return !(path.is_empty())

func check() -> void:
	var connectedRooms = 0

	for i in range(len(rooms) - 1):
		var room1 = rooms[i]
		var room2 = rooms[(i + 1) % len(rooms)]

		if !(corridors.get(str(room1) + " -> " + str(room2), []).is_empty()):
			connectedRooms += 1

	for i in range(len(rooms) - 1, -1, -1):
		if rooms[i].size == Vector2i(1, 1):
			rooms.remove_at(i)

	print(rooms)

	if connectedRooms >= len(rooms) && !(rooms.is_empty()) && findPath():
		return

	print("Failed")

	if curAttempt >= MAXIMUM_ATTEMPTS:
		DungeonGenFAILSAFE.new(tileMap)
		return

	curAttempt += 1

	randomize()

	tileMap.clear()
	rooms.clear()
	corridors.clear()
	adjacentWalls.clear()
	oneByOneRooms.clear()

	for y in sizeY:
		for x in sizeX:
			tileMap.set_cell(Vector2i(x, y), 0, WALL)

	initialiseAstar()
	initialiseGrid()

	for i in range(roomNum):
		generateRooms(roomNum)

	generateCorridors()

	playerSpawn = setPlayerSpawn()
	exit = setPlayerSpawn()

	tileMap.set_cell(tileMap.local_to_map(playerSpawn), 0, PLAYER_SPAWN)
	tileMap.set_cell(tileMap.local_to_map(exit), 0 , EXIT)


	initPathFinding()

	check()

func getPlayerSpawn() -> Vector2:
	return playerSpawn
