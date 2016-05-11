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
	/** Building stages, needed to recover a savegame. */
	static BS_NOTHING		= 0;
	static BS_BUILDING		= 1;
	static BS_REMOVING		= 2;
	static BS_ELECTRIFYING	= 3;

	/** Reasons to send a vehicle to a depot. */
	static TD_SELL = 1;
	static TD_REPLACE = 2;
	static TD_ATTACH_WAGONS = 3;

	/* Variables used by WormRailManager */
	/* 1. Variables that will be saved in a savegame. (TODO) */
	routes = null;						///< An array containing all our routes
	groups = null;						///< The list of vehicle groups
	serviced = null;					///< Industry/town - cargo pairs already serviced
	railbridges = null;					///< The list of rail bridges
	engine_blacklist = null;			///< The blacklist of train engines
	buildingstage = null;				///< The current building stage
	lastroute = null;					///< The date the last route was built
	removelist = null;					///< An array used to continue rail removal and electrification
	todepotlist = null;					///< A list of vehicles heading for the depot
	route_without_trains = -1;			///< Group number or -1 of unfinished route that needs trains added
	last_route = null;					///< route info table of last completed route. Needed if we still need to buy trains for this route.

	/* 2. Variables that will NOT be saved. */
	_current_railtype = 0;				///< The railtype we are currently using.
	_planner = null;					///< The route planner class object.

	/** Create an instance of WormRailManager and initialize our variables. */
	constructor()
	{
		routes = [];
		removelist = [];
		groups = AIList();
		serviced = AIList();
		railbridges = AITileList();
		engine_blacklist = AIList();
		todepotlist = AIList();
		_current_railtype = AIRail.RAILTYPE_INVALID;
		_planner = WormPlanner(this);
		route_without_trains = -1;
		last_route = null;
		AILog.Info("[RailManager initialized]");
	}
	
	/**
	 * Set the name of a vehicle group.
	 * @param group The GroupID of the group.
	 * @param crg The cargo transported.
	 * @param stasrc The source station.
	 * @note Taken from SimpleAI.
	 * @todo Move to a different unit, should be accessible from other managers too.
	 */
	static function SetGroupName(group, crg, stasrc);

	/**
	 * Checks whether a given rectangle is within the influence of a given town.
	 * @param tile The topmost tile of the rectangle.
	 * @param town_id The TownID of the town to be checked.
	 * @param width The width of the rectangle.
	 * @param height The height of the rectangle.
	 * @return True if the rectangle is within the influence of the town.
	 * @todo Needs to be moved to a different unit. (Town?)
	 * @note Taken from SimpleAI.
	 */
	static function IsRectangleWithinTownInfluence(tile, town_id, width, height);

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

	/**
	 * Main function for building a railway which decides all the details.
	 */
	function BuildRailway();

	/**
	 * Register the new route into the database.
	 * @param route_data A WormRoute class object containing info about the route.
	 * @param station_data A WormStation class object containing info about the station.
	 * @param vehtype The type of vehicle using this route. Currently always VT_RAIL.
	 * @param group The vehicle group for the vehicles using this route.
	 * @return The new route registered.
	 */
	function RegisterRoute(route_data, station_data, vehtype, group);

	/**
	 * Checks all routes. Empty routes are removed, new vehicles are added if needed, old vehicles are replaced,
	 * vehicles are restarted if sitting in the depot for no reason, rails are electrified, short trains are lengthened.
	 */
	function CheckRoutes();

	/**
	 * Checks ungrouped vehicles. Under normal conditions all vehicles should be grouped.
	 */
	function CheckDefaultGroup();

	/**
	 * Check if we should add another train to the specified group.
	 * @param route The route info table.
	 * @param vehicle_count The current number of vehicles in this group.
	 * @param first_vehicle The first vehicle in this group.
	 * @return True if we added a train, otherwise false.
	 */
	function CheckAddTrainToGroup(route, vehicle_count, first_vehicle);

	/**
	 * Select optimal wagon and train engine for the specified route and buy it if possible.
	 * @param route The route info table.
	 * @return True if we added a train, otherwise false.
	 */
	function SelectAndAddTrain(route);

	/**
	 * Adds a new vehicle to an existing route.
	 * @param route The route to which the new vehicle will be added.
	 * @param mainvehicle An already existing vehicle on the route to share orders with.
	 * @param engine The EngineID of the new vehicle. In case of trains it is the EngineID of the locomotive.
	 * @param wagon The EngineID of the train wagons.
	 * @return True if the action succeeded.
	 */
	function AddVehicle(route, mainvehicle, engine, wagon);

	/**
	 * Replaces an old vehicle with a newer model if it is already in the depot.
	 * @param vehicle The vehicle to be replaced.
	 */
	function ReplaceVehicle(vehicle);
	
	/**
	 * Handle a vehicle that is stopped in depot for selling, replacement or attaching wagons. 
	 * @param vehicle The vehicle stopped in depot.
	 */
	function HandleVehicleInDepot(vehicle);

	/**
	 * Check train profits and send unprofitable ones to depot to be sold. 
	 */
	function CheckTrainProfits();

	/**
	 * Check train profits and send unprofitable ones to depot to be sold. 
	 * @param vehicle The vehicle that should be sent to depot to be sold.
	 */
	function SendTrainToDepotForSelling(vehicle);


	/**
	 * Save all data that WormRailManager needs in table. 
	 * @param table The table to store the data in.
	 * @pre table should be non null.
	 */
	function SaveData(table);

	/**
	 * Load all data that WormRailManager from the table.
	 * @param table The table that has all the data.
	 * @param worm_save_version WormAI save data version.
	 * @pre table should be non null.
	 */
	function LoadData(table, worm_save_version);
}

function WormRailManager::SetGroupName(group, crg, stasrc)
{
	local groupname = AICargo.GetCargoLabel(crg) + " - " + AIStation.GetName(stasrc);
	if (groupname.len() > 30) groupname = groupname.slice(0, 30);
	if (!AIGroup.SetName(group, groupname)) {
		// Shorten the name if it is too long (Unicode character problems)
		while (AIError.GetLastError() == AIError.ERR_PRECONDITION_STRING_TOO_LONG) {
			groupname = groupname.slice(0, groupname.len() - 1);
			AIGroup.SetName(group, groupname);
		}
	}
}

function WormRailManager::IsRectangleWithinTownInfluence(tile, town_id, width, height)
{
	if (width <= 1 && height <= 1) return AITile.IsWithinTownInfluence(tile, town_id);
	local offsetX = AIMap.GetTileIndex(width - 1, 0);
	local offsetY = AIMap.GetTileIndex(0, height - 1);
	return AITile.IsWithinTownInfluence(tile, town_id) ||
				 AITile.IsWithinTownInfluence(tile + offsetX + offsetY, town_id) ||
				 AITile.IsWithinTownInfluence(tile + offsetX, town_id) ||
				 AITile.IsWithinTownInfluence(tile + offsetY, town_id);
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

function WormRailManager::BuildRailway()
{
	/* Don't try to build a new railway if there is an unfinished route without trains. */
	if (route_without_trains > -1) {
		local result = SelectAndAddTrain(last_route);
		if (result) {
			route_without_trains = -1;
			AILog.Warning("Train for last route got built. Route finished.");
		}
		else
			AILog.Warning("Still can't add a train to the last route due to lack of money.");
		return result;
	}
	
	/* Plan which route with which cargo we are going to build. */
	if (!_planner.PlanRailRoute()) return false;

	buildingstage = BS_NOTHING;

	/* Show info about chosen route. */
	local srcname, dstname = null;
	local subsidy = "";
	if (_planner.route.SourceIsTown) srcname = AITown.GetName(_planner.route.SourceID);
	else srcname = AIIndustry.GetName(_planner.route.SourceID);
	if (_planner.route.DestIsTown) dstname = AITown.GetName(_planner.route.DestID);
	else dstname = AIIndustry.GetName(_planner.route.DestID);
	if (_planner.route.IsSubsidy) subsidy = " [going for subsidy]";
	AILog.Info(AICargo.GetCargoLabel(_planner.route.Cargo) + " from " + srcname + " to " + dstname + subsidy);
	
	/* Choose wagon and train engine. */
	local wagon = WormRailBuilder.ChooseWagon(_planner.route.Cargo, engine_blacklist);
	if (wagon == null) {
		AILog.Warning("No suitable wagon available!");
		return false;
	} else {
		AILog.Info("Chosen wagon: " + AIEngine.GetName(wagon));
	}

	if (!_planner.route.double) AILog.Info("Using single rail");
	else AILog.Info("Using double rail");
	
	/* Determine the size of the train station. */
	local platform = null;
	/// @todo replace number by a definied constant or variable depending on date and other factors
	if (_planner.route.double || _planner.route.distance_manhattan > 50) platform = 3;
	else platform = 2;

	/* Check if there is a suitable engine available. */
	local engine = WormRailBuilder.ChooseTrainEngine(_planner.route.Cargo,
		_planner.route.distance_manhattan, wagon, platform * 2 - 1, engine_blacklist);
	if (engine == null) {
		AILog.Warning("No suitable train engine available!");
		return false;
	} else {
		AILog.Info("Chosen train engine: " + AIEngine.GetName(engine));
	}

	local trains = null;	// Number of trains to add to this route
	local station_data = WormStation();

	if (!_planner.route.double) {

		/* Single rail */

		trains = 1;
		local start, end = null;

		// Build the source station
		if (WormRailBuilder.BuildSingleRailStation(true, platform, _planner.route, station_data, this)) {
			end = [station_data.frontfront, station_data.stafront];
			buildingstage = BS_BUILDING;
			AILog.Info("New station successfully built: " + AIStation.GetName(station_data.stasrc));
		} else {
			AILog.Warning("Could not build source station at " + srcname);
			return false;
		}
		// Build the destination station
		if (WormRailBuilder.BuildSingleRailStation(false, platform, _planner.route, station_data, this)) {
			start = [station_data.frontfront, station_data.stafront];
			AILog.Info("New station successfully built: " + AIStation.GetName(station_data.stadst));
		} else {
			AILog.Warning("Could not build destination station at " + dstname);
			WormRailBuilder.DeleteRailStation(station_data.stasrc, this);
			buildingstage = BS_NOTHING;
			return false;
		}

		// Build the rail
		if (WormRailBuilder.BuildRail(start, end, railbridges)) {
			AILog.Info("Rail built successfully!");
		} else {
			WormRailBuilder.DeleteRailStation(station_data.stasrc, this);
			WormRailBuilder.DeleteRailStation(station_data.stadst, this);
			buildingstage = BS_NOTHING;
			return false;
		}
	} else {

		/* Double rail */

		trains = 2;
		local start, end = null;
		local temp_ps = null;
		 // Passing lane starting/ending points. SimpleAI has them as class variables but they seem
		 // to be only used here.
		local ps1_entry = null;
		local ps1_exit = null;
		local ps2_entry = null;
		local ps2_exit = null;


		// Build the source station
		if (WormRailBuilder.BuildDoubleRailStation(true, _planner.route, station_data, this)) {
			end = [station_data.morefront, station_data.frontfront];
			buildingstage = BS_BUILDING;
			AILog.Info("New station successfully built: " + AIStation.GetName(station_data.stasrc));
		} else {
			AILog.Warning("Could not build source station at " + srcname);
			return false;
		}

		// Build the destination station
		if (WormRailBuilder.BuildDoubleRailStation(false, _planner.route, station_data, this)) {
			start = [station_data.morefront, station_data.frontfront];
			AILog.Info("New station successfully built: " + AIStation.GetName(station_data.stadst));
		} else {
			AILog.Warning("Could not build destination station at " + dstname);
			WormRailBuilder.DeleteRailStation(station_data.stasrc, this);
			buildingstage = BS_NOTHING;
			return false;
		}

		// Build the first passing lane section
		temp_ps = WormRailBuilder.BuildPassingLaneSection(true, station_data, this);
		if (temp_ps == null) {
			AILog.Warning("Could not build first passing lane section");
			WormRailBuilder.DeleteRailStation(station_data.stasrc, this);
			WormRailBuilder.DeleteRailStation(station_data.stadst, this);
			buildingstage = BS_NOTHING;
			return false;
		} else {
			if (AIMap.DistanceManhattan(end[0], temp_ps[0][0]) < AIMap.DistanceManhattan(end[0], temp_ps[1][0])) {
				ps1_entry = [temp_ps[0][0], temp_ps[0][1]];
				ps1_exit = [temp_ps[1][0], temp_ps[1][1]];
			} else {
				ps1_entry = [temp_ps[1][0], temp_ps[1][1]];
				ps1_exit = [temp_ps[0][0], temp_ps[0][1]];
			}
		}
		// Build the second passing lane section
		temp_ps = WormRailBuilder.BuildPassingLaneSection(false, station_data, this);
		if (temp_ps == null) {
			AILog.Warning("Could not build second passing lane section");
			WormRailBuilder.DeleteRailStation(station_data.stasrc, this);
			WormRailBuilder.DeleteRailStation(station_data.stadst, this);
			WormRailBuilder.RemoveRailLine(ps1_entry[1], this);
			buildingstage = BS_NOTHING;
			return false;
		} else {
			if (AIMap.DistanceManhattan(start[0], temp_ps[0][0]) < AIMap.DistanceManhattan(start[0], temp_ps[1][0])) {
				ps2_entry = [temp_ps[1][0], temp_ps[1][1]];
				ps2_exit = [temp_ps[0][0], temp_ps[0][1]];
			} else {
				ps2_entry = [temp_ps[0][0], temp_ps[0][1]];
				ps2_exit = [temp_ps[1][0], temp_ps[1][1]];
			}
		}
		// Build the rail between the source station and the first passing lane section
		if (WormRailBuilder.BuildRail(ps1_entry, end, railbridges)) {
			AILog.Info("Rail built successfully!");
		} else {
			WormRailBuilder.DeleteRailStation(station_data.stadst, this);
			WormRailBuilder.DeleteRailStation(station_data.stasrc, this);
			WormRailBuilder.RemoveRailLine(ps1_entry[1], this);
			WormRailBuilder.RemoveRailLine(ps2_entry[1], this);
			buildingstage = BS_NOTHING;
			return false;
		}
		// Build the rail between the two passing lane sections
		if (WormRailBuilder.BuildRail(ps2_entry, ps1_exit, railbridges)) {
			AILog.Info("Rail built successfully!");
		} else {
			WormRailBuilder.DeleteRailStation(station_data.stadst, this);
			WormRailBuilder.DeleteRailStation(station_data.stasrc, this);
			WormRailBuilder.RemoveRailLine(ps2_entry[1], this);
			buildingstage = BS_NOTHING;
			return false;
		}
		// Build the rail between the second passing lane section and the destination station
		if (WormRailBuilder.BuildRail(start, ps2_exit, railbridges)) {
			AILog.Info("Rail built successfully!");
		} else {
			WormRailBuilder.DeleteRailStation(station_data.stadst, this);
			WormRailBuilder.DeleteRailStation(station_data.stasrc, this);
			buildingstage = BS_NOTHING;
			return false;
		}
	}
	buildingstage = BS_NOTHING;
	
	// For now always rail here
	local vehtype = AIVehicle.VT_RAIL;

	/* Set up a group for this rail route. */
	local group = AIGroup.CreateGroup(vehtype);
	this.SetGroupName(group, _planner.route.Cargo, station_data.stasrc);
	
	/* Create trains for this route. */
	local build_result = WormRailBuilder.BuildAndStartTrains(trains, 2 * platform - 2, engine, wagon, null, group,
		_planner.route.Cargo, station_data, engine_blacklist);
	
	last_route = WormRailManager.RegisterRoute(_planner.route, station_data, vehtype, group);
	
	// Retry if route was abandoned due to blacklisting
	local vehicles = AIVehicleList_Group(group);
	if (vehicles.Count() == 0 && vehtype == AIVehicle.VT_RAIL) {
		if (build_result == ERROR_BUILD_TRAIN_BLACKLISTED) {
			AILog.Info("The new route may be empty because of blacklisting, retrying...")
			// Choose wagon and locomotive
			local wagon = WormRailBuilder.ChooseWagon(_planner.route.Cargo, engine_blacklist);
			if (wagon == null) {
				AILog.Warning("No suitable wagon available!");
				return false;
			} else {
				AILog.Info("Chosen wagon: " + AIEngine.GetName(wagon));
			}
			local engine = WormRailBuilder.ChooseTrainEngine(_planner.route.Cargo, _planner.route.distance_manhattan, 
				wagon, platform * 2 - 1, engine_blacklist);
			if (engine == null) {
				AILog.Warning("No suitable engine available!");
				return false;
			} else {
				AILog.Info("Chosen engine: " + AIEngine.GetName(engine));
			}
			/* Wormnest: it seems easier to call BuildAndStartTrains again...
			local manager = cManager(root);
			manager.AddVehicle(last_route, null, engine, wagon);
			if (_planner.route.double) manager.AddVehicle(last_route, null, engine, wagon);
			*/
			/// @todo check first if we are below max no. of trains...
			AILog.Info("Trying again to build trains for this route.");
			build_result = WormRailBuilder.BuildAndStartTrains(trains, 2 * platform - 2, engine, wagon, null, group,
				_planner.route.Cargo, station_data, engine_blacklist);
		}
		if (build_result == ERROR_NOT_ENOUGH_MONEY) {
			/* We will try to add trains when we have money. */
			AILog.Warning("We built a new route but couldn't add trains yet due to lack of money.");
			route_without_trains = group;
			return true;
		}
	}
	route_without_trains = -1;
	AILog.Info("New route done!");
	station_data = null;
	
	return true;
}

function WormRailManager::RegisterRoute(route_data, station_data, vehtype, group)
{
	/* Table with info about a completed route. */
	local route = {
		src = null
		dst = null
		stasrc = null
		stadst = null
		homedepot = null
		group = null
		crg = null
		vehtype = null
		railtype = null
		maxvehicles = null
	}
	/// @todo Also save IsSubsidy, ...
	route.src = route_data.SourceID;
	route.dst = route_data.DestID;
	route.stasrc = station_data.stasrc;
	route.stadst = station_data.stadst;
	route.homedepot = station_data.homedepot;
	route.group = group;
	route.crg = route_data.Cargo;
	route.vehtype = vehtype;
	route.railtype = AIRail.GetCurrentRailType();
	switch (vehtype) {
		case AIVehicle.VT_ROAD:
			route.maxvehicles = AIController.GetSetting("max_roadvehs");
			break;
		case AIVehicle.VT_RAIL:
			route.maxvehicles = route_data.double ? 2 : 1;
			break;
		case AIVehicle.VT_AIR:
			route.maxvehicles = 0;
			break;
	}
	routes.push(route);
	serviced.AddItem(route_data.SourceID * 256 + route_data.Cargo, 0);
	groups.AddItem(group, routes.len() - 1);
	lastroute = AIDate.GetCurrentDate();
	return route;
}

function WormRailManager::CheckRoutes()
{
	/* Since routes are used in a loop as index we can not remove them inside this loop.
	 * Thus we store routes to be removed in a temp array. */
	// Now disabled since the order of routes shouldn't change see bottom of this function.
//	local remove_routes = [];
	foreach (idx, route in routes) {
		// Skip deleted routes
		if (route.vehtype == null) continue;
		
		AILog.Info(".... checking route " + idx + ", " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
		local vehicles = AIVehicleList_Group(route.group);

		/* Empty route */
		/// @todo if vehicle count = 0 because we didn't have enough money to buy trains then
		/// @todo we should (try to) add trains or wait until we have more money
		/// @todo Maybe add a status to routes like [nomoneyfortrains, unprofitable, ...]
		if (vehicles.Count() == 0) {
			/// Only remove route if we're not waiting for trains to be added
			if (route_without_trains != route.group) {
				AILog.Info("Removing empty route: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
				route.vehtype = null;
				groups.RemoveItem(route.group);
				AIGroup.DeleteGroup(route.group);
				serviced.RemoveItem(route.src * 256 + route.crg);
				// Connected rails will automatically be removed
				WormRailBuilder.DeleteRailStation(route.stasrc, this);
				WormRailBuilder.DeleteRailStation(route.stadst, this);
				/* route index that should be removed after finishing the foreach loop */
//				remove_routes.append(idx);
			}
			continue;
		}

		/* Electrifying rails */
		if ((AIRail.TrainHasPowerOnRail(route.railtype, AIRail.GetCurrentRailType())) && (route.railtype != AIRail.GetCurrentRailType())) {
			// Check if we can afford it
			if (WormMoney.GetMaxBankBalance() > WormMoney.InflationCorrection(30000)) {
				if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < WormMoney.InflationCorrection(30000)) {
					WormMoney.GetMoney(WormMoney.InflationCorrection(30000), WormMoney.WM_SILENT);
				}
				AILog.Info("Electrifying rail line: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
				route.railtype = AIRail.GetCurrentRailType();
				WormRailBuilder.ElectrifyRail(AIStation.GetLocation(route.stasrc), this);
			}
		}

		/* Adding trains */
		CheckAddTrainToGroup(route, vehicles.Count(), vehicles.Begin());
		/** see above replacement
		if (vehicles.Count() == 1 && route.maxvehicles == 2 && (!AIVehicle.IsStoppedInDepot(vehicles.Begin()))) {
			if (AIVehicle.GetProfitThisYear(vehicles.Begin()) <= 0) continue;
			if (AIStation.GetCargoWaiting(route.stasrc, route.crg) > 150) {
				local railtype = AIRail.GetCurrentRailType();
				AIRail.SetCurrentRailType(route.railtype);
				local wagon = WormRailBuilder.ChooseWagon(route.crg, engine_blacklist);
				if (wagon == null) {
					AIRail.SetCurrentRailType(railtype);
					return false;
				}
				local platform = WormRailBuilder.GetRailStationPlatformLength(route.stasrc);
				local engine = WormRailBuilder.ChooseTrainEngine(route.crg, AIMap.DistanceManhattan(AIStation.GetLocation(route.stasrc), 
					AIStation.GetLocation(route.stadst)), wagon, platform * 2 - 1, engine_blacklist);
				if (engine == null) {
					AIRail.SetCurrentRailType(railtype);
					return false;
				}
				// Check if we can afford it
				if (WormMoney.GetMaxBankBalance() > (WormMoney.GetMinimumCashNeeded() + AIEngine.GetPrice(engine) +
					4 * AIEngine.GetPrice(wagon))) {
					if (WormRailManager.AddVehicle(route, vehicles.Begin(), engine, wagon)) {
						AILog.Info("Added train to route: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
					}
				}
				AIRail.SetCurrentRailType(railtype);
			}
		}
		*/

		/* Replacing old vehicles */
		vehicles.Valuate(AIVehicle.GetAgeLeft);
		vehicles.KeepBelowValue(0);
		foreach (vehicle, dummy in vehicles) {
			if (todepotlist.HasItem(vehicle)) continue;
			local railtype = AIRail.GetCurrentRailType();
			// Choose a new model
			AIRail.SetCurrentRailType(route.railtype);
			local wagon = WormRailBuilder.ChooseWagon(route.crg, engine_blacklist);
			if (wagon == null) continue;
			local platform = WormRailBuilder.GetRailStationPlatformLength(route.stasrc);
			local engine = WormRailBuilder.ChooseTrainEngine(route.crg, AIMap.DistanceManhattan(AIStation.GetLocation(route.stasrc),
				AIStation.GetLocation(route.stadst)), wagon, platform * 2 - 1, engine_blacklist);
			AIRail.SetCurrentRailType(railtype);
			if (engine == null) continue;
			// Replace it only if we can afford it
			if (WormMoney.GetMaxBankBalance() > (WormMoney.GetMinimumCashNeeded() + AIEngine.GetPrice(engine) +
				5 * AIEngine.GetPrice(wagon))) {
				AILog.Info(AIVehicle.GetName(vehicle) + " is getting old, sending it to the depot...");
				/* Make sure it's not stopped in depot yet for some reason. */
				if (!(AIVehicle.GetState(vehicle) == AIVehicle.VS_IN_DEPOT)) {
					if (!AIVehicle.SendVehicleToDepot(vehicle)) {
						// Maybe the train only needs to be reversed to find a depot
						AIVehicle.ReverseVehicle(vehicle);
						AIController.Sleep(75);
						if (!AIVehicle.SendVehicleToDepot(vehicle)) break;
					}
				}
				todepotlist.AddItem(vehicle, TD_REPLACE);
			}
		}

		/* Lengthening short trains */
		vehicles = AIVehicleList_Group(route.group);
		local platform = WormRailBuilder.GetRailStationPlatformLength(route.stasrc);
		foreach (train, dummy in vehicles) {
			if (todepotlist.HasItem(train)) continue;
			// The train should fill its platform
			if (AIVehicle.GetLength(train) < platform * 16 - 7) {
				local railtype = AIRail.GetCurrentRailType();
				AIRail.SetCurrentRailType(route.railtype);
				local wagon = WormRailBuilder.ChooseWagon(route.crg, engine_blacklist);
				if (wagon == null) break;
				// Check if we can afford it
				if (WormMoney.GetMaxBankBalance() > (WormMoney.GetMinimumCashNeeded() + 5 * AIEngine.GetPrice(wagon))) {
					AILog.Info(AIVehicle.GetName(train) + " is short, sending it to the depot to attach more wagons...");
					if (!AIVehicle.SendVehicleToDepot(train)) {
						AIVehicle.ReverseVehicle(train);
						AIController.Sleep(75);
						if (!AIVehicle.SendVehicleToDepot(train)) break;
					}
					todepotlist.AddItem(train, TD_ATTACH_WAGONS);
				}
				AIRail.SetCurrentRailType(railtype);
			}
		}

		/* Checking vehicles in depot */
		/// @todo maybe do this for all trains in one go instead of per group probably more efficient
		//AILog.Info("[DEBUG] Check vehicles in depot...");
		vehicles = AIVehicleList_Group(route.group);
		vehicles.Valuate(AIVehicle.IsStoppedInDepot);
		vehicles.KeepValue(1);
		//if (vehicles.Count() > 0)
		//	AILog.Info("[DEBUG] There are " + vehicles.Count() + " vehicles in depot.");
		foreach (vehicle, dummy in vehicles) {
			// A vehicle has probably been sitting there for ages if its current year/last year profits are both 0, and it's at least 2 months old
			/*
			if (AIVehicle.GetProfitThisYear(vehicle) != 0 || AIVehicle.GetProfitLastYear(vehicle) != 0 || AIVehicle.GetAge(vehicle) < 60) continue;
			if (todepotlist.HasItem(vehicle)) {
				todepotlist.RemoveItem(vehicle);
				AIVehicle.StartStopVehicle(vehicle);
			} else {
				// Sell it if we have no idea how it got there
				AILog.Warning("Sold " + AIVehicle.GetName(vehicle) + ", as it has been sitting in the depot for ages.");
				AIVehicle.SellWagonChain(vehicle, 0);
			}
			*/
			/* We handle it different than SimpleAI for now: */
			HandleVehicleInDepot(vehicle);
		}
	}
	
	/* Were there any routes removed? */
	/* WARNING: Since groups stores an index into routes for each group we can't go changing this
	 * by removing unused routes.
	 * @todo FIGURE out if there is another solution to this.
	 */
//	if (remove_routes.len() > 0) {
//		foreach (removed_count, route_idx in remove_routes) {
//			/* Remove unused routes from our array. */
//			/* Because removing items changes the indexes we need to take that into account too. */
//			/* This assumes that the lowest numbered array indexes will be removed first. */
//			AILog.Info("DEBUG: Removed route " + route_idx + " (orignal idx), " + (route_idx-removed_count) +
//				" (computed idx)");
//			routes.remove(route_idx-removed_count);
//		}
//	}
	// Check ugrouped vehicles as well. There should be none after all...
	WormRailManager.CheckDefaultGroup();
}

function WormRailManager::CheckDefaultGroup()
{
	local vehicles = AIVehicleList_DefaultGroup(AIVehicle.VT_RAIL);
	vehicles.Valuate(AIVehicle.IsStoppedInDepot);
	vehicles.KeepValue(1);
	foreach (vehicle, dummy in vehicles) {
		// Check for vehicles sitting in the depot.
		if (AIVehicle.GetProfitThisYear(vehicle) != 0 || AIVehicle.GetProfitLastYear(vehicle) != 0 || AIVehicle.GetAge(vehicle) < 60) continue;
		if (todepotlist.HasItem(vehicle)) {
			todepotlist.RemoveItem(vehicle);
			AIVehicle.StartStopVehicle(vehicle);
		} else {
			AILog.Warning("Sold " + AIVehicle.GetName(vehicle) + ", as it has been sitting in the depot for ages.");
			AIVehicle.SellWagonChain(vehicle, 0);
		}
	}
}

function WormRailManager::CheckAddTrainToGroup(route, vehicle_count, first_vehicle)
{
	if (vehicle_count == 1 && route.maxvehicles == 2 && (!AIVehicle.IsStoppedInDepot(first_vehicle))) {
		if (AIVehicle.GetProfitThisYear(first_vehicle) <= 0) return false;
		if (AIStation.GetCargoWaiting(route.stasrc, route.crg) > 150)
			return SelectAndAddTrain(route);
		else
			return false;
	}
}

function WormRailManager::SelectAndAddTrain(route)
{
	/* Need to preserve our globally set optimal railtype. */
	local railtype = AIRail.GetCurrentRailType();
	AIRail.SetCurrentRailType(route.railtype);
	
	/* Choose optimal wagon. */
	local wagon = WormRailBuilder.ChooseWagon(route.crg, engine_blacklist);
	if (wagon == null) {
		AIRail.SetCurrentRailType(railtype);
		return false;
	}
	local platform = WormRailBuilder.GetRailStationPlatformLength(route.stasrc);
	
	/* Choose optimal train engine. */
	local engine = WormRailBuilder.ChooseTrainEngine(route.crg, AIMap.DistanceManhattan(AIStation.GetLocation(route.stasrc), 
		AIStation.GetLocation(route.stadst)), wagon, platform * 2 - 1, engine_blacklist);
	if (engine == null) {
		AIRail.SetCurrentRailType(railtype);
		return false;
	}
	local result = false;
	/* See if our budget allows buying the train. */
	if (WormMoney.GetMaxBankBalance() > (WormMoney.GetMinimumCashNeeded() + AIEngine.GetPrice(engine) +
		4 * AIEngine.GetPrice(wagon))) {
		/* Buy the train. */
		local vehicles = AIVehicleList_Group(route.group);
		local order_vehicle = null;
		if (vehicles.Count() > 0)
			order_vehicle = vehicles.Begin();
		if (WormRailManager.AddVehicle(route, order_vehicle, engine, wagon)) {
			AILog.Info("Added train to route: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
			result = true;
		}
	}
	/* Restore railtype. */
	AIRail.SetCurrentRailType(railtype);
	return result;
}

function WormRailManager::AddVehicle(route, mainvehicle, engine, wagon)
{
	// A WormStation instance is needed to add a new vehicle
	local station_data = WormStation();
	station_data.stasrc = route.stasrc;
	station_data.stadst = route.stadst;
	station_data.homedepot = route.homedepot;
	
	local trains = AIVehicleList();
	trains.Valuate(AIVehicle.GetVehicleType);
	trains.KeepValue(AIVehicle.VT_RAIL);
	// Do not try to add one if we have already reached the train limit
	if (trains.Count() + 1 > AIGameSettings.GetValue("vehicle.max_trains")) return false;
	local length = WormRailBuilder.GetRailStationPlatformLength(station_data.stasrc) * 2 - 2;
	if (WormRailBuilder.BuildAndStartTrains(1, length, engine, wagon, mainvehicle, route.group,
		route.crg, station_data, engine_blacklist) == ALL_OK) {
		station_data = null;
		return true;
	} else {
		station_data = null;
		return false;
	}
}

function WormRailManager::ReplaceVehicle(vehicle)
{
	local group = AIVehicle.GetGroupID(vehicle);
	local route = routes[groups.GetValue(group)];
	local engine = null;
	local wagon = null;
	local railtype = AIRail.GetCurrentRailType();
	local vehtype = AIVehicle.GetVehicleType(vehicle);

	// Although we currently only use this for rail we leave it in, we might need it later...
	switch (vehtype) {
		case AIVehicle.VT_RAIL:
			AIRail.SetCurrentRailType(route.railtype);
			wagon = WormRailBuilder.ChooseWagon(route.crg, engine_blacklist);
			if (wagon != null) {
				local platform = WormRailBuilder.GetRailStationPlatformLength(route.stasrc);
				engine = WormRailBuilder.ChooseTrainEngine(route.crg, AIMap.DistanceManhattan(AIStation.GetLocation(route.stasrc),
					AIStation.GetLocation(route.stadst)), wagon, platform * 2 - 1, engine_blacklist);
			}
			break;
		case AIVehicle.VT_ROAD:
			AILog.Error("Replacing road vehicle NOT IMPLEMENTED!");
			//engine = cBuilder.ChooseRoadVeh(route.crg);
			break;
		case AIVehicle.VT_AIR:
			AILog.Error("Replacing airplane NOT IMPLEMENTED!");
			//local srctype = AIAirport.GetAirportType(AIStation.GetLocation(route.stasrc));
			//local dsttype = AIAirport.GetAirportType(AIStation.GetLocation(route.stadst));
			//local is_small = cBuilder.IsSmallAirport(srctype) || cBuilder.IsSmallAirport(dsttype);
			//engine = cBuilder.ChoosePlane(route.crg, is_small, AIOrder.GetOrderDistance(AIVehicle.VT_AIR, AIStation.GetLocation(route.stasrc), AIStation.GetLocation(route.stadst)));
			break;
	}
	local vehicles = AIVehicleList_Group(group);
	local ordervehicle = null;
	// Choose a vehicle to share orders with
	foreach (nextveh, dummy in vehicles) {
		ordervehicle = nextveh;
		// Don't share orders with the vehicle which will be sold
		if (nextveh != vehicle)	break;
	}
	if (ordervehicle == vehicle) ordervehicle = null;
	if (AIVehicle.GetVehicleType(vehicle) == AIVehicle.VT_RAIL) {
		if (engine != null && wagon != null && (WormMoney.GetMaxBankBalance() > AIEngine.GetPrice(engine) +
			5 * AIEngine.GetPrice(wagon))) {
			// Sell the train
			AIVehicle.SellWagonChain(vehicle, 0);
			WormRailManager.AddVehicle(route, ordervehicle, engine, wagon);
		} else {
			// Restart the train if we cannot afford to replace it
			AIVehicle.StartStopVehicle(vehicle);
		}
		// Restore the previous railtype
		AIRail.SetCurrentRailType(railtype);
	} else {
		AILog.Error("Adding road/air vehicle NOT IMPLEMENTED!");
		if (engine != null && (WormMoney.GetMaxBankBalance() > AIEngine.GetPrice(engine))) {
			AIVehicle.SellVehicle(vehicle);
			//cManager.AddVehicle(route, ordervehicle, engine, null);
		} else {
			AIVehicle.StartStopVehicle(vehicle);
		}
	}
	todepotlist.RemoveItem(vehicle);
}

function WormRailManager::HandleVehicleInDepot(vehicle)
{
	//AILog.Info("[DEBUG] " + AIVehicle.GetName(vehicle) + " is stopped in depot.");
	if (todepotlist.HasItem(vehicle)) {
		switch (todepotlist.GetValue(vehicle)) {
			case WormRailManager.TD_SELL:
				// Sell a vehicle because it is old or unprofitable
				AILog.Info("Selling " + AIVehicle.GetName(vehicle) + ".");
				if (AIVehicle.GetVehicleType(vehicle) == AIVehicle.VT_RAIL) {
					if (!AIVehicle.SellWagonChain(vehicle, 0)) {
						AILog.Error("Failed to sell vehicle! " + AIError.GetLastErrorString());
						return;
					}
				} else {
					AIVehicle.SellVehicle(vehicle);
				}
				todepotlist.RemoveItem(vehicle);
				break;
			case WormRailManager.TD_REPLACE:
				// Replace an old vehicle with a newer model
				WormRailManager.ReplaceVehicle(vehicle);
				break;
			case WormRailManager.TD_ATTACH_WAGONS:
				// Attach more wagons to an existing train, if we didn't have enough money to buy all wagons beforehand
				WormRailBuilder.AttachMoreWagons(vehicle, this);
				AIVehicle.StartStopVehicle(vehicle);
				todepotlist.RemoveItem(vehicle);
				break;
			default:
				AILog.Error(AIVehicle.GetName(vehicle) + " is stopped in depot but I don't know what to do with it.");
				AIVehicle.StartStopVehicle(vehicle);
				break;
		}
	} else {
		// The vehicle is not in todepotlist
		AILog.Warning("I don't know why " + AIVehicle.GetName(vehicle) + " was sent to the depot, restarting it...");
		AIVehicle.StartStopVehicle(vehicle);
	}
}

function WormRailManager::CheckTrainProfits()
{
	/// @todo possible duplicate code with profit checking in air manager. Maybe combine in 1 function?
	local list = AIVehicleList();
	local low_profit_limit = 0;
	/* We check only trains here. */
	list.Valuate(AIVehicle.GetVehicleType);
	list.KeepValue(AIVehicle.VT_RAIL);
	local veh_count = list.Count();
	
	list.Valuate(AIVehicle.GetAge);
	/* Give the plane at least 2 full years to make a difference, thus check for 3 years old. */
	list.KeepAboveValue(365 * 3);
	list.Valuate(AIVehicle.GetProfitLastYear);

	/* Decide on the best low profit limit at this moment. */
	/* Define a few changing points for acceptable profits:
		1. When we don't have a lot of vehicles accept everything 0 or above.
		2. When we have a reasonable amount of vehicles increase it to...
		3. When we are close to or we have reached our max vehicle limit increase it even more...
	*/
	/// @todo Do this on a per group basis (each route a group).
	/// @todo That way we can decide to not check a group wich was created less than x years ago.
	local veh_limit = Vehicle.GetVehicleLimit(AIVehicle.VT_RAIL);
	if (veh_count < (veh_limit*75/100)) {
		/* Since we can still add more trains keep all trains that make at least some profit. */
		/// @todo When maintenance costs are on we should set low profit limit too at least
		/// the yearly costs.
		low_profit_limit = 0;
		list.KeepBelowValue(low_profit_limit);
	}
	else if (veh_count < (veh_limit*95/100)) {
		/* Since we can still add a few more trains keep all trains that make at least a little profit. */
		/// @todo When maintenance costs are on we should set low profit limit too at least
		/// the yearly costs.
		low_profit_limit = WormMoney.InflationCorrection(2000); // was 10000, should maybe depend on the date etc too
		list.KeepBelowValue(low_profit_limit);
	}
	else {
		//  extensive computation for low profit limit.
		local list_count = 0;
		local list_copy = AIList();
		// Set default low yearly profit
		low_profit_limit = WormMoney.InflationCorrection(10000);
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
			/* We check only trains here. */
			highest.Valuate(AIVehicle.GetVehicleType);
			highest.KeepValue(AIVehicle.VT_RAIL);
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
			AILog.Info("All trains younger than 3 years: recomputing low_profit_limit not needed.");
		}
		else {
			AILog.Warning("There are " + list.Count() + " trains below last years bad yearly profit limit.");
		}
	}

	/// @todo Don't sell all trans from the same route all at once, try selling 1 per year?
	for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
		/* Profit last year and this year bad? Let's sell the vehicle */
		WormRailManager.SendTrainToDepotForSelling(i);
		//SendToDepotForSelling(i, VEH_LOW_PROFIT);
		/* Sell vehicle provided it's in depot. If not we will get it a next time.
		   This line can also be removed probably since we handle selling once a 
		   month anyway. */
		//SellVehicleInDepot(i);
	}

}

function WormRailManager::SendTrainToDepotForSelling(vehicle)
{
	AILog.Info(AIVehicle.GetName(vehicle) + " is unprofitable, sending it to depot to be sold...");
	if (!AIVehicle.SendVehicleToDepot(vehicle)) {
		// Maybe the vehicle needs to be reversed to find a depot
		AIVehicle.ReverseVehicle(vehicle);
		AIController.Sleep(75);
		if (!AIVehicle.SendVehicleToDepot(vehicle)) return;
	}
	AILog.Info("[DEBUG] and add it to the depot list.");
	todepotlist.AddItem(vehicle, WormRailManager.TD_SELL);
}

function WormRailManager::SaveData(table)
{
	/* 1. Save all lists. */
	/* No need to check for null lists here since ListToTableEntry does that already. */
	WormUtils.ListToTableEntry(table, "todepotlist", this.todepotlist);
	WormUtils.ListToTableEntry(table, "serviced", this.serviced);
	WormUtils.ListToTableEntry(table, "groups", this.groups);
	WormUtils.ListToTableEntry(table, "railbridges", this.railbridges);
	WormUtils.ListToTableEntry(table, "engineblacklist", this.engine_blacklist); /// @todo Should we save this?
	/* 2. Save arrays. */
	table.rawset("routes", routes);
	/* 3. Save other info. */
	table.rawset("lastroute", last_route);
	table.rawset("route_without_trains", route_without_trains);
	table.rawset("buildingstage", buildingstage);
	local toremove = {
		vehtype = null,
		stasrc = null,
		stadst = null,
		list = null
	};
	switch (buildingstage) {
		case BS_BUILDING:
			/** @todo save building state!
			if (builder != null) {
				toremove.vehtype = builder.vehtype;
				toremove.stasrc = builder.stasrc;
				toremove.stadst = builder.stadst;
				toremove.list = [builder.ps1_entry[1], builder.ps2_entry[1]];
			} else {
				AILog.Error("Invalid save state, probably the game is being saved right after loading");
				table.buildingstage = BS_NOTHING;
			}
			*/
			AILog.Warning("Saving building stage not yet implemented!")
			break;
		case BS_REMOVING:
		case BS_ELECTRIFYING:
			table.toremove.list = removelist;
			break;
	}
	table.rawset("toremove", toremove);

	/// @todo EventQueue, bridgesupgraded?, inauguration?, bs_building building stage
}

function WormRailManager::LoadData(table, worm_save_version)
{
	/* Load data from savegame. */
	if ("lastroute" in table) last_route = table.lastroute;
	else last_route = 0;
	if ("route_without_trains" in table) route_without_trains = table.route_without_trains;
	else route_without_trains = 0;
	if ("routes" in table) routes = table.routes;
	/* Arrays that need to be converted to AIList. */
	WormUtils.TableEntryToList(table, "todepotlist", this.todepotlist);
	WormUtils.TableEntryToList(table, "serviced", this.serviced);
	WormUtils.TableEntryToList(table, "groups", this.groups);
	WormUtils.TableEntryToList(table, "railbridges", this.railbridges);
	WormUtils.TableEntryToList(table, "engineblacklist", this.engine_blacklist); /// @todo Should we load this?

	if ("buildingstage" in table) buildingstage = table.buildingstage;
	else buildingstage = BS_NOTHING;
	if (buildingstage != BS_NOTHING) {
		toremove = table.toremove;
	}

}
