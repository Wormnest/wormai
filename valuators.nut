/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file valuators.nut Class with generic valuators for WormAI.
 * Based partially on code from SimpleAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2016.
 *
 */ 

/**
 * Define the WormValuators class which holds the static valuator functions.
 */
class WormValuators
{
	/**
	 * Valuator function that returns 1 for items present in the supplied list, otherwise 0.
	 * @param item The item to be compared.
	 * @param list The list in which to search for the item.
	 */
	static function ListContainsValuator(item, list);
}

function WormValuators::ListContainsValuator(item, list)
{
	return list.HasItem(item);
}
