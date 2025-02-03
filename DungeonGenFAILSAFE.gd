class_name DungeonGenFAILSAFE

extends Node
var sizeY = 20
var sizeX = 20

var tileMap: TileMapLayer

func _init(tileMapL: TileMapLayer) -> void:
    tileMap = tileMapL
    tileMap.clear()

    for y in sizeY:
        for x in sizeX:
            tileMap.set_cell(Vector2i(x, y), 0, Vector2i(2, 0))
    
    initialiseGrid()

func initialiseGrid() -> void:
    for y in sizeY:
        for x in sizeX:
            if y == 0 || y == sizeY - 1 || x == 0 || x == sizeX - 1:
                tileMap.set_cell(Vector2i(x, y), 0, Vector2i(4, 0))
            elif y == 1 || y == sizeY - 2 || x == 1 || x == sizeX - 2:
                tileMap.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
