/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file strings.nut Class containing string related functions for WormAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2016.
 *
 */ 

/**
 * Define the WormStrings class containing string related functions.
 */
class WormStrings
{
	/**
	 * Convert a number to its hexadecimal string representation.
	 * @param number The number to convert.
	 * @return The hexadecimal string.
	 * @note Since the Squirrel string library is not enabled we needed to define our own function.
	 * Source: http://forum.iv-multiplayer.com/index.php?topic=914.60
	 */
	static function DecToHex(number);

	/**
	 * Writes a tile as a hexadecimal number.
	 * @param tile The tile to convert.
	 * @return The hexadecimal string.
	 */
	function WriteTile(tile);

	/**
	 * Rough year/month age estimation string where year = 365 days and month = 30 days.
	 * @param AgeInDays The age in days.
	 * @return Text string saying how many years and months.
	 */
	function GetAgeString(AgeInDays);

	/**
	 * Returns aircraft type as text.
	 * @param airplane_id The id of the airplane
	 * @return The airplane type as a text string
	 */
	function GetAircraftTypeAsText(airplane_id);

}

function WormStrings::DecToHex(number)
{
	local hexChars = "0123456789ABCDEF";
	local ret = "";
	local quotient = number;
	do
	{
		local remainder = quotient % 16;
		quotient /= 16;
		ret = hexChars[(remainder < 0) ? -remainder : remainder].tochar()+ret;
	}
	while(quotient != 0);
	if(number < 0) return "-"+ret;
	return ret;
}

function WormStrings::WriteTile(tile)
{
	return "0x" + WormStrings.DecToHex(tile);
}

function WormStrings::GetAgeString(AgeInDays)
{
	local y = AgeInDays / 365;
	local days = AgeInDays - (y * 365);
	local m = days / 30;
	return y + " years " + m + " months";
}

function WormStrings::GetAircraftTypeAsText(airplane_id)
{
	// Get the aircraft type (mainly large/small)
	local planetype = "";
	switch(AIEngine.GetPlaneType(airplane_id)) {
		case AIAirport.PT_BIG_PLANE: {planetype = "Large airplane";} break;
		case AIAirport.PT_SMALL_PLANE: {planetype = "Small airplane";} break;
		case AIAirport.PT_HELICOPTER: {planetype = "Helicopter";} break;
		default: {planetype = "<invalid aircraft type>";} break;
	}
	return planetype;
}
