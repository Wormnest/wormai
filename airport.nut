/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file airport.nut Class with airport related functions for WormAI split off from airmanager.nut.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2013-2017.
 *
 */ 

/**
 * Define the WormAirport class which holds airport related functions.
 */
class WormAirport
{

	static BUILD_SUCCESS = 1;			///< Status code: Building airport succeeded
	static BUILD_FAILED  = 2;			///< Building airport failed
	static BUILD_REBUILD_FAILED = 3;	///< Rebuilding airport failed
	static BUILD_REMOVE_FAILED = 4;		///< Removing airport failed
	static BUILD_AIRPORT_NOT_EMPTY = 5;	///< Airport is not empty, removing impossible
	static BUILD_NO_NEW_LOCATION = 6;	///< We could not find a good location for the replacement airport


	/**
	 * Get the optimal type of airport that is available.
	 * @note For now we only choose between small, large and metropolitan. Larger ones would only
	 * be useful for very high cargo/passenger amounts with many airplanes.
	 * @return The optimal AirportType or null if no suitable airport is available.
	 */
	static function GetOptimalAvailableAirportType();

	/**
	 * Get the first airport tile you can find that is part of station st_id.
	 * @param st_id The airport station id.
	 * @return The tile number or -1
	 */
	static function GetAirportTileFromStation(st_id);

	/*
	 * Get the number of aircraft (un)loading at the specified station.
	 * @st_id The id of the station
	 * @return The number of aircraft (un)loading or -1 in case of an error.
	 */
	static function GetNumLoadingAtStation(st_id);

	/**
	 * Get the number of terminals for aircraft on the specified airport.
	 * @param airport_tile A tile that is part of an airport.
	 * @return Number of bays.
	 */
	static function GetNumTerminals(airport_tile);

	/**
	 * Check whether the airport (including depots) is empty, meaning no airplanes.
	 * @param include_landing_queue (default true) Whether to include planes in the landing queue on tiles above the airport.
	 * @return true if it is empty, otherwise false.
	 * @note Airports can only be demolished when there are no planes on or above the airport.
	 */
	static function IsAirportEmpty(station_id, include_landing_queue=true);

	/**
	 * Determines whether an airport at a given tile is allowed by the town authorities
	 * because of the noise level.
	 * @param tile The tile where the aiport would be built.
	 * @param old_airport_type The type of the current airport or AT_INVALID if there is no airport yet.
	 * @param new_airport_type The type of the proposed replacement airport.
	 * @return True if the construction would be allowed. If the noise setting is off, it defaults to true.
	 * @note Adapted from SimpleAI.
	 */
	static function IsWithinNoiseLimit(tile, old_airport_type, new_airport_type);

	/**
	 * Remove airport at specified tile.
	 * If removing fails then give a warning.
	 * @note Note that using Sleep(x) here and trying again doesn't work for some reason (removing still fails)
	 * @param tile The tile of the airport that should be removed.
	 */
	static function RemoveAirport(tile);

	/**
	 * Tries to upgrade airport from large to metropolitan in the same location since they are the same size.
	 * @param nearest_town The nearest town according to town influence.
	 * @param station_id The id of the airport to upgrade.
	 * @param station_tile The tile of the airport.
	 * @return WormAirport.BUILD_SUCCESS if we succeed, or else one of the BUILD_XXX error codes.
	 * @pre Noise and Town allowance already checked, enough money, ...
	 */ 
	static function UpgradeLargeToMetropolitan(nearest_town, station_id, station_tile);

	/**
	 * Tries to upgrade airport from small to either large or metropolitan.
	 * @param station_id The id of the airport to upgrade.
	 * @param station_tile The tile of the airport.
	 * @param current_airport_type The type of the current airport.
	 * @param new_airport_type The type of airport to build as replacement.
	 * @param new_location The tile where the airport should be rebuilt.
	 * @return WormAirport.BUILD_SUCCESS if we succeed, or else one of the BUILD_XXX error codes.
	 */
	static function UpgradeAirport(station_id, station_tile, current_airport_type, new_airport_type, new_location);

}

/**
 * Get the optimal type of airport that is available.
 * @note For now we only choose between small, large and metropolitan. Larger ones would only
 * be useful for very high cargo/passenger amounts with many airplanes.
 * @return The optimal AirportType or null if no suitable airport is available.
 */
function WormAirport::GetOptimalAvailableAirportType()
{
	local AirType = null;
	if (AIAirport.IsValidAirportType(AIAirport.AT_METROPOLITAN)) {
		AirType = AIAirport.AT_METROPOLITAN;
	}
	else if (AIAirport.IsValidAirportType(AIAirport.AT_LARGE)) {
		AirType = AIAirport.AT_LARGE;
	}
	else if (AIAirport.IsValidAirportType(AIAirport.AT_SMALL)) {
		AirType = AIAirport.AT_SMALL;
	}
	return AirType;
}

/**
 * Get the first airport tile you can find that is part of station st_id.
 * @param st_id The airport station id.
 * @return The tile number or -1
 */
function WormAirport::GetAirportTileFromStation(st_id)
{
	// Get one of the airport tiles (since station can also have non airport tiles, e.g. train station)
	local airport_tiles = AITileList_StationType(st_id, AIStation.STATION_AIRPORT);
	if(airport_tiles.IsEmpty())
		return -1;
	return airport_tiles.Begin();
}

/*
 * Get the number of aircraft (un)loading at the specified station.
 * @st_id The id of the station
 * @return The number of aircraft (un)loading or -1 in case of an error.
 */
function WormAirport::GetNumLoadingAtStation(st_id)
{
	local airport_tiles = AITileList_StationType(st_id, AIStation.STATION_AIRPORT);
	if(airport_tiles.IsEmpty())
		return -1;

	// All vechicles going to this station.
	local vehicle_list = AIVehicleList_Station(st_id);
	// No need to remove other vehicles than aircraft since they won't be found on airport tiles anyway.
	
	local loading_unloading = 0;
	// Loop over all vehicles going to this station and check their state
	foreach (vehid, dummy in vehicle_list) {
		local loc = AIVehicle.GetLocation(vehid);
		local state = AIVehicle.GetState(vehid);
		if ((state == AIVehicle.VS_AT_STATION) && airport_tiles.HasItem(loc))
			loading_unloading++;
	}
	return loading_unloading;
}

/**
 * Get the number of terminals for aircraft on the specified airport.
 * @param airport_tile A tile that is part of an airport.
 * @return Number of bays.
 */
function WormAirport::GetNumTerminals(airport_tile)
{
	switch(AIAirport.GetAirportType(airport_tile)) {
		case AIAirport.AT_SMALL:
			return 2;
			break;
		case AIAirport.AT_COMMUTER:
		case AIAirport.AT_LARGE:
		case AIAirport.AT_METROPOLITAN:
			return 3;
			break;
		case AIAirport.AT_INTERNATIONAL:
			return 6;
			break;
		case AIAirport.AT_INTERCON:
			return 8;
			break;
		default:
			return 0;
			break; 
	}
}

/**
 * Check whether the airport (including depots) is empty, meaning no airplanes.
 * @param include_landing_queue (default true) Whether to include planes in the landing queue on tiles above the airport.
 * @return true if it is empty, otherwise false.
 * @note Airports can only be demolished when there are no planes on or above the airport.
 */
function WormAirport::IsAirportEmpty(station_id, include_landing_queue=true)
{
	local aircraft = AIVehicleList_Station(station_id);
	if (aircraft.Count() == 0)
		return true;
	local airport_tiles = AITileList_StationType(station_id, AIStation.STATION_AIRPORT);
	if (airport_tiles.IsEmpty())
		return false;

	/* Note that we should NOT adjust for plane speed here since testing showed us that a plane
	 * leaves the airport at a speed of close to 320 km/h-ish.
	 * Speed just before lifting off seems to be 268 km/h-ish, then when lifting off 284, 300, 317, 333.
	 */
	local broken_down_speed = 320 /*/ AIGameSettings.GetValue("plane_speed")*/;

	foreach (plane, dummy in aircraft) {
		local veh_tile = AIVehicle.GetLocation(plane);
		//AILog.Info("[DEBUG] " + AIVehicle.GetName(plane) + ", location: " + WormStrings.WriteTile(veh_tile));
		// Check if the location of one of our planes is on one of the airport tiles.
		if (airport_tiles.HasItem(veh_tile)) {
			// If planes in the landing queue should also be taken into account then every plane
			// on or above the airport tiles means not Empty.
			if (include_landing_queue) {
				return false;
			}
			local veh_state = AIVehicle.GetState(plane);
			//AILog.Info("[DEBUG] " + AIVehicle.GetName(plane) + ", location: " + WormStrings.WriteTile(veh_tile) +
			//	", speed: " + AIVehicle.GetCurrentSpeed(plane) + ", state: " + veh_state);
			// Anything not running or broken down should be on the airport.
			if ((veh_state != AIVehicle.VS_RUNNING) && (veh_state != AIVehicle.VS_BROKEN)) {
				return false;
			}
			else {
				// A running or broken down plane can also be flying over the airport or be in the
				// waiting queue to land above the airport. Thus we need to check the speed to see if
				// it's a plane on the airport or above the airport.
				// Taxi-ing speed is 150 km-ish; Broken down = 320 kmh-ish.
				// All default OpenTTD aircraft have a speed higher than 320 so we can use that.
				if (AIVehicle.GetCurrentSpeed(plane) < broken_down_speed)
					return false;
			}
		}
	}
	// No planes found on airport tiles
	return true;
}

/**
 * Determines whether an airport at a given tile is allowed by the town authorities
 * because of the noise level.
 * @param tile The tile where the aiport would be built.
 * @param old_airport_type The type of the current airport or AT_INVALID if there is no airport yet.
 * @param new_airport_type The type of the proposed replacement airport.
 * @return True if the construction would be allowed. If the noise setting is off, it defaults to true.
 * @note Adapted from SimpleAI.
 */
function WormAirport::IsWithinNoiseLimit(tile, old_airport_type, new_airport_type)
{
	if (!AIGameSettings.GetValue("economy.station_noise_level")) return true;
	if (old_airport_type != AIAirport.AT_INVALID) {
		// Replacing airport
		local allowed = AITown.GetAllowedNoise(AIAirport.GetNearestTown(tile, old_airport_type));
		local increase = AIAirport.GetNoiseLevelIncrease(tile, new_airport_type) -
			AIAirport.GetNoiseLevelIncrease(tile, old_airport_type);
		// return here or else we need to declare the two local's outside the if
		return (increase < allowed);
	}
	else {
		// No existing airport
		local allowed = AITown.GetAllowedNoise(AIAirport.GetNearestTown(tile, new_airport_type));
		local increase = AIAirport.GetNoiseLevelIncrease(tile, new_airport_type);
		// return here or else we need to declare the two local's outside the if
		return (increase < allowed);
	}
}

/**
 * Remove airport at specified tile.
 * If removing fails then give a warning.
 * @note Note that using Sleep(x) here and trying again doesn't work for some reason (removing still fails)
 * @param tile The tile of the airport that should be removed.
 */
function WormAirport::RemoveAirport(tile)
{
	if (!AIAirport.RemoveAirport(tile)) {
		AILog.Warning(AIError.GetLastErrorString());
		AILog.Warning("Failed to remove airport " + AIStation.GetName(AIStation.GetStationID(tile)) +
			" at tile " + WormStrings.WriteTile(tile) );
	}
}

/**
 * Tries to upgrade airport from large to metropolitan in the same location since they are the same size.
 * @param nearest_town The nearest town according to town influence.
 * @param station_id The id of the airport to upgrade.
 * @param station_tile The tile of the airport.
 * @return WormAirport.BUILD_SUCCESS if we succeed, or else one of the BUILD_XXX error codes.
 * @pre Noise and Town allowance already checked, enough money, ...
 */ 
function WormAirport::UpgradeLargeToMetropolitan(nearest_town, station_id, station_tile)
{
	if (!WormAirport.IsAirportEmpty(station_id)) {
		AILog.Info("Can't upgrade, there are still airplanes on the airport.");
		return WormAirport.BUILD_AIRPORT_NOT_EMPTY;
	}
	// Try to remove old airport
	/// @todo Can we use RemoveAirport too or does that make it impossible to reuse station_id?
	if (!AITile.DemolishTile(station_tile))
		return WormAirport.BUILD_REMOVE_FAILED;
	// Try to build new airport in same spot
	local airport_status = AIAirport.BuildAirport(station_tile, AIAirport.AT_METROPOLITAN, station_id);
	if (!airport_status) {
		// Try to get our old station back...
		AILog.Info("Upgrading airport failed, try to get old airport back.");
		airport_status = AIAirport.BuildAirport(station_tile, AIAirport.AT_LARGE, station_id);
	}
	if (airport_status)
		return WormAirport.BUILD_SUCCESS;
	else
		return WormAirport.BUILD_REBUILD_FAILED;
}

/**
 * Tries to upgrade airport from small to either large or metropolitan.
 * @param station_id The id of the airport to upgrade.
 * @param station_tile The tile of the airport.
 * @param current_airport_type The type of the current airport.
 * @param new_airport_type The type of airport to build as replacement.
 * @param new_location The tile where the airport should be rebuilt.
 * @return WormAirport.BUILD_SUCCESS if we succeed, or else one of the BUILD_XXX error codes.
 */
function WormAirport::UpgradeAirport(station_id, station_tile, current_airport_type, new_airport_type, new_location)
{
	// Try to remove old airport
	/// @todo Can we use RemoveAirport too or does that make it impossible to reuse station_id?
	if (!AITile.DemolishTile(station_tile)) {
		AILog.Warning(AIError.GetLastErrorString());
		AILog.Info("Removing old airport failed, can't upgrade (probably airplane in the way).");
		return WormAirport.BUILD_REMOVE_FAILED;
	}

	// Try to build new airport in the new location
	local airport_status = AIAirport.BuildAirport(new_location, new_airport_type, station_id);
	if (!airport_status) {
		// Try to get our old station back...
		AILog.Warning(AIError.GetLastErrorString());
		AILog.Info("Upgrading airport failed, try to get old airport back.");
		airport_status = AIAirport.BuildAirport(station_tile, current_airport_type, station_id);
	}
	if (airport_status)
		// New station tile etc will be updated by caller.
		return WormAirport.BUILD_SUCCESS;
	else {
		AILog.Warning(AIError.GetLastErrorString());
		return WormAirport.BUILD_REBUILD_FAILED;
	}
}
