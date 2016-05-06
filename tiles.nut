/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file tiles.nut Class containing tile related functions for WormAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2013-2016.
 *
 */ 

/**
 * Define the WormTiles class containing tile related functions.
 */
class WormTiles
{
	/**
	 * Add a square area to an AITileList containing tiles that are within radius
	 * tiles from the center tile, taking the edges of the map into account.
	 * @note This function was taken from Rondje. Name was changed from SafeAddRectangle to SafeAddSquare.
	 * @param list The AITileList in which the valid tiles will be returned.
	 * @param tile The center tile.
	 * @param radius The radius of tiles.
	 */
	static function SafeAddSquare(list, tile, radius);

	/**
	 * A safe implementation of AITileList.AddRectangle. Only valid tiles are
	 * added to the tile list.
	 * @note Taken from AdmiralAI.
	 * @param tile_list The AITileList to add the tiles to.
	 * @param center_tile The center of the rectangle.
	 * @param x_min The amount of tiles to the north-east, relative to center_tile.
	 * @param y_min The amount of tiles to the north-west, relative to center_tile.
	 * @param x_plus The amount of tiles to the south-west, relative to center_tile.
	 * @param y_plus The amount of tiles to the south-east, relative to center_tile.
	 */
	static function SafeAddRectangle(tile_list, center_tile, x_min, y_min, x_plus, y_plus);

	/**
	 * Get the direction from one tile to another.
	 * @note Taken from SimpleAI.
	 * @param tilefrom The first tile.
	 * @param tileto The second tile
	 * @return The direction from the first tile to the second tile.
	 */
	static function GetDirection(tilefrom, tileto);
}

function WormTiles::SafeAddSquare(list, tile, radius)
{
	local x1 = max(0, AIMap.GetTileX(tile) - radius);
	local y1 = max(0, AIMap.GetTileY(tile) - radius);
	
	local x2 = min(AIMap.GetMapSizeX() - 2, AIMap.GetTileX(tile) + radius);
	local y2 = min(AIMap.GetMapSizeY() - 2, AIMap.GetTileY(tile) + radius);
	
	list.AddRectangle(AIMap.GetTileIndex(x1, y1),AIMap.GetTileIndex(x2, y2)); 
}

function WormTiles::SafeAddRectangle(tile_list, center_tile, x_min, y_min, x_plus, y_plus)
{
	local tile_x = AIMap.GetTileX(center_tile);
	local tile_y = AIMap.GetTileY(center_tile);
	local tile_from = AIMap.GetTileIndex(max(1, tile_x - x_min), max(1, tile_y - y_min));
	local tile_to = AIMap.GetTileIndex(min(AIMap.GetMapSizeX() - 2, tile_x + x_plus), min(AIMap.GetMapSizeY() - 2, tile_y + y_plus));
	tile_list.AddRectangle(tile_from, tile_to);
} 

function WormTiles::GetDirection(tilefrom, tileto)
{
	local distx = AIMap.GetTileX(tileto) - AIMap.GetTileX(tilefrom);
	local disty = AIMap.GetTileY(tileto) - AIMap.GetTileY(tilefrom);
	local ret = 0;
	if (abs(distx) > abs(disty)) {
		ret = 2;
		disty = distx;
	}
	if (disty > 0) {
		ret = ret + 1;
	}
	return ret;
}
