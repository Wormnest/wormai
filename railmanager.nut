/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file railmanager.nut Class containing the Rail Manager for WormAI.
 * Based on code from SimpleAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2016.
 *
 */ 

/**
 * Define the WormRailManager class which handles trains.
 */
class WormRailManager
{
	/* Variables used by WormRailManager */
	/* 1. Variables that will be saved in a savegame. */
	
	/* 2. Variables that will NOT be saved. */
	_current_railtype = 0;							///< The railtype we are currently using.

	/** Create an instance of WormRailManager and initialize our variables. */
	constructor()
	{
		_current_railtype = AIRail.RAILTYPE_INVALID;
		AILog.Info("[RailManager initialized]");
	}
	
	/**
	 * Updates the current rail type of the AI based on the maximum number of cargoes transportable.
	 */
	function UpdateRailType();

	/**
	 * Sets the current rail type of the AI based on the maximum number of cargoes transportable.
	 * @return The new railtype that has been set.
	 * @todo Possible better evaluation what rail type is the most profitable.
	 */
	static function SetRailType();

}

function WormRailManager::UpdateRailType()
{
	local new_railtype = WormRailManager.SetRailType();
	if (new_railtype != _current_railtype) {
		_current_railtype = new_railtype;
		AILog.Warning("Changed rail type we use to " + AIRail.GetName(_current_railtype));
	}
}

function WormRailManager::SetRailType()
{
	local railtypes = AIRailTypeList();
	local cargoes = AICargoList();
	local max_cargoes = 0;
	local current_railtype = AIRail.RAILTYPE_INVALID;
	// Check each rail type for the number of available cargoes
	foreach (railtype, dummy in railtypes) {
		// Avoid the universal rail in NUTS and other similar ones
		local buildcost = AIRail.GetBuildCost(railtype, AIRail.BT_TRACK);
		if (buildcost > WormMoney.InflationCorrection(2000)) continue;
		current_railtype = AIRail.GetCurrentRailType();
		AIRail.SetCurrentRailType(railtype);
		local num_cargoes = 0;
		// Count the number of available cargoes
		foreach (cargo, dummy2 in cargoes) {
			if (WormRailBuilder.ChooseWagon(cargo, null) != null) num_cargoes++;
		}
		if (num_cargoes > max_cargoes) {
			max_cargoes = num_cargoes;
			current_railtype = railtype;
		}
		AIRail.SetCurrentRailType(current_railtype);
	}
	return current_railtype;
}

