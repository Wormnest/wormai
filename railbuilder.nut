/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file railbuilder.nut Class containing the Rail Builder for WormAI.
 * Based on code from SimpleAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2016.
 *
 */ 

/**
 * Define the WormRailBuilder class which handles trains.
 */
class WormRailBuilder
{

	/**
	 * Choose a rail wagon for the given cargo.
	 * @param cargo The cargo which will be transported by te wagon.
	 * @return The EngineID of the chosen wagon, null if no suitable wagon was found.
	 */
	static function ChooseWagon(cargo, blacklist);

}

function WormRailBuilder::ChooseWagon(cargo, blacklist)
{
	local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
	wagonlist.Valuate(AIEngine.CanRunOnRail, AIRail.GetCurrentRailType());
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.IsWagon);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.CanRefitCargo, cargo);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.IsArticulated);
	// Only remove articulated wagons if there are non-articulated ones left
	local only_articulated = true;
	foreach (wagon, articulated in wagonlist) {
		if (articulated == 0) {
			only_articulated = false;
			break;
		}
	}
	if (!only_articulated) {
		wagonlist.KeepValue(0);
	}
	if (blacklist != null) {
		wagonlist.Valuate(SimpleAI.ListContainsValuator, blacklist);
		wagonlist.KeepValue(0);
	}
	wagonlist.Valuate(AIEngine.GetCapacity);
	if (wagonlist.Count() == 0) return null;
	return wagonlist.Begin();
}
