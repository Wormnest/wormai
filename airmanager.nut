/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file airmanager.nut Class containing the Air Manager for WormAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2013-2016.
 *
 */ 

/* Define some constants for easier maintenance. */

/* Airport/Aircraft handling. */
const MINIMUM_BALANCE_BUILD_AIRPORT = 100000;	///< Minimum bank balance to start building airports.
const MINIMUM_BALANCE_AIRCRAFT = 25000;			///< Minimum bank balance to allow buying a new aircraft.
const MINIMUM_BALANCE_TWO_AIRCRAFT = 5000000;	///< Minimum bank balance to allow buying 2 aircraft at once.
const MINIMUM_BALANCE_BUILD_STATUE =  750000;	///< Minimum bank balance to allow building of statues.
const BUILD_OVERHEAD = 20000;					///< Add a little extra for building (certain terrain costs more to build on).

const AIRCRAFT_LOW_PRICE_CUT = 500000;			///< Bank balance below which we will try to buy a low price aircraft.
const AIRCRAFT_MEDIUM_PRICE_CUT = 2000000;		///< Bank balance below which we will try to buy a medium price aircraft.
const AIRCRAFT_LOW_PRICE = 50000;				///< Maximum price of a low price aircraft.
const AIRCRAFT_MEDIUM_PRICE = 250000;			///< Maximum price of a medium price aircraft.
const AIRCRAFT_HIGH_PRICE = 1500000;			///< Maximum price of a high price aircraft.

const STARTING_ACCEPTANCE_LIMIT = 150;			///< Starting limit in acceptance for finding suitable airport tile.
const BAD_YEARLY_PROFIT = 10000;				///< Yearly profit limit below which profit is deemed bad.
const AIRPORT_LIMIT_FACTOR = 4;					///< We limit airports to max aircraft / FACTOR * 2 (2 needed per route).
const AIRPORT_CARGO_WAITING_LOW_LIMIT = 250;	///< Limit of waiting cargo (passengers) on airport above which we add an aircraft.
const AIRPORT_CARGO_WAITING_HIGH_LIMIT = 1250;	///< Limit of waiting cargo (passengers) on airport above which we add 2 aircraft.
const AIRPORT2_WAITING_DIFF = 150;				///< Cargo waiting diff (less) value at the other station to allow extra aircraft.
const VEHICLE_AGE_LEFT_LIMIT = 150;				///< Number of days limit before maximum age for vehicle to get sent to depot for selling.
const MAX_STATUES_BUILD_COUNT = 3;				///< Maximum number of statues we will build at one time.

/// @{
/**
 * @name Reasons for selling vehicles
 * @todo Maybe convert to enum.
 */
const VEH_OLD_AGE			= 0;				///< Vehicle is sold because of its old age.
const VEH_LOW_PROFIT		= 1;				///< Vehicle is sold because it has low profits.
const VEH_STATION_REMOVAL	= 2;				///< Vehicle is sold because one of its stations got removed and could not be replaced.
/// @}

/**
 * Define the WormAirManager class which handles airports and airplanes.
 */
class WormAirManager
{
	/* Variables used by WormAirManager */
	/* 1. Variables that will be saved in a savegame. */
	towns_used = null;					///< town id, airport station tile
	route_1 = null;						///< vehicle id, station_tile of first station in an order
	route_2 = null;						///< vehicle id, station_tile of last station in an order
	
	/* 2. Variables that will NOT be saved. */
	distance_of_route = {};				///< vehicle id, distance between first/last order stations
	vehicle_to_depot = {};				///< vehicle id, boolean always true currently
	engine_usefulness = null;
	acceptance_limit = 0;				///< Starting limit for passenger acceptance for airport finding.
	passenger_cargo_id = -1;
	no_aircraft_warning_shown = false;	///< Whether we have shown the no available aircraft warning
	route_without_aircraft = false;		///< True if we have built airports but failed to buy airplanes due to lack of money.
	incomplete_route_tile1 = 0;			///< Tile of first airport of incomplete air route without aircraft.
	incomplete_route_tile2 = 0;			///< Tile of second airport of incomplete air route without aircraft.
	towns_blacklist = null;				///< List of towns where we already tried to build an airport.


	/** Create an instance of WormAirManager and initialize our variables. */
	constructor()
	{
		this.distance_of_route = {};
		this.vehicle_to_depot = {};
		this.towns_used = AIList();
		this.towns_blacklist = AIList();
		this.route_1 = AIList();
		this.route_2 = AIList();
		this.engine_usefulness = AIList();
		this.acceptance_limit = STARTING_ACCEPTANCE_LIMIT;
		/* Get the correct Passengers id even when an industry NewGRF is used. */
		this.passenger_cargo_id = Helper.GetPAXCargo();
	}

    /// @{
	/** @name Debugging output functions */
	/** List of towns used and stations near those towns. */
	function DebugListTownsUsed();
	/** List all towns in the supplied list. */
	function DebugListTowns(towns_list);
	/** List all routes: per route all stations and all vehicles on that route with relevant info. */
	function DebugListRoutes();
	/** List all route info in the supplied list. */
	function DebugListRoute(route);
	/** List all our air routes. */
	function DebugListRouteInfo();
	/** List all vehicles that were sent to depot to be sold. */
	function DebugListVehiclesSentToDepot();
	/**
	 * Show info about the specified vehicle. It's start and end town and distance between them.
	 * @param veh = Vehicle id
	 */
	function DebugVehicleInfo(veh);
	/// @}

	/** @name  Airport handling functions */
    /// @{
	/**
	 * Remove airport at specified tile.
	 * If removing fails then give a warning.
	 * @note Note that using Sleep(x) here and trying again doesn't work for some reason (removing still fails)
	 * @param tile The tile of the airport that should be removed.
	 */
	function RemoveAirport(tile);
	/**
	 * Get the optimal type of airport that is available.
	 * @note For now we only choose between small, large and metropolitan. Larger ones would only
	 * be useful for very high cargo/passenger amounts with many airplanes.
	 * @return The optimal AirportType or null if no suitable airport is available.
	 */
	function GetOptimalAvailableAirportType();
	/**
	 * Get tile of airport at the other end of the route.
	 * @param town_id Town id of town at this end of route.
	 * @param station_tile tile of station at this end of route.
	 * @return tile of airport or -1 if not found.
	 */
	function GetAiportTileOtherEndOfRoute(town_id, station_tile);
	/**
	 * Update the airport station tile info in our lists after upgrading airport.
	 * Expects a valid station_id.
	 * @param town_idx Index into towns_used list.
	 * @param station_id Id of the Airport station that got upgraded.
	 * @param old_tile The old tile for the airport before upgrading.
	 */
	function UpdateAirportTileInfo(town_idx, station_id, old_tile);
	/**
	 * Replace the airport town and station tile info in our lists and update orders.
	 * @param old_town_idx Index into towns_used list of town/station being replaced
	 * @param old_tile The old tile for the airport being replaced.
	 * @param new_tile The tile of the new airport.
	 * @param other_end_of_route_tile Tile of other end of route (needed to access vehicles of route)
	 */
	function ReplaceAirportTileInfo(old_town_idx, old_tile, new_tile, other_end_of_route_tile);
	/**
	 * Determines whether an airport at a given tile is allowed by the town authorities
	 * because of the noise level
	 * @param tile The tile where the aiport would be built.
	 * @param airport_type The type of the airport.
	 * @return True if the construction would be allowed. If the noise setting is off, it defaults to true.
	 * @note Taken from SimpleAI.
	 */
	function IsWithinNoiseLimit(tile, airport_type);
	/**
	 * Checks all airports to see if they should be upgraded.
	 * If they can it tries to upgrade the airport. If it fails after removing the old airport
	 * it will first try to replace it with another airport at another spot. If that also fails
	 * it will send the aircraft on the now crippled route to depot to be sold. After all
	 * aircraft are sold the remaining airport will be sold too.
	 */
	function CheckForAirportsNeedingToBeUpgraded();
	/**
	 * Build an airport route. Find 2 cities that are big enough and try to build airport in both cities.
	 * Then we can build an aircraft and try to make some money.
	 * We limit our amount of airports to max aircraft / AIRPORT_LIMIT_FACTOR * 2.
	 * (2 airports for a route, and AIRPORT_LIMIT_FACTOR planes per route)
	 */
	function BuildAirportRoute();
	/**
	 * Find a suitable spot for an airport, walking all towns hoping to find one.
	 * When a town is used, it is marked as such and not re-used.
	 * @param airport_type The type of airport we want to build.
	 * @param center_tile The tile around which we will search for a spot for the airport.
	 * @return tile where we can build the airport or an error code.
	 */
	function FindSuitableAirportSpot(airport_type, center_tile);
	/**
	  * Sells the airports at tile_1 and tile_2. Removes towns from towns_used list too.
	  * @param airport_1_tile The tile of the first airport to remove
	  * @param airport_2_tile The tile of the other airport to remove
	  * @note The airport tiles are allowed to be invalid. Removal will be ignored in that
	  * case but the towns_used will be updated.
	  */
	function SellAirports(airport_1_tile, airport_2_tile);
	/// @}

	/** @name Order handling */
    /// @{
	/**
	 * Check whether the airport at a certain town is used as the first order of a route.
	 * @param town_id The id of the town to check if it's the first order.
	 * @return true if it is the first order, else false if it is the last order.
	 */
	function IsTownFirstOrder(town_id);
	/**
	 * Replace orders of a vehicle, either the first station or last station is replaced.
	 * @param veh Vehicle to replace the orders for.
	 * @param is_first_order Whether to replace the orders for the first or last station.
	 * @param breakdowns Whether breakdowns are on; if they are on we will add maintenance orders.
	 * @param station_tile Tile of station for the new order.
	 */
	function ReplaceOrders(veh, is_first_order, breakdowns, station_tile);
	/**
	 * Insert go to station order for airport at station_tile.
	 * @param veh Vehicle to set the order for.
	 * @param order_pos Position in the order list where order should be inserted.
	 * @param station_tile Tile for the Airport of the to be inserted order.
	 * @return true if order got inserted; false in case of failure to insert.
	 */
	function InsertGotoStationOrder(veh, order_pos, station_tile);
	/**
	 * Insert Maintenance order for airport at station_tile.
	 * @param veh Vehicle to set the order for
	 * @param order_pos Position in the order list where order should be inserted
	 * @param station_tile Tile for the Airport (not the hangar) of the order to be inserted.
	 * @return true if order got inserted; false in case of failure to insert.
	 */
	function InsertMaintenanceOrder(veh, order_pos, station_tile);
	/**
	 * Replace go to station order for airport at station_tile.
	 * @param veh Vehicle to set the order for.
	 * @param order_pos Position in the order list where order should be inserted.
	 * @param station_tile Tile for the Airport of the new to be inserted order.
	 */
	function ReplaceGotoStationOrder(veh, order_pos, station_tile);
	/// @}

	/** @name Aircraft handling */
    /// @{
	/**
	 * Get the maximum distance this aircraft can safely fly without landing.
	 * @param engine The engine id for which we want to know the maximum distance.
	 * @return The maximum distance.
	 */
	function GetMaximumDistance(engine);
	/**
	 * Build an aircraft with orders from tile_1 to tile_2.
	 * The best available aircraft will be bought.
	 * @param tile_1 Airport tile that should be used as the first order.
	 * @param tile_2 Airport tile that should be used as the last order.
	 * @param start_tile The Airport tile where the airplane should start. If this is 0 then
	 * it will start at tile_1. To let it start at tile_2 use the same value as tile_2.
	 */
	function BuildAircraft(tile_1, tile_2, start_tile);
	/**
	 * Send all vehicles belonging to a station to depot for selling.
	 * @param station_id The id of the station.
	 * @param sell_reason The reason for selling. Valid reasons are
	 * @ref VEH_OLD_AGE, @ref VEH_LOW_PROFIT, @ref VEH_STATION_REMOVAL
	 */
	function SendAllVehiclesOfStationToDepot(station_id, sell_reason);
	/**
	 * Send a vehicle to depot to be sold when it arrives.
	 * @param vehicle The vehicle id of the vehicle to be sold.
	 * @param sell_reason The reason for selling. Valid reasons are
	 * @ref VEH_OLD_AGE, @ref VEH_LOW_PROFIT, @ref VEH_STATION_REMOVAL
	 */
	function SendToDepotForSelling(vehicle,sell_reason);
	/**
	 * Remove a vehicle from our route lists and to depot list.
	 * @note If this is the last vehicle serving a certain route then after selling
	 * the vehicle we will also sell the airports.
	 * @param vehicle The vehicle id that should be removed from the lists.
	 */
	function RemoveVehicleFromLists(vehicle);
	/**
	 * Sell the vehicle provided it's in depot. If it's not yet in depot it will fail silently.
	 * @param vehicle The id of the vehicle that should be sold.
	 */
	function SellVehicleInDepot(vehicle);
	/**
	 * Sell all vehicles in depot that are marked to be sold.
	 */
	function SellVehiclesInDepot();
	/// @}

	/** @name Task related functions */
    /// @{
	/**
	 * Check all vehicles for being old or needing upgrading to a newer type.
	 * It will send all vehicles that are non optimal to depot for selling.
	 */
	function ManageVehicleRenewal();
	/**
	 * Check for airports that don't have any vehicles anymore and delete them.
	 */
	function CheckAirportsWithoutVehicles();
	/**
	 * Remove towns from the blacklist where blacklisting has expired.
	 */
	function UpdateBlacklist();
	/**
	 * Manage air routes:
	 * ------------------
	 * - Checks for airports without vehicles.
	 * - Send unprofitable aircraft to depot for selling.
	 * - Add aircraft to routes that have a lot of waiting cargo.
	 * @return Error code if something went wrong or ok.
	 * @todo Refactor the parts of this function into separate functions.
	 */
	function ManageAirRoutes();
	/** 
	 * Callback that handles events. Currently only AIEvent.ET_VEHICLE_CRASHED is handled.
	 */
	function HandleEvents();
	/**
	 * Task that evaluates all available aircraft for how suited they are
	 * for our purposes. The suitedness values for aircraft which we can use are saved in
	 * @ref engine_usefulness.
	 * @param clear_warning_shown_flag Whether to clear the @ref no_aircraft_warning_shown flag.
	 */
	function EvaluateAircraft(clear_warning_shown_flag);
	/**
	 * Build the company headquarters if there isn't one yet.
	 * @note Adapted from the version in AdmiralAI.
	 */ 
	function BuildHQ();
	/**
	 * Build statues in towns where we have a station as long as we have a reasonable amount of money.
	 * We limit the amount of statues we build at any one time.
	 */
	function BuildStatues();
/// @}

	/** @name General functions */
    /// @{
	/**
	 * Get Town id in our towns_used list based on tile of station built near it.
	 * @return id of town or null if not found.
	 */
	function GetTownFromStationTile(st_tile);
	/**
	 * Determine if a station is valid based on the station tile.
	 * @param st_tile The tile of the station.
	 * @return true if station is valid, otherwise false.
	 */
	function IsValidStationFromTile(st_tile);
	/**
	 * Determine if the first station of the route of a vehicle is valid.
	 * @param veh Vehicle to determine the validity of the station for.
	 * @return true if station is valid, otherwise false.
	 */
	function IsValidFirstStation(veh);
	/**
	 * Determine if the last station of the route of a vehicle is valid.
	 * @param veh Vehicle to determine the validity of the station for.
	 * @return true if station is valid, otherwise false.
	 */
	function IsValidLastStation(veh);
	/// @}

	/** @name Valuator functions */
    /// @{
	/**
	 * Valuator function to get the cost factor of an aircraft.
	 * @param engine The engine id of the aircraft.
	 * @param costfactor_list The list (usually @ref engine_usefulness) that holds the cost factors.
	 * @return The cost factor.
	 */
	function GetCostFactor(engine, costfactor_list);
	/// @}

	/**
	 * Do any necessary processing after a savegame has been loaded.
	 * Currently recomputes the values for the @ref distance_of_route table.
	 */
	function AfterLoading();
}

//////////////////////////////////////////////////////////////////////////
//	Debugging functions

/** List of towns used and stations near those towns. */
function WormAirManager::DebugListTownsUsed()
{
	AILog.Info("---------- DEBUG towns_used and related stations ----------");
	if (!this.towns_used) {
		AILog.Warning("WARNING: towns_used is null!");
	}
	else {
		AILog.Info("Number of towns used: " + this.towns_used.Count())
		//foreach(t in towns_used) {
		for (local t = towns_used.Begin(); !towns_used.IsEnd(); t = towns_used.Next()) {
			local tile = towns_used.GetValue(t);
			local is_city = (AITown.IsCity(t) ? "city" : "town");
			AILog.Info("Town: " + AITown.GetName(t) + " (id: " + t + "), " + is_city +
				", population: " + AITown.GetPopulation(t) + ", houses: " + AITown.GetHouseCount(t) +
				", grows every " + AITown.GetGrowthRate(t) + " days");
			AILog.Info("    Location: " + WormStrings.WriteTile(AITown.GetLocation(t)) +
				", station tile " + WormStrings.WriteTile(tile) + ").")
			local sid = AIStation.GetStationID(tile);
			local st_veh = AIVehicleList_Station(sid);
			AILog.Info("Station: " + AIStation.GetName(sid) + " (id: " + sid + "), waiting cargo: " + 
				AIStation.GetCargoWaiting(sid, passenger_cargo_id) + ", cargo rating: " + 
				AIStation.GetCargoRating(sid, passenger_cargo_id) + ", aircraft: " +
				st_veh.Count());
		}
	}
	AILog.Info("");
}

/** List all towns in the supplied list. */
function WormAirManager::DebugListTowns(towns_list)
{
	AILog.Info("---------- DEBUG list towns in list----------");
	if (!this.towns_used) {
		AILog.Warning("WARNING: towns_list is null!");
	}
	else {
		AILog.Info("Number of towns in list: " + towns_list.Count());
		for (local t = towns_list.Begin(); !towns_list.IsEnd(); t = towns_list.Next()) {
			local is_city = (AITown.IsCity(t) ? "city" : "town");
			AILog.Info("Town: " + AITown.GetName(t) + " (id: " + t + "), " + is_city +
				", population: " + AITown.GetPopulation(t) + ", houses: " + AITown.GetHouseCount(t) +
				", grows every " + AITown.GetGrowthRate(t) + " days");
			AILog.Info("    Location: " + WormStrings.WriteTile(AITown.GetLocation(t)) );
		}
	}
	AILog.Info("");
}

/** List all routes: per route all stations and all vehicles on that route with relevant info. */
function WormAirManager::DebugListRoutes()
{
	AILog.Info("---------- DEBUG route info ----------");
		local expected_route_count = this.towns_used.Count() / 2;
		local route_count = 0;
		local veh_count = 0;
		local veh_check = AIList();
		veh_check.AddList(route_1); // Check to see if all vehicles are accounted for
		AILog.Info("Number of routes: " + expected_route_count );
		for (local t = towns_used.Begin(); !towns_used.IsEnd(); t = towns_used.Next()) {
			local st_tile = towns_used.GetValue(t);
			// Find out whether this station is the first or last order
			local route1 = AIList();
			route1.AddList(route_1);
			// Keep only those with our station tile
			route1.KeepValue(st_tile);
			if (route1.Count() == 0) {
				/* Don't warn here since a station can be either on route_1 or route_2. */
				continue;
			}
			// List from and to station names, and distance between them, and total profit of
			// all planes on route in the last year
			local st_id = AIStation.GetStationID(st_tile);
			local st_veh = AIVehicleList_Station(st_id);
			route_count += 1;
			if (st_veh.Count() == 0) {
				/* Might happen after a failed upgrading of stations. The other one will then get
					removed after all aircraft haven been sold. */
				AILog.Warning("Station " + AIStation.GetName(st_id) + " near town " + AITown.GetName(t)
					+ " has 0 aircraft!");
				continue;
			}
			local first = true;
			local total_profit = 0;
			// Sort vehicle list on last years profit
			st_veh.Valuate(AIVehicle.GetProfitLastYear);
			for (local veh = st_veh.Begin(); !st_veh.IsEnd(); veh = st_veh.Next()) {
				veh_check.RemoveItem(veh); // Remove vehicle from our checklist
				if (first) {
					// Get list of stations this vehicle has in its orders
					local veh_stations = AIStationList_Vehicle(veh);
					local st_end_id = -1;
					foreach(veh_st_id, dummy_val in veh_stations) {
						// Since we have only 2 stations in our orders any id not the same
						// as st_id will be our target station id
						if (veh_st_id != st_id) {
							st_end_id = veh_st_id;
							break;
						}
					}
					local st_end_tile = route_2.GetValue(veh);
					local sq_dist = AITile.GetDistanceSquareToTile(st_tile, st_end_tile)
					AILog.Info( "Route from " + AIStation.GetName(st_id) +" ("+st_id+ ") to " +
						AIStation.GetName(st_end_id) +" ("+st_end_id+") "+
						", distance: " + sqrt(sq_dist).tointeger());
					first = false;
				}
				// Show info about aircraft
				AILog.Info("     " + AIVehicle.GetName(veh) + " (id: " + veh + "), age: " +
					WormStrings.GetAgeString(AIVehicle.GetAge(veh)) + ", capacity: " + 
					AIVehicle.GetCapacity(veh, passenger_cargo_id) + ", size: " + 
					WormStrings.GetAircraftTypeAsText(AIVehicle.GetEngineType(veh)) );
				local last_profit = AIVehicle.GetProfitLastYear(veh);
				// Increment total profit for this route
				total_profit += last_profit;
				AILog.Info("        Profit last year: " + last_profit + ", this year: " + 
					AIVehicle.GetProfitThisYear(veh));
			}
			veh_count += st_veh.Count();
			AILog.Warning("     Total " + st_veh.Count() + " aircraft. Total profit last year: " + total_profit + ", average: " + (total_profit / st_veh.Count()));
		}
	if (route_count != expected_route_count) {
		AILog.Error("Attention! Route count: " + route_count + " is not the same as the expected route count: " +
			expected_route_count);
		//DebugListRoute(route_1);
		//DebugListRoute(route_2);
	}
	if (veh_count != this.route_1.Count()) {
		AILog.Error("Attention! Vehicle count on our stations: " + veh_count +
			" is not the same as vehicles on routes count: " + this.route_1.Count());
		//DebugListRoute(route_1);
		//DebugListRoute(route_2);
	}
	if (veh_check.Count() > 0) {
		/* Should result in the same amount as the previous check. */
		/* A reason for showing up here is vehicles that are sent to depot to be sold
			because of a failed upgrade of a station of a route. */
		AILog.Warning("The following vehicles were not used by the airports listed above.");
		DebugListRoute(veh_check);
		DebugListVehiclesSentToDepot();
	}
	AILog.Info("");
}

/** List all route info in the supplied list. */
function WormAirManager::DebugListRoute(route)
{
	AILog.Info("---------- DEBUG route ----------");
	if (!route) {
		AILog.Error("ERROR: route is null!");
	}
	else {
		AILog.Info("Number of aircraft in this list: " + route.Count());
		for (local r = route.Begin(); !route.IsEnd(); r = route.Next()) {
			local st_tile = route.GetValue(r);
			AILog.Info("Aircraft: " + AIVehicle.GetName(r) + " (id: " + r + ", tile " + 
				WormStrings.WriteTile(st_tile) + " = station " + 
				AIStation.GetName(AIStation.GetStationID(st_tile)) + ").");
		}
	}
	AILog.Info("");
}

/** List all our air routes. */
function WormAirManager::DebugListRouteInfo()
{
	//this.route_1.AddItem(vehicle, tile_1);
	//this.route_2.AddItem(vehicle, tile_2);
	local temp_route = AIList();
	temp_route.AddList(this.route_1); // so that we don't sort the original list
	AILog.Info("---------- DEBUG route info ----------");
	if (!temp_route) {
		AILog.Warning("WARNING: route list is null!");
	}
	else {
		temp_route.Sort(AIList.SORT_BY_ITEM, true);
		AILog.Info("Number of aircraft used: " + temp_route.Count());
		for (local r = temp_route.Begin(); !temp_route.IsEnd(); r = temp_route.Next()) {
			local tile1 = 0;
			local tile2 = 0;
			local t1 = 0;
			local t2 = 0;
			local route_start = AIList();
			local route_end = AIList();
			route_start.AddList(this.towns_used);
			route_end.AddList(this.towns_used);
			tile1 = temp_route.GetValue(r);
			tile2 = route_2.GetValue(r);
			route_start.KeepValue(tile1);
			t1 = route_start.Begin();
			route_end.KeepValue(tile2);
			t2 = route_end.Begin();
			local dist = this.distance_of_route.rawget(r);
			AILog.Info("Aircraft: " + AIVehicle.GetName(r) + " (id: " + r + "), from: " + 
				AITown.GetName(t1) + ", to: " + AITown.GetName(t2) + ", distance: " + dist);
		}
	}
	AILog.Info("");
}

/**
 * Show info about the specified vehicle. It's start and end town and distance between them.
 * @param veh = Vehicle id
 */
function WormAirManager::DebugVehicleInfo(veh) {
	local output_str = "Aircraft: ";
	if (AIVehicle.IsValidVehicle(veh)) {
		output_str += AIVehicle.GetName(veh);
	}
	else {
		output_str += "<invalid aircraft id>";
	}
	output_str += " (id: " + veh + "), from: ";
	/* Get route start and end points. */
	local tile1 = route_1.GetValue(veh);
	local tile2 = route_2.GetValue(veh);
	local town1 = GetTownFromStationTile(tile1);
	local town2 = GetTownFromStationTile(tile2);
	if (town1 > -1)
		{ output_str += AITown.GetName(town1); }
	else
		{ output_str += "<invalid town id>"; }
	output_str += ", to: ";
	if (town2 > -1)
		{ output_str += AITown.GetName(town2); }
	else
		{ output_str += "<invalid town id>"; }
	local dist = this.distance_of_route.rawget(veh);
	output_str += ", distance: " + dist + ".";
	
	/* If vehicle was sent to depot to be sold give some info about that. */
	if (vehicle_to_depot.rawin(veh)) {
		output_str += " [On the way to depot to be sold.]";
	}
	
	AILog.Info(output_str);
}

/**
 * List all vehicles that were sent to depot to be sold.
 */
function WormAirManager::DebugListVehiclesSentToDepot() {
	AILog.Info("The following vehicles are on the way to depot to be sold.");

	// veh_id = vehicle id, veh_value = boolean, always true currently
	foreach( veh_id, veh_value in vehicle_to_depot) {
		DebugVehicleInfo(veh_id);
	}
}

//	End debugging functions
//////////////////////////////////////////////////////////////////////////

/**
 * Get Town id in our towns_used list based on tile of station built near it.
 * @return id of town or null if not found.
 */
function WormAirManager::GetTownFromStationTile(st_tile) {
	local towns = AIList();
	towns.AddList(this.towns_used);
	towns.KeepValue(st_tile);
	if (towns.Count() > 0) {
		return towns.Begin();
	}
	else
		{ return null; }
}

/**
 * Remove airport at specified tile.
 * If removing fails then give a warning.
 * @note Note that using Sleep(x) here and trying again doesn't work for some reason (removing still fails)
 * @param tile The tile of the airport that should be removed.
 */
function WormAirManager::RemoveAirport(tile)
{
	if (!AIAirport.RemoveAirport(tile)) {
		AILog.Warning(AIError.GetLastErrorString());
		AILog.Warning("Failed to remove airport " + AIStation.GetName(AIStation.GetStationID(tile)) +
			" at tile " + WormStrings.WriteTile(tile) );
	}
}

/**
 * Get the optimal type of airport that is available.
 * @note For now we only choose between small, large and metropolitan. Larger ones would only
 * be useful for very high cargo/passenger amounts with many airplanes.
 * @return The optimal AirportType or null if no suitable airport is available.
 */
function WormAirManager::GetOptimalAvailableAirportType()
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
 * Check whether the airport at a certain town is used as the first order of a route.
 * @param town_id The id of the town to check if it's the first order.
 * @return true if it is the first order, else false if it is the last order.
 */
function WormAirManager::IsTownFirstOrder(town_id)
{
	local station_tile = towns_used.GetValue(town_id);
	// Copy the list of First order routes
	local route1 = AIList();
	route1.AddList(route_1);
	// Keep only those with our station tile
	route1.KeepValue(station_tile);
	/* AILog.Info("Town: " + AITown.GetName(town_id) + ", station at tile: " + WormStrings.WriteTile(station_tile) +
		", route1 count: " + route1.Count()); */
	// return true if found (not 0) in route_1
	return (route1.Count() != 0);
}

/**
 * Get tile of airport at the other end of the route.
 * @param town_id Town id of town at this end of route.
 * @param station_tile tile of station at this end of route.
 * @return tile of airport or -1 if not found.
 */
function WormAirManager::GetAiportTileOtherEndOfRoute(town_id, station_tile)
{
	local route1 = AIList();
	local route2 = AIList();
	if (IsTownFirstOrder(town_id)) {
		route1.AddList(route_1);
		route2 = route_2;
	}
	else {
		route1.AddList(route_2);
		route2 = route_1;
	}
	// Keep only those with our station tile
	route1.KeepValue(station_tile);
	if (route1.Count() == 0) {
		if (!route_without_aircraft)
			AILog.Warning("  No routes found that contain this station!");
		return -1;
	}

	/* Return tile for other end of route from first vehicle belonging to other end of route. */
	return route2.GetValue(route1.Begin());
}

/**
 * Update the airport station tile info in our lists after upgrading airport.
 * Expects a valid station_id.
 * @param town_idx Index into towns_used list.
 * @param station_id Id of the Airport station that got upgraded.
 * @param old_tile The old tile for the airport before upgrading.
 */
function WormAirManager::UpdateAirportTileInfo(town_idx, station_id, old_tile)
{
	/* Determine if old town data belongs to route 1 or 2. */
	local route = AIList();
	if (IsTownFirstOrder(town_idx)) {
		route = route_1;
		//AILog.Info("route 1");
	}
	else {
		route = route_2;
		//AILog.Info("route 2");
	}
	/* Note: IsTownFirstOrder must be called BEFORE towns_used.SetValue because it uses the
		old tile value to determine if it belongs to route 1. */
	/* Get the new tile for the airport after upgrading. */
	local new_airport_tile = Airport.GetAirportTile(station_id);
	/* Update the airport tile in our towns_used list. */
	this.towns_used.SetValue(town_idx, new_airport_tile);

	//AILog.Warning("Update route tile " + WormStrings.WriteTile(old_tile) + " to " + WormStrings.WriteTile(new_airport_tile));

	/* Loop through the route info that should contain our airport. */
	for (local r = route.Begin(); !route.IsEnd(); r = route.Next()) {
		/* Update airport station tiles. */
		if (route.GetValue(r) == old_tile) {
			//AILog.Info("Updating info for vehicle: " + AIVehicle.GetName(r));
			route.SetValue(r, new_airport_tile);
		}
	}
	/* DEBUG:
	if (IsTownFirstOrder(t)) {
		DebugListRoute(route_1);
	}
	else {
		DebugListRoute(route_2);
	} */
}

/**
 * Replace the airport town and station tile info in our lists and update orders.
 * @param old_town_idx Index into towns_used list of town/station being replaced
 * @param old_tile The old tile for the airport being replaced.
 * @param new_tile The tile of the new airport.
 * @param other_end_of_route_tile Tile of other end of route (needed to access vehicles of route)
 */
function WormAirManager::ReplaceAirportTileInfo(old_town_idx, old_tile, new_tile, other_end_of_route_tile)
{
	/* Determine which end of a route is being replaced. */
	local route = AIList();
	local is_first_order = true;
	if (IsTownFirstOrder(old_town_idx)) {
		route = route_1;
	}
	else {
		route = route_2;
		is_first_order = false;
	}

	/* Remove old town from towns_used. */
	this.towns_used.RemoveValue(old_tile);

	/* Loop through the route info that should contain our airport. */
	for (local r = route.Begin(); !route.IsEnd(); r = route.Next()) {
		/* Update airport station tiles. */
		if (route.GetValue(r) == old_tile) {
			route.SetValue(r, new_tile);
		}
	}
	
	/* Change the orders of vehicles belonging to this route. */
	/* Since we group vehicles with the same orders we only have to do that once. */
	/* First get a vehicle belonging to our station. */
	local st_veh = AIVehicleList_Station(AIStation.GetStationID(other_end_of_route_tile));
	if (st_veh.Count() > 0) {
		local veh = st_veh.Begin();
		local breakdowns = AIGameSettings.GetValue("difficulty.vehicle_breakdowns") > 0;
		/* Now update the vehicle orders. */
		ReplaceOrders(veh, is_first_order, breakdowns, new_tile);
	}
}

/**
 * Insert Maintenance order for airport at station_tile.
 * @param veh Vehicle to set the order for
 * @param order_pos Position in the order list where order should be inserted
 * @param station_tile Tile for the Airport (not the hangar) of the order to be inserted.
 * @return true if order got inserted; false in case of failure to insert.
 */
function WormAirManager::InsertMaintenanceOrder(veh, order_pos, station_tile)
{
	/* Get the hangar tile. */
	local Depot_Airport = AIAirport.GetHangarOfAirport(station_tile);
	/* Add maintenance order for our station. */
	if (!AIOrder.InsertOrder(veh, order_pos, Depot_Airport, AIOrder.OF_SERVICE_IF_NEEDED )) {
		AILog.Warning("Failed to insert go to depot order at order postion " + order_pos +
			", depot tile " + WormStrings.WriteTile(Depot_Airport));
		return false;
	}
	else
		{ return true; }
}

/**
 * Insert go to station order for airport at station_tile.
 * @param veh Vehicle to set the order for.
 * @param order_pos Position in the order list where order should be inserted.
 * @param station_tile Tile for the Airport of the to be inserted order.
 * @return true if order got inserted; false in case of failure to insert.
 */
function WormAirManager::InsertGotoStationOrder(veh, order_pos, station_tile)
{
	if (!AIOrder.InsertOrder(veh, order_pos, station_tile, AIOrder.OF_FULL_LOAD_ANY )) {
		AILog.Warning("Failed to add order for station tile " + WormStrings.WriteTile(station_tile));
		return false;
	}
	else
		{ return true; }
}

/**
 * Replace go to station order for airport at station_tile.
 * @param veh Vehicle to set the order for.
 * @param order_pos Position in the order list where order should be inserted.
 * @param station_tile Tile for the Airport of the new to be inserted order.
 */
function WormAirManager::ReplaceGotoStationOrder(veh, order_pos, station_tile)
{
	/* Replace the orders for the station at order_pos. */
	/* First insert new order below current order. */
	InsertGotoStationOrder(veh, order_pos+1, station_tile);
	/* Delete order to old station. By doing it in this order the aircraft going to the old order 
	   will now go to the new one. */
	AIOrder.RemoveOrder(veh, order_pos);
}

/**
 * Replace orders of a vehicle, either the first station or last station is replaced.
 * @param veh Vehicle to replace the orders for.
 * @param is_first_order Whether to replace the orders for the first or last station.
 * @param breakdowns Whether breakdowns are on; if they are on we will add maintenance orders.
 * @param station_tile Tile of station for the new order.
 */
function WormAirManager::ReplaceOrders(veh, is_first_order, breakdowns, station_tile)
{
	/* Order of aircraft orders (with breakdowns on):
		0/0. Goto station 1
		1/-. Maintain at hangar of station 2
		2/1. Goto station 2
		3/-. Maintain at hangar of station 1
	*/
	local order_pos = 0;
	/* Beware that the current setting of breakdowns doesn't have to be the same as when
	   the orders were created. We determine if there are maintenance orders by looking
	   at the order count. */
	local has_maint_orders = AIOrder.GetOrderCount(veh) == 4;
	if (is_first_order) {
		/* Replace the orders for the first station. */
		ReplaceGotoStationOrder(veh, 0, station_tile);
		order_pos = 1;
		/* If we had maintenance before and not now then remove maintenance of station 2. */
		if (has_maint_orders) {
			if (!breakdowns) {
				/* Delete maintenance order of station 2. */
				AIOrder.RemoveOrder(veh, order_pos);
				order_pos = 2;
			}
			else {
				order_pos = 3;
			}
			/* Delete maintenance order of station 1.*/
			AIOrder.RemoveOrder(veh, order_pos);
		}
		if (breakdowns) {
			/* If old station 2 order didn't have a maintenance order then add it. */
			if (!has_maint_orders) {
				/* We need destination of station 2. */
				local st2 = AIOrder.GetOrderDestination(veh, 1);
				/* Insert maintenance order for station 2. */
				InsertMaintenanceOrder(veh, 2, st2);
			}
			/* Insert maintenance order for station 1. */
			InsertMaintenanceOrder(veh, 3, station_tile);
		}
	}
	else {
		if (has_maint_orders)
			{ order_pos = 2; }
		else
			{ order_pos = 1; }
		/* Replace the orders for the second station. */
		ReplaceGotoStationOrder(veh, order_pos, station_tile);
		/* If we had maintenance before and not now then also remove maintenance of station 1. */
		if (has_maint_orders) {
			/* Delete maintenance order of station 2.*/
			AIOrder.RemoveOrder(veh, 1);
			if (!breakdowns) {
				/* Delete maintenance order of station 1. */
				AIOrder.RemoveOrder(veh, 2);
			}
		}
		if (breakdowns) {
			/* Insert maintenance order for station 2. */
			InsertMaintenanceOrder(veh, 1, station_tile);
			/* If old station 1 order didn't have a maintenance order then add it. */
			if (!has_maint_orders) {
				/* We need destination of station 1. */
				local st2 = AIOrder.GetOrderDestination(veh, 0);
				/* Insert maintenance order for station 1. */
				InsertMaintenanceOrder(veh, 3, st2);
			}
		}
	}
}

/**
 * Send all vehicles belonging to a station to depot for selling.
 * @param station_id The id of the station.
 * @param sell_reason The reason for selling. Valid reasons are
 * @ref VEH_OLD_AGE, @ref VEH_LOW_PROFIT, @ref VEH_STATION_REMOVAL
 */
function WormAirManager::SendAllVehiclesOfStationToDepot(station_id, sell_reason)
{
	if (AIStation.IsValidStation(station_id)) {
		local st_veh = AIVehicleList_Station(station_id);
		for (local veh = st_veh.Begin(); !st_veh.IsEnd(); veh = st_veh.Next()) {
			SendToDepotForSelling(veh, sell_reason);
		}
	}
	else {
		AILog.Warning("Can't send vehicles to depot: station id is invalid!");
	}
}

/**
 * Determines whether an airport at a given tile is allowed by the town authorities
 * because of the noise level
 * @param tile The tile where the aiport would be built.
 * @param airport_type The type of the airport.
 * @return True if the construction would be allowed. If the noise setting is off, it defaults to true.
 * @note Taken from SimpleAI.
 */
function WormAirManager::IsWithinNoiseLimit(tile, airport_type)
{
	/** @todo Maybe we should account for wanting to remove an old smaller airport first
	  * which presumably would decrease the noise level.
	  */
	if (!AIGameSettings.GetValue("economy.station_noise_level")) return true;
	local allowed = AITown.GetAllowedNoise(AIAirport.GetNearestTown(tile, airport_type));
	local increase = AIAirport.GetNoiseLevelIncrease(tile, airport_type);
	return (increase <= allowed);
}
 
 /**
 * Checks all airports to see if they should be upgraded.
 * If they can it tries to upgrade the airport. If it fails after removing the old airport
 * it will first try to replace it with another airport at another spot. If that also fails
 * it will send the aircraft on the now crippled route to depot to be sold. After all
 * aircraft are sold the remaining airport will be sold too.
 */
function WormAirManager::CheckForAirportsNeedingToBeUpgraded()
{
	AILog.Info("Check if there are airports that can be upgraded.");
	/// @todo Maybe set a max amount of upgrades at one time?
	for (local t = towns_used.Begin(); !towns_used.IsEnd(); t = towns_used.Next()) {
		/// @todo Maybe order by highest amount of waiting cargo to choose the station to be converted first.
		// AILog.Info("Upgrade check for: " + AITown.GetName(t));
		// Start looking at stations in towns that are the last/second order.
		local station_tile = towns_used.GetValue(t);
		local station_id = AIStation.GetStationID(station_tile);
		local airport_type = AIAirport.GetAirportType(station_tile);
		local optimal_airport = GetOptimalAvailableAirportType();
		/* Determine tile of other side of route: If station there is invalid we won't
			try to upgrade this one since it will be soon deleted (after all aircraft
			have been sold). */
		local tile_other_st = GetAiportTileOtherEndOfRoute(t, station_tile);
		local st_id_other = -1;
		if (tile_other_st > -1) {
			st_id_other = AIStation.GetStationID(tile_other_st);
		}
		if ((airport_type != optimal_airport) && AIStation.IsValidStation(station_id) &&
			this.IsWithinNoiseLimit(station_tile, optimal_airport)) {
			if (!AIStation.IsValidStation(st_id_other)) {
				/* Make sure this station isn't closed because we may have to send
					aircraft there in case of upgrade failure. */
				if (AIStation.IsAirportClosed(station_id)) {
					AIStation.OpenCloseAirport(station_id);
					AILog.Warning("Opening airport again since other one got removed.");
				}
				continue;
			}
			AILog.Info("Airport: " + AIStation.GetName(station_id) + " needs upgrading!");
			/* Airport needs upgrading if possible... */
			/* Close airport to make sure no airplanes will land, but those still there
				will be handled. */
			/* If airport still closed after one full loop then open it again after one more try. */
			local old_airport_closed = AIStation.IsAirportClosed(station_id);
			/* Make sure airport is closed. */
			if (!old_airport_closed)
				{ AIStation.OpenCloseAirport(station_id); }
			local upgrade_list = [optimal_airport];
			/* Try to upgrade airport. */
			local upgrade_result = Airport.UpgradeAirportInTown(t, station_id, upgrade_list, this.passenger_cargo_id, 
			  this.passenger_cargo_id);
			/* Need to check if it succeeds. */
			if (upgrade_result == Result.SUCCESS) {
				/* Need to get the station id of the upgraded station. */
				/* Check if old station_id is still valid */
				if (AIStation.IsValidStation(station_id)) {
					UpdateAirportTileInfo(t, station_id, station_tile);
					/* It is possible that upgrading failed for whatever reason but that we then
					 * managed to rebuild the original airport type. In that case upgrade result
					 * will give SUCCESS too but upgrading obviously failed then so check for that.
					 */
					station_tile = towns_used.GetValue(t);
					airport_type = AIAirport.GetAirportType(station_tile);
					if (airport_type == optimal_airport)
						AILog.Warning("Upgrading airport " + AIStation.GetName(station_id) + " succeeded!");
					else {
						AILog.Warning("Upgrading airport " + AIStation.GetName(station_id) + " failed!");
						AILog.Warning("However we managed to build a replacement airport of an older type.");
						/// @todo register this case and wait a while before trying to upgrade again!
					}
				}
				else {
					AILog.Error("We're out of luck: station id is no longer valid!");
					/*** @todo Figure out what we should do now.
						Can we expect this to happen in normal situations? */
				}
				if (AIStation.IsAirportClosed(station_id))
					{ AIStation.OpenCloseAirport(station_id); }
			}
			else if (upgrade_result == Result.REBUILD_FAILED) {
				/* Oh boy. Airport was removed but rebuilding a replacement failed. */
				AILog.Warning("We removed the old airport but failed to build a replacement!");
				/* 1. Try to build a second airport as replacement. */
				/* First get tile of other end of route. */
				local tile_other_end = GetAiportTileOtherEndOfRoute(t, station_tile);
				if (tile_other_end != -1) {
					/* Try to build an airport somewhere. */
					/*** @todo Currently we don't consider the case that if the new airport will
					   be farther away than the old one that certain aircraft with limited
					   range will cause problems. */
					AILog.Info("Try to build a replacement airport somewhere else");
					local tile_2 = this.FindSuitableAirportSpot(optimal_airport, tile_other_end);
					if (tile_2 >= 0) {
						/* Valid tile for airport: try to build it. */
						if (!AIAirport.BuildAirport(tile_2, optimal_airport, AIStation.STATION_NEW)) {
							AILog.Warning(AIError.GetLastErrorString());
							AILog.Error("Although the testing told us we could build an airport, it still failed at tile " + 
							  WormStrings.WriteTile(tile_2) + ".");
							this.towns_used.RemoveValue(tile_2);
							SendAllVehiclesOfStationToDepot(station_id, VEH_STATION_REMOVAL);
						}
						else {
							/* Building new airport succeeded. Now update tiles, routes and orders. */
							ReplaceAirportTileInfo(t, station_tile, tile_2, tile_other_end);
							AILog.Warning("Replaced airport " + AIStation.GetName(station_id) + 
								" with " + AIStation.GetName(AIStation.GetStationID(tile_2)) + "." );
						}
					}
					else {
						AILog.Warning("Finding a suitable spot for a new airport failed.");
						AILog.Info("Sending vehicles to depot to be sold.");
						SendAllVehiclesOfStationToDepot(station_id, VEH_STATION_REMOVAL);
					}
				}
				else {
					/* Unlikely failure, send aircraft to hangar then delete aircraft and airport. */
					AILog.Warning("We couldn't find the other station belonging to this route!");
					AILog.Info("Sending vehicles to depot to be sold.");
					SendAllVehiclesOfStationToDepot(station_id, VEH_STATION_REMOVAL);
				}
			}
			else {
				/* If airport was already closed before we started trying to upgrade and is now
					still closed then open it again to give airplanes a chance to land and be
					handled. We will try upgrading again at a later time. */
				if (old_airport_closed && AIStation.IsAirportClosed(station_id))
					{ AIStation.OpenCloseAirport(station_id); }
			}
		}
	}
}

/**
 * Build an airport route. Find 2 cities that are big enough and try to build airport in both cities.
 * Then we can build an aircraft and try to make some money.
 * We limit our amount of airports to max aircraft / AIRPORT_LIMIT_FACTOR * 2.
 * (2 airports for a route, and AIRPORT_LIMIT_FACTOR planes per route)
 */
function WormAirManager::BuildAirportRoute()
{
	local tile_1 = 0;
	local tile_2 = 0;
	if (!(route_without_aircraft)) {
		if (!WormMoney.HasMoney(WormMoney.InflationCorrection(MINIMUM_BALANCE_BUILD_AIRPORT)))
			return ERROR_NOT_ENOUGH_MONEY;
		
		// No sense building airports if we already have the max (or more because amount can be changed in game)
		local max_vehicles = Vehicle.GetVehicleLimit(AIVehicle.VT_AIR);
		if (max_vehicles <= this.route_1.Count()) {
			AILog.Info("We are not going to look for a new airport route. We already have the maximum number of aircraft.");
			return ERROR_MAX_AIRCRAFT;
		}
		
		if (engine_usefulness.Count() == 0) {
			/* First look if there are any aircraft that we can use. */
			EvaluateAircraft(false);
			if (engine_usefulness.Count() == 0) {
				/* Most likely no aircraft found for the range we wanted of before any aircraft are introduced. */
				AILog.Warning("There are no aircraft available at the moment that we can use.");
				/* Don't spam this warning in the debug log. */
				no_aircraft_warning_shown = true;
				return ERROR_BUILD_AIRCRAFT_INVALID;
			}
		}

		// Check for our maximum allowed airports (max only set by our own script, not OpenTTD)
		local airport_count = this.towns_used.Count();
		if ((max_vehicles * 2 / AIRPORT_LIMIT_FACTOR) <= airport_count) {
			AILog.Info("Not building more airports. We already have a reasonable amount for the current aircraft limit.");
			return ERROR_MAX_AIRPORTS;
		}

		// See for capacity of different airport types:
		// Airport capacity test: http://www.tt-forums.net/viewtopic.php?f=2&t=47279
		local airport_type = GetOptimalAvailableAirportType();
		if (airport_type == null) {
			AILog.Warning("No suitable airport type available that we know how to use.");
			return ERROR_NO_SUITABLE_AIRPORT;
		}

		/* Get enough money to work with. Since building on rough terrain costs more we add in overhead costs. */
		if (!WormMoney.GetMoney(AIAirport.GetPrice(airport_type)*2 + WormMoney.InflationCorrection(BUILD_OVERHEAD + AIRCRAFT_LOW_PRICE))) {
			// Can't get enough money
			return ERROR_NOT_ENOUGH_MONEY;
		}

		/* Show some info about what we are doing */
		AILog.Info(Helper.GetCurrentDateString() + " Trying to build an airport route");

		tile_1 = this.FindSuitableAirportSpot(airport_type, 0);
		if (tile_1 < 0) {
			if ((this.towns_used.Count() == 0) && (tile_1 == ERROR_FIND_AIRPORT_ACCEPTANCE)) {
				// We don't have any airports yet so try again at a lower acceptance limit
				while(tile_1 == ERROR_FIND_AIRPORT_ACCEPTANCE) {
					tile_1 = this.FindSuitableAirportSpot(airport_type, 0);
				}
				if (tile_1 < 0) return ERROR_FIND_AIRPORT1;
			}
			else {
				return ERROR_FIND_AIRPORT1;
			}
		}
		tile_2 = this.FindSuitableAirportSpot(airport_type, tile_1);
		if (tile_2 < 0) {
			// Check for 1, not 0, here since if we get here we have at least 1 airport.
			if ((this.towns_used.Count() == 1) && (tile_2 == ERROR_FIND_AIRPORT_ACCEPTANCE)) {
				// We don't have any airports yet so try again at a lower acceptance limit
				while(tile_2 == ERROR_FIND_AIRPORT_ACCEPTANCE) {
					tile_2 = this.FindSuitableAirportSpot(airport_type, 0);
				}
				if (tile_2 < 0) {
					this.towns_used.RemoveValue(tile_1);
					return ERROR_FIND_AIRPORT2;
				}
			}
			else {
				this.towns_used.RemoveValue(tile_1);
				return ERROR_FIND_AIRPORT2;
			}
		}

		/* In certain cases building an airport still fails for unknown reason. */
		/* Build the airports for real */
		if (!AIAirport.BuildAirport(tile_1, airport_type, AIStation.STATION_NEW)) {
			AILog.Warning(AIError.GetLastErrorString());
			AILog.Error("Although the testing told us we could build an airport, it still failed at tile " +
			  WormStrings.WriteTile(tile_1) + ".");
			this.towns_used.RemoveValue(tile_1);
			this.towns_used.RemoveValue(tile_2);
			return ERROR_BUILD_AIRPORT1;
		}
		if (!AIAirport.BuildAirport(tile_2, airport_type, AIStation.STATION_NEW)) {
			AILog.Warning(AIError.GetLastErrorString());
			AILog.Error("Although the testing told us we could build an airport, it still failed at tile " +
			  WormStrings.WriteTile(tile_2) + ".");
			this.RemoveAirport(tile_1);
			this.towns_used.RemoveValue(tile_1);
			this.towns_used.RemoveValue(tile_2);
			return ERROR_BUILD_AIRPORT1;
		}
	}
	else {
		/* We have an unfinished route without airplanes. */
		tile_1 = incomplete_route_tile1;
		tile_2 = incomplete_route_tile2;
		AILog.Info("Trying to add aircraft to incomplete route without any airplanes.");
		/* See if we can get more loan...*/
		if (!WormMoney.GetMoney(WormMoney.InflationCorrection(BUILD_OVERHEAD + AIRCRAFT_LOW_PRICE), WormMoney.WM_SILENT)) {
			AILog.Info("We still don't have enough money.");
			// Can't get enough money
			return ERROR_NOT_ENOUGH_MONEY;
		}
		route_without_aircraft = false;
	}

	local ret = this.BuildAircraft(tile_1, tile_2, tile_1);
	if (ret < 0) {
		if (!(ret == ERROR_NOT_ENOUGH_MONEY)) {
			// For some reason removing an airport in here sometimes fails, sleeping a little
			// helps for the cases we have seen.
			AIController.Sleep(1);
			this.RemoveAirport(tile_1);
			this.RemoveAirport(tile_2);
			this.towns_used.RemoveValue(tile_1);
			this.towns_used.RemoveValue(tile_2);
			AILog.Info("Cancelled route because we couldn't build an aircraft.");
		}
		else {
			/* No money to add airplanes to this new route: Try to add them later. */
			route_without_aircraft = true;
			incomplete_route_tile1 = tile_1;
			incomplete_route_tile2 = tile_2;
			AILog.Warning("We built airports but don't have enough money yet to buy airplanes.");
		}
	}
	else {
		local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
		if ((balance >= WormMoney.InflationCorrection(MINIMUM_BALANCE_TWO_AIRCRAFT))
			&& (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) > this.route_1.Count())) {
			/* Build a second aircraft and start it at the other airport. */
			ret = this.BuildAircraft(tile_1, tile_2, tile_2);
		}
		AILog.Info("Done building a route");
	}

	AILog.Info("");
	
	return ret;
}

/**
 * Get the maximum distance this aircraft can safely fly without landing.
 * @param engine The engine id for which we want to know the maximum distance.
 * @return The maximum distance.
 */
function WormAirManager::GetMaximumDistance(engine) {
	local max_dist = AIEngine.GetMaximumOrderDistance(engine);
	if (max_dist == 0) {
		/* Unlimited distance. Since we need to be able to keep values above a squared distance
		We set it to a predefined maximum value. Maps can be maximum 4096x4096. Diagonal will
		be more than that. To be safe we compute 10000 * 10000. */
		return 10000 * 10000;
	}
	else {
		return max_dist;
	}
}

/**
 * Build an aircraft with orders from tile_1 to tile_2.
 * The best available aircraft will be bought.
 * @param tile_1 Airport tile that should be used as the first order.
 * @param tile_2 Airport tile that should be used as the last order.
 * @param start_tile The Airport tile where the airplane should start. If this is 0 then
 * it will start at tile_1. To let it start at tile_2 use the same value as tile_2.
 */
function WormAirManager::BuildAircraft(tile_1, tile_2, start_tile)
{
	// Don't try to build aircraft if we already have the max (or more because amount can be changed in game)
	if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) <= this.route_1.Count()) {
		AILog.Warning("Can't buy aircraft. We already have the maximum number allowed.");
		return ERROR_MAX_AIRCRAFT;
	}

	/* order_start_tile: where our order should start */
	local order_start_tile = start_tile;
	local order_end_tile = 0;
	if (start_tile == 0) {
		order_start_tile = tile_1;
		order_end_tile = tile_2
	}
	else {
		if (start_tile == tile_1)
			{ order_end_tile = tile_2; }
		else
			{ order_end_tile = tile_1; }
	}
	/* Build an aircraft */
	local hangar = AIAirport.GetHangarOfAirport(order_start_tile);
	local engine = null;
	local eng_price = 0;

	local engine_list = AIEngineList(AIVehicle.VT_AIR);

	/* When bank balance < AIRCRAFT_LOW_PRICE_CUT, buy cheaper planes */
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	
	/*** @todo Maybe try to get more loan here? */
	
	/* Balance below a certain minimum? Wait until we buy more planes. */
	if (balance < WormMoney.InflationCorrection(MINIMUM_BALANCE_AIRCRAFT)) {
		AILog.Warning("We are low on money (" + balance + "). We are not going to buy an airplane right now.");
		return ERROR_NOT_ENOUGH_MONEY;
	}
	
	/* We don't want helicopters so weed them out. */
	/* Might not be necessary since they are most likely never the most profitable. */
	engine_list.Valuate(AIEngine.GetPlaneType);
	engine_list.RemoveValue(AIAirport.PT_HELICOPTER);
	
	/*  We can't use large planes on small airports. Filter them out if needed.
		In fact if there is at least 1 small airport part of this order, then all large planes
		should be removed.
	*/
	local airport_type = AIAirport.GetAirportType(order_start_tile);
	local airport_type2 = AIAirport.GetAirportType(order_end_tile);
	if (airport_type == AIAirport.AT_SMALL || airport_type == AIAirport.AT_COMMUTER ||
		airport_type2 == AIAirport.AT_SMALL || airport_type2 == AIAirport.AT_COMMUTER) {
		AILog.Info("Removing big planes from selection since we are building for a small airport.");
		engine_list.RemoveValue(AIAirport.PT_BIG_PLANE);
	}
	
	engine_list.Valuate(AIEngine.GetCargoType);
	engine_list.KeepValue(this.passenger_cargo_id);
	
	// Newer versions of OpenTTD allow NewGRFs to set a maximum distance a plane can fly between orders
	// That means we need to make sure planes can fly the distance necessary for our intended order.
	// Since distance is returned squared we need to get the squared distance for our intended order.
	engine_list.Valuate(this.GetMaximumDistance);
	//foreach (eng,x in engine_list) {
	//	AILog.Info("Engine: " + AIEngine.GetName(eng) + ", distance: " + AIEngine.GetMaximumOrderDistance(eng));
	//}
	//local distance_between_stations = AIOrder.GetOrderDistance(null, tile_1, tile_2);
	local distance_between_stations = AIMap.DistanceSquare(tile_1, tile_2);
	engine_list.KeepAboveValue(distance_between_stations);
	// debugging:
	//AILog.Info("squared distance: " + distance_between_stations);
	//foreach (eng,x in engine_list) {
	//	AILog.Info("Engine: " + AIEngine.GetName(eng) + ", distance: " + AIEngine.GetMaximumOrderDistance(eng));
	//}
	////////////

	/* Check if there are any airplanes left. */
	if (engine_list.Count() == 0) {
		// Most likely no aircraft found for the range we wanted.
		AILog.Warning("Couldn't find a suitable aircraft.");
		return ERROR_BUILD_AIRCRAFT_INVALID;
	}

	engine_list.Valuate(AIEngine.GetPrice);
	engine_list.KeepBelowValue(balance < WormMoney.InflationCorrection(AIRCRAFT_LOW_PRICE_CUT) ?
		WormMoney.InflationCorrection(AIRCRAFT_LOW_PRICE) : (balance < WormMoney.InflationCorrection(AIRCRAFT_MEDIUM_PRICE_CUT) ?
		WormMoney.InflationCorrection(AIRCRAFT_MEDIUM_PRICE) : WormMoney.InflationCorrection(AIRCRAFT_HIGH_PRICE)));

	/* Check if there are any airplanes left. */
	if (engine_list.Count() == 0) {
		// Either we don't have enough money to buy an airplane, or there are only very expensive airlanes
		// above our set maximum price.
		/// @todo Maybe instead of a fixed max we need to find the current max price for an airplane?
		AILog.Warning("We either don't have enough money for an airplane or the airplanes are too expensive.");
		return ERROR_NOT_ENOUGH_MONEY;
	}

	//engine_list.Valuate(AIEngine.GetCapacity);
	//engine_list.KeepTop(1);
	engine_list.Valuate(this.GetCostFactor, this.engine_usefulness);
	engine_list.KeepBottom(1);

	/* Make sure that there was a suitable engine found. */
	if (engine_list.Count() == 0) {
		// Most likely no aircraft found for the range we wanted.
		AILog.Warning("Couldn't find a suitable aircraft.");
		return ERROR_BUILD_AIRCRAFT_INVALID;
	}
	
	engine = engine_list.Begin();

	if (!AIEngine.IsValidEngine(engine)) {
		AILog.Warning("Couldn't find a suitable aircraft. Most likely we don't have enough available funds.");
		return ERROR_BUILD_AIRCRAFT_INVALID;
	}
	/* Price of cheapest engine can be more than our bank balance, check for that. */
	eng_price = AIEngine.GetPrice(engine);
	if (eng_price > balance) {
		AILog.Warning("Can't buy aircraft. The cheapest selected aircraft (" + eng_price + ") costs more than our available funds (" + balance + ").");
		return ERROR_NOT_ENOUGH_MONEY;
	}
	local vehicle = AIVehicle.BuildVehicle(hangar, engine);
	if (!AIVehicle.IsValidVehicle(vehicle)) {
		AILog.Warning(AIError.GetLastErrorString());
		AILog.Error("Couldn't build the aircraft: " + AIEngine.GetName(engine));
		return ERROR_BUILD_AIRCRAFT;
	}

	/* Send him on his way */
	/* If this isn't the first vehicle with this order, then make a shared order. */
	local veh_list = AIList();
	veh_list.AddList(this.route_1);
	veh_list.KeepValue(tile_1);
	if (veh_list.Count() > 0) {
		local share_veh = veh_list.Begin();
		AIOrder.ShareOrders(vehicle, share_veh);
		AILog.Info("Not the first vehicle: share orders.");
	}
	else {
		/* First vehicle with these orders. */
		AIOrder.AppendOrder(vehicle, tile_1, AIOrder.OF_FULL_LOAD_ANY);
		AIOrder.AppendOrder(vehicle, tile_2, AIOrder.OF_FULL_LOAD_ANY);
		AILog.Info("First vehicle: set orders.");
	}
	/* If vehicle should be started at another tile than tile_1 then skip to that order. */
	/* Currently always assumes it is tile_2 and that that is the second order, thus 1. */
	if (order_start_tile != tile_1) {
		AILog.Info("Order: skipping to other tile.");
		AIOrder.SkipToOrder(vehicle, 1);
	}
	
	/* When breakdowns are on add go to depot orders on every airport.
	   Ignore this when we added aircraft to shared orders. */
	if ((veh_list.Count() == 0) && (AIGameSettings.GetValue("difficulty.vehicle_breakdowns") > 0)) {
		/* Get the hangar tiles of both airports. */
		local Depot_Airport_1 = AIAirport.GetHangarOfAirport(tile_1);
		local Depot_Airport_2 = AIAirport.GetHangarOfAirport(tile_2);
		/* Add the depot orders: only go there if service is needed. */
		if (!AIOrder.InsertOrder(vehicle, 1, Depot_Airport_2, AIOrder.OF_SERVICE_IF_NEEDED ))
			{ AILog.Warning("Failed to insert go to depot order!"); }
		if (!AIOrder.InsertOrder(vehicle, 3, Depot_Airport_1, AIOrder.OF_SERVICE_IF_NEEDED ))
			{ AILog.Warning("Failed to insert go to depot order!"); }
	}
	
	AIVehicle.StartStopVehicle(vehicle);
	this.distance_of_route.rawset(vehicle, AIMap.DistanceManhattan(tile_1, tile_2));
	this.route_1.AddItem(vehicle, tile_1);
	this.route_2.AddItem(vehicle, tile_2);

	AILog.Info("Finished building aircraft " + AIVehicle.GetName(vehicle) + ", type: " + 
		AIEngine.GetName(engine) + ", price: " + eng_price );
	AILog.Info("Yearly running costs: " + AIEngine.GetRunningCost(engine) + ",  capacity: " + 
		AIEngine.GetCapacity(engine) + ", Maximum speed: " + AIEngine.GetMaxSpeed(engine) +
		", Maximum distance: " + AIEngine.GetMaximumOrderDistance(engine));

	return ALL_OK;
}

/**
 * Find a suitable spot for an airport, walking all towns hoping to find one.
 * When a town is used, it is marked as such and not re-used.
 * @param airport_type The type of airport we want to build.
 * @param center_tile The tile around which we will search for a spot for the airport.
 * @return tile where we can build the airport or an error code.
 */
function WormAirManager::FindSuitableAirportSpot(airport_type, center_tile)
{
	local airport_x, airport_y, airport_rad;

	airport_x = AIAirport.GetAirportWidth(airport_type);
	airport_y = AIAirport.GetAirportHeight(airport_type);
	airport_rad = AIAirport.GetAirportCoverageRadius(airport_type);

	local town_list = AITownList();
	/* Remove all the towns that already have an airport. */
	town_list.RemoveList(this.towns_used);
	/* Remove all the towns where we already tried to build an airport. */
	town_list.RemoveList(this.towns_blacklist);

	town_list.Valuate(AITown.GetPopulation);
	town_list.KeepAboveValue(AIController.GetSetting("min_town_size"));
	/* Keep the best 20, if we can't find 2 stations in there, just leave it anyway */
	/* Original value was 10. We increase it to 20 to make it more likely we will find
	   a town in case there are a lot of unsuitable locations. */
	town_list.KeepTop(20);
	town_list.Valuate(AIBase.RandItem);
	
	/* DEBUG
	DebugListTowns(town_list);
	*/

	/* Now find 2 suitable towns */
	/* First compute distance limits outside the loop. */
	local min_distance_squared = AIController.GetSetting("min_airport_distance") * AIController.GetSetting("min_airport_distance");
	local max_distance_squared = AIController.GetSetting("max_airport_distance") * AIController.GetSetting("max_airport_distance");
	for (local town = town_list.Begin(); !town_list.IsEnd(); town = town_list.Next()) {
		/* Don't make this a CPU hog */
		AIController.Sleep(1);

		local tile = AITown.GetLocation(town);

		/* Create a grid around the core of the town and see if we can find a spot for an airport .*/
		local list = AITileList();
		/* Take into account that towns grow larger over time. A constant value of 15 may not be
		 * enough for large towns to get outside the building. Inspired by AIAI which uses 100 insted of 75.
		 */
		local range = WormMath.Sqrt(AITown.GetPopulation(town)/75) + 15;

		/* Safely add a square rectangle taking care of border tiles. */
		WormTiles.SafeAddSquare(list, tile, range);
		/* Remove all tiles where an airport can't be built and finally keep the best value. */
		list.Valuate(AITile.IsBuildableRectangle, airport_x, airport_y);
		list.KeepValue(1);

		/* Check if we need to consider the distance to another tile. */
		if (center_tile != 0) {
			/* If we have a tile defined, check to see if it's within the minimum and maximum allowed. */
			list.Valuate(AITile.GetDistanceSquareToTile, center_tile);
			/* Keep above minimum distance. */
			list.KeepAboveValue(min_distance_squared);
			/* Keep below maximum distance. */
			list.KeepBelowValue(max_distance_squared);
			/// @todo In early games with low maximum speeds we may need to adjust maximum and
			/// maybe even minimum distance to get a round trip within a year.
		}

		/* Sort on acceptance, remove places that don't have acceptance */
		list.Valuate(AITile.GetCargoAcceptance, this.passenger_cargo_id, airport_x, airport_y, airport_rad);
		list.RemoveBelowValue(this.acceptance_limit);
		
		/* debug off
		AILog.Info("DEBUG tile list count: " + list.Count());
		for (local t = list.Begin(); !list.IsEnd(); t = list.Next()) {
			AILog.Info("DEBUG Town: " + AITown.GetName(town) + ", Tile: " + WormStrings.WriteTile(t) +
				", Passenger Acceptance: " + list.GetValue(t));
		} */

		/* Couldn't find a suitable place for this town, skip to the next */
		if (list.Count() == 0) {
			/* Add town to blacklist for a while. */
			towns_blacklist.AddItem(town, AIDate.GetCurrentDate()+500);
			continue;
		}

		/* Walk all the tiles and see if we can build the airport at all */
		{
			local test = AITestMode();
			local good_tile = 0;

			for (tile = list.Begin(); !list.IsEnd(); tile = list.Next()) {
				AIController.Sleep(1);
				if (!AIAirport.BuildAirport(tile, airport_type, AIStation.STATION_NEW)) continue;
				good_tile = tile;
				break;
			}

			/* Did we find a place to build the airport on? */
			if (good_tile == 0) {
				/* Add town to blacklist for a while. */
				towns_blacklist.AddItem(town, AIDate.GetCurrentDate()+500);
				continue;
			}
		}

		AILog.Info("Found a good spot for an airport in " + AITown.GetName(town) + " (id: "+ town + 
			", tile " + WormStrings.WriteTile(tile) + ", acceptance: " + list.GetValue(tile) + ").");

		/* Mark the town as used, so we don't use it again */
		this.towns_used.AddItem(town, tile);

		return tile;
	}

	local ret = 0;
	if (this.acceptance_limit > 25) {
		this.acceptance_limit -= 25;
		ret = ERROR_FIND_AIRPORT_ACCEPTANCE;
		AILog.Info("Lowering acceptance limit for suitable airports to " + this.acceptance_limit );
	}
	else {
		// Maybe remove this? Minimum of 25 seems low enough.
		//this.acceptance_limit = 10;
		ret = ERROR_FIND_AIRPORT_FINAL;
	}
	AILog.Info("Couldn't find a suitable town to build an airport in");
	return ret;
}

/**
 * Send a vehicle to depot to be sold when it arrives.
 * @param vehicle The vehicle id of the vehicle to be sold.
 * @param sell_reason The reason for selling. Valid reasons are
 * @ref VEH_OLD_AGE, @ref VEH_LOW_PROFIT, @ref VEH_STATION_REMOVAL
 */
function WormAirManager::SendToDepotForSelling(vehicle,sell_reason)
{
	/* Send the vehicle to depot if we didn't do so yet */
	if (!vehicle_to_depot.rawin(vehicle) || vehicle_to_depot.rawget(vehicle) != true) {
		local info_text = "--> Sending " + AIVehicle.GetName(vehicle) + " (id: " + vehicle + 
			") to depot because of ";
		switch(sell_reason) {
			case VEH_OLD_AGE: {
				info_text += "old age: " +  WormStrings.GetAgeString(AIVehicle.GetAge(vehicle)) + " / " + 
					WormStrings.GetAgeString(AIVehicle.GetMaxAge(vehicle));
			} break;
			case VEH_LOW_PROFIT: {
				info_text += "low profits: " + AIVehicle.GetProfitLastYear(vehicle) + " / " + 
					AIVehicle.GetProfitThisYear(vehicle);
			} break;
			case VEH_STATION_REMOVAL: {
				info_text += "removal of station";
			} break;
		}
		AILog.Info(info_text);
		/* Send it to depot. */
		/* Make also sure the vehicle isn't already stopped in depot while not being in our to depot
		   list. This can happen after loading a saved game because we don't save our list of
		   vehicles that get sent to depot. */
		if (!AIVehicle.IsStoppedInDepot(vehicle) && !AIVehicle.SendVehicleToDepot(vehicle))
		{
			AILog.Warning(AIError.GetLastErrorString());
			AILog.Warning("Failed to send vehicle " + AIVehicle.GetName(vehicle) + " to depot!");
			// Maybe the vehicle needs to be reversed to find a depot
			AIVehicle.ReverseVehicle(vehicle);
			AIController.Sleep(75);
			if (!AIVehicle.SendVehicleToDepot(vehicle)) return;
		}
		/* Add it to our list of vehicles that were sent to depot. */
		vehicle_to_depot.rawset(vehicle, true);
	}
}

/**
 * Remove a vehicle from our route lists and to depot list.
 * @note If this is the last vehicle serving a certain route then after selling
 * the vehicle we will also sell the airports.
 * @param vehicle The vehicle id that should be removed from the lists.
 */
function WormAirManager::RemoveVehicleFromLists(vehicle)
{
	/* Check if we are the last one serving those airports; else sell the airports */
	/* Since the cause of removing vehicles can now also be a failed upgrade of airports,
	   it's possible that one of the two airports is invalid and thus check that we get
	   a list for a valid station. */
	local station_id = AIStation.GetStationID(this.route_1.GetValue(vehicle));
	if (!AIStation.IsValidStation(station_id)) {
		AILog.Info("First station of route invalid. Using second station to get vehicle list.");
		station_id = AIStation.GetStationID(this.route_2.GetValue(vehicle));
	}
	local veh_list = AIVehicleList_Station(station_id);
	if (veh_list.Count() == 0) {
		local t1 = route_1.GetValue(vehicle);
		local t2 = route_2.GetValue(vehicle);
		this.SellAirports(t1, t2);
	}
	/* Remove the aircraft from the routes. */
	route_1.RemoveItem(vehicle);
	route_2.RemoveItem(vehicle);
	/* Remove aircraft from our to_depot list. */
	vehicle_to_depot.rawdelete(vehicle);
}

/**
 * Sell the vehicle provided it's in depot. If it's not yet in depot it will fail silently.
 * @param vehicle The id of the vehicle that should be sold.
 */
function WormAirManager::SellVehicleInDepot(vehicle)
{
	// Make sure vehicle occurs in vehicle_to_depot
	if ((vehicle_to_depot.rawin(vehicle) && vehicle_to_depot.rawget(vehicle) == true)) {
		local veh_name = AIVehicle.GetName(vehicle);
		// Try to sell the vehicle
		if (AIVehicle.SellVehicle(vehicle)) {
			AILog.Info("--> Sold " + veh_name + " (id: " + vehicle + ").");
			RemoveVehicleFromLists(vehicle)
		}
		else {
			/* Since vehicle not yet being in depot is an expected error we
			   won't show a log message for that. */
			local last_error = AIError.GetLastError();
			if (last_error == AIVehicle.ERR_VEHICLE_IS_DESTROYED ||
				last_error == AIError.ERR_PRECONDITION_FAILED) {
				/* Vehicle destroyed so will never arrive in depot. Delete it from our lists. */
				AILog.Info("--> Aircraft " + veh_name + " was destroyed.");
				RemoveVehicleFromLists(vehicle);
			}
			else if (last_error != AIVehicle.ERR_VEHICLE_NOT_IN_DEPOT) {
				AILog.Warning(AIError.GetLastErrorString());
				AILog.Warning("Failed to sell vehicle " + AIVehicle.GetName(vehicle));
			}
			else {
				/* Vehicle not yet in depot. Check to see if this is a "lost" vehicle.
					This can happen when the depot/airport a vehicle to be sold is going
					to is destroyed because of a failed upgrade. If this is the case then
					send the vehicle to the depot of the airport at the other end of the
					route. */
				if (!IsValidFirstStation(vehicle) ||
					!IsValidLastStation(vehicle)) {
					/* Either first or last station is not valid. Testing for IsGotoDepotOrder
						doesn't work well since we can have a normal maintenance in depot order too. */
					if ((AIOrder.GetOrderFlags(vehicle, AIOrder.ORDER_CURRENT) & AIOrder.OF_STOP_IN_DEPOT) !=
						AIOrder.OF_STOP_IN_DEPOT) {
						/* Only send to depot if that is not it's current order otherwise
							the go to depot order will be cancelled. */
						AIVehicle.SendVehicleToDepot(vehicle);
						AILog.Warning("Vehicle " + veh_name + " on the way to depot was lost. Sent it to depot again!");
					}
				}
			}
		}
	}
}

/*
 * Sell all vehicles in depot that are marked to be sold.
 */
function WormAirManager::SellVehiclesInDepot()
{
	AILog.Info("- Check for vehicles waiting in depot to be sold.")
	// i = vehicle id, v = boolean, always true currently
	foreach( i,v in vehicle_to_depot) {
		SellVehicleInDepot(i);
	}
}

/**
 * Check all vehicles for being old or needing upgrading to a newer type.
 * It will send all vehicles that are non optimal to depot for selling.
 */
function WormAirManager::ManageVehicleRenewal()
{
	AILog.Info("- Check for vehicles that are old.")
	local list = AIVehicleList();
	/* We check only aircraft here. */
	list.Valuate(AIVehicle.GetVehicleType);
	list.KeepValue(AIVehicle.VT_AIR);
	list.Valuate(AIVehicle.GetAgeLeft);
	/* Keep vehicles whose age is below the limit we set. */
	list.KeepBelowValue(VEHICLE_AGE_LEFT_LIMIT);
	/* Send them all to depot to be sold. */
	for (local veh = list.Begin(); !list.IsEnd(); veh = list.Next()) {
		SendToDepotForSelling(veh, VEH_OLD_AGE);
	}
}

/**
 * Check for airports that don't have any vehicles anymore and delete them.
 */
function WormAirManager::CheckAirportsWithoutVehicles()
{
	local list = AIStationList(AIStation.STATION_AIRPORT);
	/* Loop over all stations we have. */
	for (local st = list.Begin(); !list.IsEnd(); st = list.Next()) {
		local veh_list = AIVehicleList_Station(st);
		/* If no vehicles go to this station then sell it. */
		if (veh_list.Count() == 0) {
			/* This can happen when on a route with 1 plane the plane crashes.
				or when after building 2 airports it fails to build an aircraft
				due to unknown reasons and then removing one of the airports fails
				due to unknown reasons. A fix that seems to help so far is doing a Sleep(1)
				before removing the airports but just to be sure we check here anyway.
				In that case tile_1 and 2 will be 0 although there still is a station. */
			local st_tile = AIStation.GetLocation(st);
			/* Don't remove a route that's waiting for airplanes until we have enough money. */
			if ((!route_without_aircraft) || ((st_tile != incomplete_route_tile1) && (st_tile != incomplete_route_tile2))) {
				AILog.Warning("Airport " + AIStation.GetName(st) + " (" + st + ") has no vehicles using it.");
				AILog.Info("Removing airport");
				local st_town = this.GetTownFromStationTile(st_tile);
				this.RemoveAirport(st_tile);
				this.towns_used.RemoveValue(st_tile);
				/* Add town to blacklist for a while. */
				if (st_town != null)
					towns_blacklist.AddItem(st_town, AIDate.GetCurrentDate()+1500);
			}
			else {
				AILog.Info("Not removing airport " + AIStation.GetName(st) + ". We are waiting for money to buy airplanes.");
			}
		}
	}
}

/**
 * Manage air routes:
 * ------------------
 * - Checks for airports without vehicles.
 * - Send unprofitable aircraft to depot for selling.
 * - Add aircraft to routes that have a lot of waiting cargo.
 * @return Error code if something went wrong or ok.
 * @todo Refactor the parts of this function into separate functions.
 */
function WormAirManager::ManageAirRoutes()
{
	/// @todo
	/// 1. Make groups for each route
	/// 2. When we have max aircraft/airports:
	///  - Evaluate total profit per group, remove bad groups/airports or reduce # planes
	///  - Favor bigger/faster aircraft over cost more when high amount waiting passengers
	/// 3. Upgrade aircraft when they are old or when newer ones would be more profitable
	/// 4. Upgrade airports only when it's needed
	/// 5. Check reliability when breakdowns are on
	local list = AIVehicleList();
	local low_profit_limit = 0;
	
	/* Show some info about what we are doing */
	AILog.Info(Helper.GetCurrentDateString() + " Managing air routes.");
	
	CheckAirportsWithoutVehicles();
	
	/* We check only aircraft here. */
	list.Valuate(AIVehicle.GetVehicleType);
	list.KeepValue(AIVehicle.VT_AIR);
	
	list.Valuate(AIVehicle.GetAge);
	/* Give the plane at least 2 full years to make a difference, thus check for 3 years old. */
	list.KeepAboveValue(365 * 3);
	list.Valuate(AIVehicle.GetProfitLastYear);

	/* Decide on the best low profit limit at this moment. */
	/// @todo Do this on a per group basis (each route a group).
	/// @todo That way we can decide to not check a group wich was created less than x years ago.
	if ((Vehicle.GetVehicleLimit(AIVehicle.VT_AIR)*95/100) > this.route_1.Count()) {
		/* Since we can still add more planes keep all planes that make at least some profit. */
		/// @todo When maintenance costs are on we should set low profit limit too at least
		/// the yearly costs.
		low_profit_limit = 0;
		list.KeepBelowValue(low_profit_limit);
	}
	else {
		//  extensive computation for low profit limit.
		local list_count = 0;
		local list_copy = AIList();
		// Set default low yearly profit
		low_profit_limit = WormMoney.InflationCorrection(BAD_YEARLY_PROFIT);
		list_count = list.Count();
		// We need a copy of list before cutting off low_profit
		list_copy.AddList(list);
		list.KeepBelowValue(low_profit_limit);
		if (list.Count() == 0) {
			// All profits are above our current low_profit_limit
			// Get vehicle with last years highest profit
			// We need to get the vehicle list again because our other list has removed
			// vehicles younger than 3 years, we want the absolute high profit of all vehicles
			local highest = AIVehicleList();
			/* We check only aircraft here. */
			highest.Valuate(AIVehicle.GetVehicleType);
			highest.KeepValue(AIVehicle.VT_AIR);
			highest.Valuate(AIVehicle.GetProfitLastYear);
			highest.KeepTop(1);
			local v = highest.Begin();
			local high_profit = highest.GetValue(v);
			// get profits below 20% of that
			low_profit_limit = high_profit * 3 / 10; // TESTING: 30%
			// Copy the list_copy back to list which at this point is (should be) empty.
			list.AddList(list_copy);
			// Apparently need to use Valuate again on profit for it to work
			list.Valuate(AIVehicle.GetProfitLastYear);
			list.KeepBelowValue(low_profit_limit);
			// DEBUG:
			//foreach (i,v in list) {
			//	AILog.Info("Vehicle " + i + " has profit: " + v);
			//}
			AILog.Warning("Computed low_profit_limit: " + low_profit_limit + " (highest profit: " +
				high_profit + "), number below limit: " + list.Count());
		}
		else if (list_count == 0) {
			AILog.Info("All aircraft younger than 3 years: recomputing low_profit_limit not needed.");
		}
		else {
			AILog.Warning("There are " + list.Count() + " aircraft below last years bad yearly profit limit.");
		}
	}

	/// @todo Don't sell all aircraft from the same route all at once, try selling 1 per year?
	for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
		/* Profit last year and this year bad? Let's sell the vehicle */
		SendToDepotForSelling(i, VEH_LOW_PROFIT);
		/* Sell vehicle provided it's in depot. If not we will get it a next time.
		   This line can also be removed probably since we handle selling once a 
		   month anyway. */
		SellVehicleInDepot(i);
	}

	/* Don't try to add planes when we are short on cash */
	if (!WormMoney.HasMoney(WormMoney.InflationCorrection(AIRCRAFT_LOW_PRICE))) return ERROR_NOT_ENOUGH_MONEY;
	else if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) <= this.route_1.Count()) {
		// No sense building plane if we already have the max (or more because amount can be changed in game)
		AILog.Info("We already have the maximum number of aircraft. No need to check if we should add more planes.");
		return ERROR_MAX_AIRCRAFT;
	}

	/* Don't check if routes need extra airplanes when there's an unfinished route without planes. */
	if (route_without_aircraft) {
		return ALL_OK;
	}	

	list = AIStationList(AIStation.STATION_AIRPORT);
	list.Valuate(AIStation.GetCargoWaiting, this.passenger_cargo_id);
	list.KeepAboveValue(AIRPORT_CARGO_WAITING_LOW_LIMIT);

	for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
		local list2 = AIVehicleList_Station(i);
		/* No vehicles going to this station, abort and sell */
		if (list2.Count() == 0) {
			if (!route_without_aircraft) {
				/* Should not happen anymore since we called CheckAirportsWithoutVehicles earlier.*/
				AILog.Error("Error: Unexpectedly no vehicles are going to station " + 
					 AIStation.GetName(i) + "!");
			}
			continue;
		};

		/* Find the first vehicle that is going to this station */
		local v = list2.Begin();
		local dist = this.distance_of_route.rawget(v) / 2;
		
		/* Find the id of the other station and then request that stations waiting cargo. */
		local st = this.route_1.GetValue(v);
		if (st == AIStation.GetLocation(i)) {
			// Need route_2 for the station tile of the other one
			st = this.route_2.GetValue(v);
		}
		local s2_id = AIStation.GetStationID(st);
		local s2_waiting = AIStation.GetCargoWaiting(s2_id, this.passenger_cargo_id);

		list2.Valuate(AIVehicle.GetAge);
		list2.KeepBelowValue(dist);
		/* Do not build a new vehicle if we bought a new one in the last DISTANCE / 2 days */
		if (list2.Count() != 0) continue;

		/* Do not build new vehicle if there isn't at least some waiting cargo at the other station too. */
		if  (s2_waiting <= AIRPORT_CARGO_WAITING_LOW_LIMIT-AIRPORT2_WAITING_DIFF) continue;

		/* Do not build more aircraft if there are too many planes waiting to land at both
		   the airports part of this order. */
		if (Airport.GetNumAircraftInAirportQueue(i, false) > 2) continue;
		if (Airport.GetNumAircraftInAirportQueue(s2_id, false) > 2) continue;
		/* Same for when there are too many non stopped aircraft waiting in hangars. */
		if (Airport.GetNumNonStopedAircraftInAirportDepot(i) > 2) continue;
		if (Airport.GetNumNonStopedAircraftInAirportDepot(s2_id) > 2) continue;

		AILog.Info("Station " + AIStation.GetName(i) + "(id: " + i +
			") has a lot of waiting passengers (cargo: " + list.GetValue(i) + ")");
		AILog.Info("Other station: " + AIStation.GetName(s2_id) + " waiting passengers: " + s2_waiting);
		AILog.Info("Going to add a new aircraft for this route.");

		/* Make sure we have enough money */
		WormMoney.GetMoney(WormMoney.InflationCorrection(AIRCRAFT_LOW_PRICE));

		/* Build the aircraft. */
		local ret = this.BuildAircraft(this.route_1.GetValue(v), this.route_2.GetValue(v), 0);
		
		/* If we have a real high amount of waiting cargo/passengers then add 2 planes at once. */
		/* Provided buying the first plane went ok. */
		/* Do not build new vehicle if there isn't at least some waiting cargo at the other station too. */
		if ((ret == ALL_OK) && (AIStation.GetCargoWaiting(i, this.passenger_cargo_id) > AIRPORT_CARGO_WAITING_HIGH_LIMIT) &&
			(s2_waiting > AIRPORT_CARGO_WAITING_HIGH_LIMIT-AIRPORT2_WAITING_DIFF)) {
			AILog.Info(" Building a second aircraft since waiting passengers is very high.");
			/* Make sure we have enough money */
			WormMoney.GetMoney(WormMoney.InflationCorrection(AIRCRAFT_LOW_PRICE));
			/* Build the aircraft. */
			ret = this.BuildAircraft(this.route_1.GetValue(v), this.route_2.GetValue(v), 0);
		}
		return ret;
	}
	AILog.Info(Helper.GetCurrentDateString() + " Finished managing air routes.");
}

/**
 * Remove towns from the blacklist where blacklisting has expired.
 */
function WormAirManager::UpdateBlacklist()
{
	local cur_date = AIDate.GetCurrentDate();
	for (local town = towns_blacklist.Begin(); !towns_blacklist.IsEnd(); town = towns_blacklist.Next()) {
		local expires = towns_blacklist.GetValue(town);
		if (expires < cur_date) {
			towns_blacklist.RemoveItem(town);
			AILog.Info("Removed town " + AITown.GetName(town) + " from blacklist.");
		}
//		else
//			AILog.Info("Town " + AITown.GetName(town) + " is blacklisted until " + Helper.GetDateString(expires) + ".");
	}
}

/**
 * Determine if a station is valid based on the station tile.
 * @param st_tile The tile of the station.
 * @return true if station is valid, otherwise false.
 */
function WormAirManager::IsValidStationFromTile(st_tile)
{
	return AIStation.IsValidStation(AIStation.GetStationID(st_tile));
}

/**
 * Determine if the first station of the route of a vehicle is valid.
 * @param veh Vehicle to determine the validity of the station for.
 * @return true if station is valid, otherwise false.
 */
function WormAirManager::IsValidFirstStation(veh)
{
	return IsValidStationFromTile(this.route_1.GetValue(veh));
}

/**
 * Determine if the last station of the route of a vehicle is valid.
 * @param veh Vehicle to determine the validity of the station for.
 * @return true if station is valid, otherwise false.
 */
function WormAirManager::IsValidLastStation(veh)
{
	return IsValidStationFromTile(this.route_2.GetValue(veh));
}

/**
  * Sells the airports at tile_1 and tile_2. Removes towns from towns_used list too.
  * @param airport_1_tile The tile of the first airport to remove
  * @param airport_2_tile The tile of the other airport to remove
  * @note The airport tiles are allowed to be invalid. Removal will be ignored in that
  * case but the towns_used will be updated.
  */
function WormAirManager::SellAirports(airport_1_tile, airport_2_tile) {
	/* Remove the airports */
	AILog.Info("==> Removing airports " + AIStation.GetName(AIStation.GetStationID(airport_1_tile)) + " and " + 
		AIStation.GetName(AIStation.GetStationID(airport_2_tile)) + " since they are not used anymore");

	/* Since it's possible for one of the airports to be already removed we check for that too. 
		(Because of a failed airport upgrade.) */
	if (AIStation.IsValidStation(AIStation.GetStationID(airport_1_tile)))
		{ this.RemoveAirport(airport_1_tile); }
	if (AIStation.IsValidStation(AIStation.GetStationID(airport_2_tile)))
		{ this.RemoveAirport(airport_2_tile); }
	/* Free the towns_used entries */
	this.towns_used.RemoveValue(airport_1_tile);
	this.towns_used.RemoveValue(airport_2_tile);
	/// @todo Make a list of removed airports/tiles so that we don't build a new airport
	/// in the same spot soon after we have removed it!
}

/** 
 * Callback that handles events. Currently only AIEvent.ET_VEHICLE_CRASHED is handled.
 */
function WormAirManager::HandleEvents()
{
	while (AIEventController.IsEventWaiting()) {
		local e = AIEventController.GetNextEvent();
		switch (e.GetEventType()) {
			case AIEvent.ET_VEHICLE_CRASHED: {
				local ec = AIEventVehicleCrashed.Convert(e);
				local v = ec.GetVehicleID();
				AILog.Warning("We have a crashed aircraft (" + v + "), buying a new one as replacement");
				this.BuildAircraft(this.route_1.GetValue(v), this.route_2.GetValue(v), 0);
				this.route_1.RemoveItem(v);
				this.route_2.RemoveItem(v);
			} break;

			default:
				break;
		}
	}
}

/**
 * Task that evaluates all available aircraft for how suited they are
 * for our purposes. The suitedness values for aircraft which we can use are saved in
 * @ref engine_usefulness.
 * @param clear_warning_shown_flag Whether to clear the @ref no_aircraft_warning_shown flag.
 */
function WormAirManager::EvaluateAircraft(clear_warning_shown_flag) {
	/* Show some info about what we are doing */
	AILog.Info(Helper.GetCurrentDateString() + " Evaluating aircraft.");
	
	if (clear_warning_shown_flag) no_aircraft_warning_shown = false;
	
	local engine_list = AIEngineList(AIVehicle.VT_AIR);
	//engine_list.Valuate(AIEngine.GetPrice);
	//engine_list.KeepBelowValue(balance < AIRCRAFT_LOW_PRICE_CUT ? AIRCRAFT_LOW_PRICE : (balance < AIRCRAFT_MEDIUM_PRICE_CUT ? AIRCRAFT_MEDIUM_PRICE : AIRCRAFT_HIGH_PRICE));

	engine_list.Valuate(AIEngine.GetCargoType);
	engine_list.KeepValue(this.passenger_cargo_id);

	// Only use this one when debugging:
	//engine_list.Valuate(AIEngine.GetCapacity);
	
	// First fill temporary list with our usefulness factors
	local factor_list = AIList();
	// Remember best engine for logging purposes
	local best_engine = null;
	local best_factor = 10000000; // Very high factor so any engine will be below it
	
	foreach(engine, value in engine_list) {
		// From: http://thegrebs.com/irc/openttd/2012/04/20
		// <frosch123>	both AIOrder::GetOrderDistance and AIEngine::GetMaximumOrderDistance() return 
		// squared euclidian distance
		// <frosch123>	so, you can compare them without any conversion
		// <+michi_cc>	krinn: Always use AIOrder::GetOrderDistance to query the distance.You can pass 
		// tiles that either are part of a station or are not, it will automatically calculate the right thing.
		// <+michi_cc>	AIEngine::GetMaximumOrderDistance and AIOrder::GetOrderDistance complement each other, 
		// and you can always use > or < on the returned values without knowing if it is square, manhatten or 
		// whatever that is applicable for the vehicle type.
		// <krinn>	vehlist.Valuate(AIEngine.GetMaximumOrderDistance); + vehlist.KeepValue(distance*distance)
		local _ayear = 24*365;	// 24 hours * 365 days
		local _eval_distance = 50000;	// assumed distance for passengers to travel
		if (AIEngine.IsValidEngine(engine)) {
			local speed = AIEngine.GetMaxSpeed(engine);
			local cap = AIEngine.GetCapacity(engine);
			local ycost = AIEngine.GetRunningCost(engine);
			//local costfactor = ycost / (speed * cap);
			local distance_per_year = speed * _ayear;
			local pass_per_year = cap * distance_per_year / _eval_distance;
			// No real values thus to get a sensible int value multiply with 100
			local cost_per_pass = (ycost * 100) / pass_per_year;
			if (cost_per_pass < best_factor) {
				best_factor = cost_per_pass;
				best_engine = engine;
			}
			if (AIController.GetSetting("debug_show_lists") == 1) {
				// Show info about evaluated engines
				AILog.Info("Engine: " + AIEngine.GetName(engine) + ", price: " + AIEngine.GetPrice(engine) +
					", yearly running costs: " + AIEngine.GetRunningCost(engine));
				AILog.Info( "    Capacity: " + AIEngine.GetCapacity(engine) + ", Maximum speed: " + 
					AIEngine.GetMaxSpeed(engine) + ", Maximum distance: " + AIEngine.GetMaximumOrderDistance(engine) +
					", type: " + WormStrings.GetAircraftTypeAsText(engine));
				AILog.Warning("    Aircraft usefulness factors d: " + distance_per_year + ", p: " + pass_per_year +
					", pass cost factor: " + cost_per_pass);
			}
			// Add the cost factor to our temporary list
			factor_list.AddItem(engine,cost_per_pass);
		}
	}
	this.engine_usefulness.Clear();
	this.engine_usefulness.AddList(factor_list);
	AILog.Info("Evaluated engines count: " + this.engine_usefulness.Count());
	if (!best_engine) {
		AILog.Warning("Best overall engine: <no engine available>");
	}
	else {
		AILog.Warning("Best overall engine: " + AIEngine.GetName(best_engine) + ", cost factor: " + best_factor);
	}
}

/**
 * Build the company headquarters if there isn't one yet.
 * @note Adapted from the version in AdmiralAI.
 */ 
function WormAirManager::BuildHQ()
{
	/* Make sure we don't have a company headquarter yet. */
	if (AICompany.GetCompanyHQ(AICompany.COMPANY_SELF) != AIMap.TILE_INVALID) return;
	
	/* Check first if we have a minimum amount of money. */
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < WormMoney.InflationCorrection(50000)) return;

	AILog.Info("Trying to find a spot to build our headquarters.");

	/* We want it near one of our stations so get the list of stations we have. */
	if (this.towns_used) {
		/* Loop over our towns with a station until we have built our hq. */
		for (local t = towns_used.Begin(); !towns_used.IsEnd(); t = towns_used.Next()) {
			local st_tile = towns_used.GetValue(t);
			local st_id = AIStation.GetStationID(st_tile);
			if (AIStation.IsValidStation(st_id)) {
				local airport_type = AIAirport.GetAirportType(AIStation.GetLocation(st_id));
				local airport_width = AIAirport.GetAirportWidth(airport_type);
				local airport_height = AIAirport.GetAirportHeight(airport_type);
				local tiles = AITileList();
				/* Get the tiles around this station. */
				WormTiles.SafeAddRectangle(tiles, AIStation.GetLocation(st_id), 4, 4, 3 + airport_width, 3 + airport_height);
				tiles.Valuate(AIMap.DistanceManhattan, AIStation.GetLocation(st_id));
				tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
				/* Try to build our hq on one of these tiles. */
				foreach (tile, distance in tiles) {
					if (AICompany.BuildCompanyHQ(tile)) {
						AILog.Warning("We built our headquarters near " + AITown.GetName(t) + 
						  ", station " + AIStation.GetName(st_id) + ".");
						return;
					}
				}
			}
		}
	}
}

/**
 * Build statues in towns where we have a station as long as we have a reasonable amount of money.
 * We limit the amount of statues we build at any one time.
 */
function WormAirManager::BuildStatues()
{
	local build_count = 0; // Amount of statues built.
	/* Only think of building statues if we have no outstanding loan. */
	if (AICompany.GetLoanAmount() == 0) {
		local build_max = MAX_STATUES_BUILD_COUNT;
		/* In case we are wealthy increase the max amount to build. */
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 5*WormMoney.InflationCorrection(MINIMUM_BALANCE_BUILD_STATUE)) {
			build_max *= 4;
		}
		for (local t = towns_used.Begin(); !towns_used.IsEnd(); t = towns_used.Next()) {
			/* Ignore towns that already have a statue. */
			if (AITown.HasStatue(t)) continue;
			/* Only build a statue if we have a reasonable amount of money available. */
			if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < WormMoney.InflationCorrection(MINIMUM_BALANCE_BUILD_STATUE)) return;
			if (AITown.PerformTownAction(t, AITown.TOWN_ACTION_BUILD_STATUE)) {
				AILog.Info("We built a statue in " + AITown.GetName(t) + ".");
				build_count += 1;
				/* Don't build more than a certain maximum number of statues at one time. */
				if (build_count == build_max) return;
			}
		}
	}
}

/**
 * Valuator function to get the cost factor of an aircraft.
 * @param engine The engine id of the aircraft.
 * @param costfactor_list The list (usually @ref engine_usefulness) that holds the cost factors.
 * @return The cost factor.
 */
function WormAirManager::GetCostFactor(engine, costfactor_list) {
	// For some reason we can't access this.engine_usefulness from inside the Valuate function,
	// thus we add that as a parameter
	//AILog.Info("usefulness list count: " + costfactor_list.Count());
	if (costfactor_list == null) {
		return 0;
	}
	else {
		return costfactor_list.GetValue(engine);
		//return AIEngine.GetCapacity(engine);
	}
}

function WormAirManager::AfterLoading()
{
	if (AIController.GetSetting("debug_show_lists") == 1) {
		/* Debugging info */
		DebugListTownsUsed();
	}
	AILog.Info("Updating route table distances.");
	// We need to redo distance_of_route table
	foreach( veh, tile_1 in route_1) {
		local tile_2 = route_2.GetValue(veh);
		if (AIController.GetSetting("debug_show_lists") == 1) {
			AILog.Info("Vehicle: " + veh + " tile1: " + WormStrings.WriteTile(tile_1) +
			  " tile2: " + WormStrings.WriteTile(tile_2));
			AILog.Info("Distance: " + AIMap.DistanceManhattan(tile_1, tile_2));
		}
		this.distance_of_route.rawset(veh, AIMap.DistanceManhattan(tile_1, tile_2));
	}
	if (AIController.GetSetting("debug_show_lists") == 1) {
		/* Debugging info */
		DebugListRouteInfo();
	}
}

