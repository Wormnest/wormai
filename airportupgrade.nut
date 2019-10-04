/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file airportupgrade.nut Class with airport upgrading functions for WormAI split off from airmanager.nut.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2013-2017.
 *
 */ 

class WormAirportToUpgrade
{
	station_id = 0;
	station_tile = 0;
	airport_town = 0;
	airport_closed_date = 0;
	wanted_airport_type = AIAirport.AT_INVALID;
	
	constructor(st_id, st_tile, st_town, new_airport_type)
	{
		station_id = st_id;
		station_tile = st_tile;
		airport_town = st_town;
		wanted_airport_type = new_airport_type;
	}
}

/**
 * Define the WormAirportUpgrade class which handles airport upgrading.
 */
class WormAirportUpgrade
{

	upgrade_list = [];						///< Array of all airports needing an upgrade
	in_progress = [];						///< Array of airports where an upgrade is in progress (waiting for airport to be cleared)
	air_manager = null;						///< WormAirManager class.
	upgrade_idx = 0;
	
	closed_count = 0;
	
	constructor(manager)
	{
		upgrade_list = [];
		in_progress = [];
		air_manager = manager;
		upgrade_idx = 0;
		
		closed_count = 0; // temporary solution
	}
	
	function AddAirportToUpgrade(st_id, st_tile, st_town, new_airport_type);
	
	function Exists(st_id); // Returns true if station already exists in upgrade list.
	
	function GetNext(); // Get next airport to upgrade.
	
	function GetCount(); // Get count of airports in the upgrade queue.
	
	function Remove(st_id); // Remove airport from upgrade queue.
	
	function UpgradeAirports();
}

/**
 * Add airport that needs upgrading to the upgrade_list.
 * @param st_id The airport station id of the airport that should be added to the list.
 * @param st_tile The airport tile of the station.
 * @param st_town The town under which influence the airport falls.
 * @param new_airport_type The type of airport we want to upgrade to.
 * @return false if we failed add the station to the list, or true if we succeeded.
 */
function WormAirportUpgrade::AddAirportToUpgrade(st_id, st_tile, st_town, new_airport_type)
{
	// Don't add airport if it's already in the upgrade queue.
	if (Exists(st_id))
		return false;
	if (air_manager.upgrade_blacklist.HasItem(st_town))
		return false;
	local airport_type = AIAirport.GetAirportType(st_tile);
	if (airport_type == new_airport_type)
		return false;
	if (!AIStation.IsValidStation(st_id))
		return false;
	if (!WormAirport.IsWithinNoiseLimit(st_tile, airport_type, new_airport_type))
		return false; /// @todo add to blacklist
	
	local upgrade_airport = WormAirportToUpgrade(st_id, st_tile, st_town, new_airport_type);
	upgrade_list.append(upgrade_airport);
	return true;
}

/**
 * Returns whether a certain airport id exists in the upgrade_list.
 * @param st_id The airport station id of the airport that should be checked.
 * @return false if it doesn't exist in the list or true if it does.
 */
function WormAirportUpgrade::Exists(st_id)
{
	if (upgrade_list == null)
		return false;
	foreach(idx, airport in upgrade_list) {
		if (airport.station_id == st_id)
			return true;
	}
	return false;
}

/**
 * Get the next airport in upgrade_list.
 * @return id of next airport to be upgraded or null
 */
function WormAirportUpgrade::GetNext()
{
	if ((upgrade_list == null) || (upgrade_list.len() == 0))
		return null;
	if (upgrade_idx >= upgrade_list.len())
		upgrade_idx = 0;
	local return_idx = upgrade_idx;
	upgrade_idx += 1;
	return upgrade_list[return_idx];
}

/**
 * Get the number of airports in the upgrade_list.
 * @return the number of airports or -1 if the upgrade_list is null.
 */
function WormAirportUpgrade::GetCount()
{
	if (upgrade_list == null)
		return -1;
	return upgrade_list.len();
}

/**
 * Remove airport from upgrade_list.
 * @param st_id The airport station id of the airport that should be removed from the list.
 * @return false if we failed to remove the specified airport id.
 */
function WormAirportUpgrade::Remove(st_id)
{
	if (upgrade_list == null)
		return false;
	local remove_idx = -1;
	foreach(idx, airport in upgrade_list) {
		if (airport.station_id == st_id) {
			remove_idx = idx;
			break;
		}
	}
	if (remove_idx > -1) {
		upgrade_list.remove(remove_idx);
		if (upgrade_idx > remove_idx)
			upgrade_idx -= 1;
		return true;
	}
	return false;
}

/**
 * Try to upgrade all airports that are in the upgrade_list.
 */
function WormAirportUpgrade::UpgradeAirports()
{
	// while there are more upgrades and we are not over the max time limit and max upgrade limit
	// do upgrade the next airport.
	
	// 0. If there are closed airports go to 2.
	// 1. Close some airports.
	// 2. Check list of closed airports. If there are any that have no planes there anymore then try to upgrade.
	
	
	//if ((upgrade_list == null) || (upgrade_list.len() == 0))
	if (GetCount() <= 0)
		return;
	AILog.Warning("There are " + upgrade_list.len() + " airports that need to be upgraded.");
	
	// Don't let the loop last more than 90 days
	local loop_end = AIDate.GetCurrentDate() + 90;
	upgrade_idx = 0;
	while (AIDate.GetCurrentDate() < loop_end) {
		local upgrade_airport = GetNext();
		if (upgrade_airport == null)
			return;
		
		//AILog.Warning("---------------------------------------------------------------------------------");
		AILog.Warning("Try to upgrade airport " + AIStation.GetName(upgrade_airport.station_id));
		//AILog.Warning("---------------------------------------------------------------------------------");
		TryUpgradeAirport(upgrade_airport);
		if (upgrade_idx >= GetCount()) // Stop after we did one full loop
			return;
	}
}

/**
 * Try to upgrade an airport in specified town where old airport is at station_tile.
 * @param airport The airport instance that needs upgrading.
 * @return false if we failed to upgrade, true if airport got upgraded.
 */
function WormAirportUpgrade::TryUpgradeAirport(airport)
{
	local airport_type = AIAirport.GetAirportType(airport.station_tile);
	if (airport_type == airport.wanted_airport_type)
		return false;
	//local station_id = AIStation.GetStationID(station_tile);
	if (!AIStation.IsValidStation(airport.station_id))
		return false;
	if (!WormAirport.IsWithinNoiseLimit(airport.station_tile, airport_type, airport.wanted_airport_type))
		return false;

	/* Determine tile of other side of route: If station there is invalid we won't
		try to upgrade this one since it will be soon deleted (after all aircraft
		have been sold). */
	local tile_other_st = air_manager.GetAiportTileOtherEndOfRoute(airport.airport_town, airport.station_tile);
	local st_id_other = -1;
	if (tile_other_st > -1) {
		st_id_other = AIStation.GetStationID(tile_other_st);
	}
	
	if (!AIStation.IsValidStation(st_id_other)) {
		/* Make sure this station isn't closed because we may have to send
			aircraft there in case of upgrade failure. */
		if (AIStation.IsAirportClosed(airport.station_id)) {
			AIStation.OpenCloseAirport(airport.station_id);
			AILog.Warning("Opening airport " + AIStation.GetName(airport.station_id) + " again since other airport got removed.");
		}
		// Remove from upgrade queue
		Remove(airport.station_id);
		return false;
	}
	
	/* Airport needs upgrading if possible... */
	/* Close airport to make sure no airplanes will land, but those still there
		will be handled. */
	/* If airport still closed after one full loop then open it again after one more try. */
	local old_airport_closed = AIStation.IsAirportClosed(airport.station_id);
	/* Make sure airport is closed. */
	if (!old_airport_closed) {
		AILog.Info("Closing airport " + AIStation.GetName(airport.station_id) + " because it needs upgrading!");
		closed_count++;
		AIStation.OpenCloseAirport(airport.station_id);
		airport.airport_closed_date = AIDate.GetCurrentDate();
		// Send all airplanes that are on the airport to their next order...
		air_manager.SendAirplanesOffAirport(airport.airport_town, airport.station_id);
	}
	else {
		AILog.Info("Try upgrading airport " + AIStation.GetName(airport.station_id) + " again.");
	}
	local nearest_town = AIAirport.GetNearestTown(airport.station_tile, airport_type);
	local upgrade_result = WormAirport.BUILD_FAILED;
	/* Try to upgrade airport. */
	if ((airport_type == AIAirport.AT_LARGE) && (airport.wanted_airport_type == AIAirport.AT_METROPOLITAN)) {
		/// Since METROPOLITAN is the same size as LARGE we will try to rebuild it in the same spot!
		upgrade_result = WormAirport.UpgradeLargeToMetropolitan(nearest_town, airport.station_id, airport.station_tile);
	}
	else {
		upgrade_result = air_manager.UpgradeAirport(nearest_town, airport.station_id, airport.station_tile,
			airport.wanted_airport_type, tile_other_st);
	}
	/* Need to check if it succeeds. */
	if (upgrade_result == WormAirport.BUILD_SUCCESS) {
		/* Need to get the station id of the upgraded station. */
		/* Check if old airport.station_id is still valid */
		if (AIStation.IsValidStation(airport.station_id)) {
			air_manager.UpdateAirportTileInfo(airport.airport_town, airport.station_id, airport.station_tile);
			/* It is possible that upgrading failed for whatever reason but that we then
			 * managed to rebuild the original airport type. In that case upgrade result
			 * will give SUCCESS too but upgrading obviously failed then so check for that.
			 */
			airport.station_tile = air_manager.towns_used.GetValue(airport.airport_town);
			airport_type = AIAirport.GetAirportType(airport.station_tile);
			if (airport_type == airport.wanted_airport_type)
				AILog.Warning("Upgrading airport " + AIStation.GetName(airport.station_id) + " succeeded!");
			else {
				AILog.Warning("Upgrading airport " + AIStation.GetName(airport.station_id) + " failed!");
				AILog.Warning("However we managed to build a replacement airport of an older type.");
				// blacklist upgrading
				air_manager.upgrade_blacklist.AddItem(airport.airport_town, AIDate.GetCurrentDate()+500);
			}
		}
		else {
			AILog.Error("We're out of luck: station id is no longer valid!");
			/*** @todo Figure out what we should do now.
				Can we expect this to happen in normal situations? */
		}
		if (AIStation.IsAirportClosed(airport.station_id))
			{ AIStation.OpenCloseAirport(airport.station_id); }
		// Remove from upgrade queue
		Remove(airport.station_id);
	}
	else if (upgrade_result == WormAirport.BUILD_REBUILD_FAILED) {
		/* Oh boy. Airport was removed but rebuilding a replacement failed. */
		AILog.Warning("We removed the old airport but failed to build a replacement!");
		/* 1. Try to build a second airport as replacement. */
		/* First get tile of other end of route. */
		local tile_other_end = air_manager.GetAiportTileOtherEndOfRoute(airport.airport_town, airport.station_tile);
		if (tile_other_end != -1) {
			/* Try to build an airport somewhere. */
			/*** @todo Currently we don't consider the case that if the new airport will
			   be farther away than the old one that certain aircraft with limited
			   range will cause problems. */
			AILog.Info("Try to build a replacement airport somewhere else");
			/// @todo Check if it is possible to init towns only once (set to null list outside loop),
			/// then here check for it being null...
			local towns = air_manager.GetTownListForAirportSearch();
			local tile_2 = air_manager.FindSuitableAirportSpot(airport.wanted_airport_type, tile_other_end, towns);
			if (tile_2 >= 0) {
				/* Valid tile for airport: try to build it. */
				if (!AIAirport.BuildAirport(tile_2, airport.wanted_airport_type, AIStation.STATION_NEW)) {
					AILog.Warning(AIError.GetLastErrorString());
					AILog.Error("Although the testing told us we could build an airport, it still failed at tile " + 
					  WormStrings.WriteTile(tile_2) + ".");
					air_manager.towns_used.RemoveValue(tile_2);
					air_manager.SendAllVehiclesOfStationToDepot(airport.station_id, VEH_STATION_REMOVAL);
				}
				else {
					/* Building new airport succeeded. Now update tiles, routes and orders. */
					air_manager.ReplaceAirportTileInfo(airport.airport_town, airport.station_tile, tile_2, tile_other_end);
					AILog.Warning("Replaced airport " + AIStation.GetName(airport.station_id) + 
						" with " + AIStation.GetName(AIStation.GetStationID(tile_2)) + "." );
				}
			}
			else {
				AILog.Warning("Finding a suitable spot for a new airport failed.");
				AILog.Info("Sending vehicles to depot to be sold.");
				air_manager.SendAllVehiclesOfStationToDepot(airport.station_id, VEH_STATION_REMOVAL);
			}
		}
		else {
			/* Unlikely failure, send aircraft to hangar then delete aircraft and airport. */
			AILog.Warning("We couldn't find the other station belonging to this route!");
			AILog.Info("Sending vehicles to depot to be sold.");
			air_manager.SendAllVehiclesOfStationToDepot(airport.station_id, VEH_STATION_REMOVAL);
		}
		// Remove from upgrade queue
		Remove(airport.station_id);
	}
	else {
		/* If airport was already closed before we started trying to upgrade and is now
			still closed then open it again to give airplanes a chance to land and be
			handled unless it was caused by airplanes still being on the airport.
			We will try upgrading again at a later time. */
		if (airport.airport_closed_date + 90 < AIDate.GetCurrentDate() ||
			(old_airport_closed && AIStation.IsAirportClosed(airport.station_id) &&
			(upgrade_result != WormAirport.BUILD_AIRPORT_NOT_EMPTY))) {
			AIStation.OpenCloseAirport(airport.station_id);
			AILog.Info("We couldn't upgrade the airport this time, blacklisting it for a while.");
			local days = 500;
			if (airport_type == AIAirport.AT_SMALL)
				days = 100; // We want to get rid of small airports faster in this case
			air_manager.upgrade_blacklist.AddItem(airport.airport_town, AIDate.GetCurrentDate()+days);
			
			// Remove from upgrade queue
			Remove(airport.station_id);
		}
	}
	return true;
}
