/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file math.nut Class with math related functions for WormAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2016.
 *
 */ 

/**
 * Define the WormMath class which holds the static math functions.
 */
class WormMath
{
	/**
	 * Computes square root of i using Babylonian method.
	 * @param i The integer number to compute the square root of.
	 * @return The highest integer that is lower or equal to the square root of integer i.
	 * @note Taken from Rondje om de kerk
	 */
	static function Sqrt(i);
}

function WormMath::Sqrt(i)
{ 
	assert(i>=0);
	if (i == 0) {
		return 0; // Avoid divide by zero
	}
	local n = (i / 2) + 1; // Initial estimate, never low
	local n1 = (n + (i / n)) / 2;
	while (n1 < n) {
		n = n1;
		n1 = (n + (i / n)) / 2;
	}
	return n;
}
