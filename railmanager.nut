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

/** Building stages, needed to recover a savegame. */
const BS_NOTHING		= 0;
const BS_BUILDING		= 1;
const BS_REMOVING		= 2;
const BS_ELECTRIFYING	= 3;

/**
 * Define the WormRailManager class which handles trains.
 */
class WormRailManager
{
	/* Variables used by WormRailManager */
	/* 1. Variables that will be saved in a savegame. (TODO) */
	_routes = null;									///< An array containing all our routes
	_groups = null;									//?< The list of vehicle groups
	_serviced = null;								///< Industry/town - cargo pairs already serviced
	_railbridges = null;							///< The list of rail bridges
	_engine_blacklist = null;						///< The blacklist of train engines
	_buildingstage = null;							///< The current building stage
	_lastroute = null;								///< The date the last route was built

	/* 2. Variables that will NOT be saved. */
	_current_railtype = 0;							///< The railtype we are currently using.
	_planner = null;								///< The route planner class object.

	/** Create an instance of WormRailManager and initialize our variables. */
	constructor()
	{
		_routes = [];
		_groups = AIList();
		_serviced = AIList();
		_railbridges = AITileList();
		_engine_blacklist = AIList();
		_current_railtype = AIRail.RAILTYPE_INVALID;
		_planner = WormPlanner(this);
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

 }

/**
 * Set the name of a vehicle group.
 * @param group The GroupID of the group.
 * @param crg The cargo transported.
 * @param stasrc The source station.
 */
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
	/* Plan which route with which cargo we are going to build. */
	if (!_planner.PlanRailRoute()) return false;

	_buildingstage = BS_NOTHING;

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
	local wagon = WormRailBuilder.ChooseWagon(_planner.route.Cargo, _engine_blacklist);
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
		_planner.route.distance_manhattan, wagon, platform * 2 - 1, _engine_blacklist);
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
		if (WormRailBuilder.BuildSingleRailStation(true, platform, _planner.route, station_data)) {
			end = [station_data.frontfront, station_data.stafront];
			_buildingstage = BS_BUILDING;
			AILog.Info("New station successfully built: " + AIStation.GetName(station_data.stasrc));
		} else {
			AILog.Warning("Could not build source station at " + srcname);
			return false;
		}
		// Build the destination station
		if (WormRailBuilder.BuildSingleRailStation(false, platform, _planner.route, station_data)) {
			start = [station_data.frontfront, station_data.stafront];
			AILog.Info("New station successfully built: " + AIStation.GetName(station_data.stadst));
		} else {
			AILog.Warning("Could not build destination station at " + dstname);
/// @todo DeleteRailStation
//			cBuilder.DeleteRailStation(station_data.stasrc);
			_buildingstage = BS_NOTHING;
			return false;
		}

		// Build the rail
		if (WormRailBuilder.BuildRail(start, end, _railbridges)) {
			AILog.Info("Rail built successfully!");
		} else {
/// @todo DeleteRailStation
//			cBuilder.DeleteRailStation(station_data.stasrc);
//			cBuilder.DeleteRailStation(station_data.stadst);
			_buildingstage = BS_NOTHING;
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
		if (WormRailBuilder.BuildDoubleRailStation(true, _planner.route, station_data)) {
			end = [station_data.morefront, station_data.frontfront];
			_buildingstage = BS_BUILDING;
			AILog.Info("New station successfully built: " + AIStation.GetName(station_data.stasrc));
		} else {
			AILog.Warning("Could not build source station at " + srcname);
			return false;
		}

		// Build the destination station
		if (WormRailBuilder.BuildDoubleRailStation(false, _planner.route, station_data)) {
			start = [station_data.morefront, station_data.frontfront];
			AILog.Info("New station successfully built: " + AIStation.GetName(station_data.stadst));
		} else {
			AILog.Warning("Could not build destination station at " + dstname);
/// @todo DeleteRailStation
//			cBuilder.DeleteRailStation(station_data.stasrc);
			_buildingstage = BS_NOTHING;
			return false;
		}

		// Build the first passing lane section
		temp_ps = WormRailBuilder.BuildPassingLaneSection(true, station_data);
		if (temp_ps == null) {
			AILog.Warning("Could not build first passing lane section");
/// @todo DeleteRailStation
//			cBuilder.DeleteRailStation(station_data.stasrc);
//			cBuilder.DeleteRailStation(station_data.stadst);
			_buildingstage = BS_NOTHING;
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
		temp_ps = WormRailBuilder.BuildPassingLaneSection(false, station_data);
		if (temp_ps == null) {
			AILog.Warning("Could not build second passing lane section");
/// @todo DeleteRailStation, RemoveRailLine
//			cBuilder.DeleteRailStation(station_data.stasrc);
//			cBuilder.DeleteRailStation(station_data.stadst);
//			cBuilder.RemoveRailLine(ps1_entry[1]);
			_buildingstage = BS_NOTHING;
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
		if (WormRailBuilder.BuildRail(ps1_entry, end, _railbridges)) {
			AILog.Info("Rail built successfully!");
		} else {
/// @todo DeleteRailStation, RemoveRailLine
//			cBuilder.DeleteRailStation(station_data.stadst);
//			cBuilder.DeleteRailStation(station_data.stasrc);
//			cBuilder.RemoveRailLine(ps1_entry[1]);
//			cBuilder.RemoveRailLine(ps2_entry[1]);
			_buildingstage = BS_NOTHING;
			return false;
		}
		// Build the rail between the two passing lane sections
		if (WormRailBuilder.BuildRail(ps2_entry, ps1_exit, _railbridges)) {
			AILog.Info("Rail built successfully!");
		} else {
/// @todo DeleteRailStation, RemoveRailLine
//			cBuilder.DeleteRailStation(station_data.stadst);
//			cBuilder.DeleteRailStation(station_data.stasrc);
//			cBuilder.RemoveRailLine(ps2_entry[1]);
			_buildingstage = BS_NOTHING;
			return false;
		}
		// Build the rail between the second passing lane section and the destination station
		if (WormRailBuilder.BuildRail(start, ps2_exit, _railbridges)) {
			AILog.Info("Rail built successfully!");
		} else {
/// @todo DeleteRailStation
//			cBuilder.DeleteRailStation(station_data.stadst);
//			cBuilder.DeleteRailStation(station_data.stasrc);
			_buildingstage = BS_NOTHING;
			return false;
		}
	}
	_buildingstage = BS_NOTHING;
	
	// For now always rail here
	local vehtype = AIVehicle.VT_RAIL;

	/* Set up a group for this rail route. */
	local group = AIGroup.CreateGroup(vehtype);
	this.SetGroupName(group, _planner.route.Cargo, station_data.stasrc);
	
	/* Create trains for this route. */
	WormRailBuilder.BuildAndStartTrains(trains, 2 * platform - 2, engine, wagon, null, group,
		_planner.route, station_data, _engine_blacklist);
	/// @todo If building trains fails because of lack of money we should try again after a little wait...
	/// @note This is probably something that is done in manager or RegisteRoute by SimpleAI. Check this!
	
	local new_route = WormRailManager.RegisterRoute(_planner.route, station_data, vehtype, group);
	
	// Retry if route was abandoned due to blacklisting
	local vehicles = AIVehicleList_Group(group);
	if (vehicles.Count() == 0 && vehtype == AIVehicle.VT_RAIL) {
		AILog.Info("The new route may be empty because of blacklisting, retrying...")
		// Choose wagon and locomotive
		local wagon = WormRailBuilder.ChooseWagon(_planner.route.Cargo, _engine_blacklist);
		if (wagon == null) {
			AILog.Warning("No suitable wagon available!");
			return false;
		} else {
			AILog.Info("Chosen wagon: " + AIEngine.GetName(wagon));
		}
		local engine = WormRailBuilder.ChooseTrainEngine(_planner.route.Cargo, _planner.route.distance_manhattan, 
			wagon, platform * 2 - 1, _engine_blacklist);
		if (engine == null) {
			AILog.Warning("No suitable engine available!");
			return false;
		} else {
			AILog.Info("Chosen engine: " + AIEngine.GetName(engine));
		}
		/* Wormnest: it seems easier to call BuildAndStartTrains again...
		local manager = cManager(root);
		manager.AddVehicle(new_route, null, engine, wagon);
		if (_planner.route.double) manager.AddVehicle(new_route, null, engine, wagon);
		*/
		/// @todo check first if we are below max no. of trains...
		/// @todo if we're short on money we should'nt try but wait longer before trying again.
		AILog.Info("Trying again to build trains for this route.");
		WormRailBuilder.BuildAndStartTrains(trains, 2 * platform - 2, engine, wagon, null, group,
			_planner.route, station_data, _engine_blacklist);
	}
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
	_routes.push(route);
	_serviced.AddItem(route_data.SourceID * 256 + route_data.Cargo, 0);
	_groups.AddItem(group, _routes.len() - 1);
	_lastroute = AIDate.GetCurrentDate();
	return route;
}
