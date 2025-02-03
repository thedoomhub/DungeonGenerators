# DungeonGenerators
Dungeon Generators made with GDScript. 

# How To Use
This dungeon generator comes premade with an _init() function, meaning all you need to do is insert the parameters needed, and the rest will be done for you! However, this only works with TileMapLayers that have no special walls. e.g., corners. This script only supports seven tiles: Rooms, Walls, Corridors, Borders, Room Exits, Player Spawns, and Floor Exits, all of which are needed for this to run.

There are two dungeon generators: DungeonGen01 and DungeonGen02. DungeonGen01 does not allow two corridors to be placed on the same wall and generates dead-ends, and DungeonGen02 does not generate dead-ends. 

Also, make sure to put DungeonGenFAILSAFE.gd inside the project as well, as the script will break without it. DungeonGenFAILSAFE is a failsafe in case the dungeon generator cannot generate a valid dungeon after ten attempts. All it does is generate a one-room dungeon. 

# Issues
- Dungeons tend to fail when there are too few rooms. This is likely because the dungeon generator skips rooms that cannot be placed.
