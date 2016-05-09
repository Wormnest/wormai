/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file railbuilder.nut Containing the Rail Builder and related classes for WormAI.
 * Based on code from SimpleAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2016.
 *
 */ 

const DIR_NE = 2;
const DIR_NW = 0;
const DIR_SE = 1;
const DIR_SW = 3;

/**
 * Define WormStation class containing station building info.
 */
class WormStation
{
	statile = null;				///< The tile of the station
	deptile = null;				///< The tile of the depot
	stafront = null;			///< The tile in front of the station
	depfront = null;			///< The tile in front of the depot
	statop = null;				///< The top tile of the station
	stabottom = null;			///< The bottom tile of the station
	frontfront = null;			///< ...
	stationdir = null;			///< The direction of the station
	stasrc = null;				///< Station ID of source station
	stadst = null;				///< Station ID of destination station
	homedepot = null;			///< The depot at the source station
	// Below only used only for "double" station
	front1 = null;
	front2 = null;
	lane2 = null;
	morefront = null;

	constructor() {}
}

class WormRailPathFinder extends RailPathFinder
{
		_cost_level_crossing = null;
}

/**
 * Overrides the rail pathfinder's _Cost function to add a penalty for level crossings.
 */
function WormRailPathFinder::_Cost(path, new_tile, new_direction, self)
{
	local cost = ::RailPathFinder._Cost(path, new_tile, new_direction, self);
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_ROAD)) cost += self._cost_level_crossing;
	return cost;
}

/**
 * Define the WormRailBuilder class which handles trains.
 */
class WormRailBuilder
{

	/**
	 * Get a TileList around a town.
	 * @param town_id The TownID of the given town.
	 * @param width The width of the proposed station.
	 * @param height The height of the proposed station.
	 * @return A TileList containing tiles around a town.
	 */
	function GetTilesAroundTown(town_id, width, height);

	/**
	 * Choose a rail wagon for the given cargo.
	 * @param cargo The cargo which will be transported by te wagon.
	 * @return The EngineID of the chosen wagon, null if no suitable wagon was found.
	 */
	static function ChooseWagon(cargo, blacklist);

	/**
	 * Choose a train locomotive.
	 * @param cargo The cargo to carry.
	 * @param distance The distance to be traveled.
	 * @param wagon The EngineID of the wagons to be pulled.
	 * @param num_wagons The number of wagons to be pulled.
	 * @param blacklist A list of engines that cannot be used.
	 * @return The EngineID of the chosen locomotive, null if no suitable locomotive was found.
	 */
	static function ChooseTrainEngine(cargo, distance, wagon, num_wagons, blacklist);

	/**
	 * A valuator function for scoring train locomotives.
	 * @param engine The engine to be scored.
	 * @param weight The weight to be pulled.
	 * @param max_speed The maximum speed allowed.
	 * @param money The amount of money the company has.
	 * @return The score of the engine.
	 * @todo the money parameter seems not to be used.
	 */
	static function TrainEngineValuator(engine, weight, max_speed, money);
	
	/**
	 * Build a single (one-lane) rail station at a town or an industry.
	 * Builder class variables used: crg, src, dst, srcplace, dstplace, srcistown, dstistown,
	 *   statile, stafront, depfront, frontfront, statop, stationdir
	 * Builder class variables set: stasrc, stadst, homedepot
	 * @param is_source True if we are building the source station.
	 * @param platform_length The length of the new station's platform. (2 or 3)
	 * @param route_data A WormRoute class object containing info about the route.
	 * @param station_data A WormStation class object containing info about the station.
	 * @param rail_manager The WormRailManager class object.
	 * @return True if the construction succeeded.
	 */
	function BuildSingleRailStation(is_source, platform_length, route_data, station_data, rail_manager);

	/**
	 * Check whether a single rail station can be built at the given position.
	 * Builder class variables set: statop, stabotton, statile, stafront, depfront, frontfront
	 * @param tile The tile to be checked.
	 * @param direction The direction of the proposed station.
	 * @param platform_length The length of the proposed station's platform. (2 or 3)
	 * @param station_data WormStation class object where the build info will be store (should be non null when called).
	 * @return True if a single rail station can be built at the given position.
	 */
	function CanBuildSingleRailStation(tile, direction, platform_length, station_data);

	/**
	 * Build a double (two-lane) rail station at a town or an industry.
	 * Builder class variables used: crg, src, dst, srcplace, dstplace, srcistown, dstistown,
	 *   statile, deptile, stafront, depfront, frontfront, front1, front2, lane2, morefront
	 * Builder class variables set: stasrc, stadst, homedepot
	 * @param is_source True if we are building the source station.
	 * @param route_data A WormRoute class object containing info about the route.
	 * @param station_data A WormStation class object containing info about the station.
	 * @param rail_manager The WormRailManager class object.
	 * @return True if the construction succeeded.
	 */
	function BuildDoubleRailStation(is_source, route_data, station_data, rail_manager);

	/**
	 * Determine whether a double rail station can be built at a given place.
	 * Builder class variables set: statile, deptile, stafront, depfront, front1, front2,
	 *   lane2, frontfront, morefront, statop, stabottom
	 * @param tile The tile to be checked.
	 * @param direction The direction of the proposed station.
	 * @param station_data WormStation class object where the build info will be store (should be non null when called).
	 * @return Ture if a double rail station can be built at the given position.
	 */
	function CanBuildDoubleRailStation(tile, direction, station_data);

	/**
	 * Build a rail line between two given points.
	 * @param head1 The starting points of the rail line.
	 * @param head2 The ending points of the rail line.
	 * @param railbridges The list of railbridges. If we need to build a bridge it will be added to this list.
	 * @return True if the construction succeeded.
	 */
	function BuildRail(head1, head2, railbridges);

	/**
	 * Build a rail line between two given points.
	 * @param head1 The starting points of the rail line.
	 * @param head2 The ending points of the rail line.
	 * @param railbridges The list of railbridges. If we need to build a bridge it will be added to this list.
	 * @param recursiondepth The recursion depth used to catch infinite recursions.
	 * @return True if the construction succeeded.
	 */
	function InternalBuildRail(head1, head2, railbridges, recursiondepth);

	/**
	 * Retry building a rail track after it was interrupted. The last three pieces of track
	 * are removed, and then pathfinding is restarted from the other end.
	 * @param prevprev The last successfully built piece of track.
	 * @param pp1 The piece of track before prevprev.
	 * @param pp2 The piece of track before pp1.
	 * @param pp3 The piece of track before pp2. It is not removed.
	 * @param head1 The other end to be connected.
	 * @param railbridges The list of railbridges. If we need to build a bridge it will be added to this list.
	 * @param recursiondepth The recursion depth used to catch infinite recursions.
	 * @return True if the construction succeeded.
	 */
	function RetryRail(prevprev, pp1, pp2, pp3, head1, railbridges, recursiondepth);

	/**
	 * Build a passing lane section between the current source and destination.
	 * Builder class variables used: stasrc, stadst
	 * @param near_source True if we're building the first passing lane section. (the one closer to the source station)
	 * @param station_data A WormStation class object with info about the stations between which rail is being built.
	 * @param rail_manager The WormRailManager class object.
	 * @return True if the construction succeeded.
	 */
	function BuildPassingLaneSection(near_source, station_data, rail_manager);

	/**
	 * Determine whether a passing lane section can be built at a given position.
	 * @param centre The centre tile of the proposed passing lane section.
	 * @param direction The direction of the proposed passing lane section.
	 * @param reverse True if we are trying to build a flipped passing lane section.
	 * @return True if a passing lane section can be built.
	 */
	function CanBuildPassingLaneSection(centre, direction, reverse);

	/**
	 * Build and start trains for the current route.
	 * @param number The number of trains to be built.
	 * @param length The number of wagons to be attached to the train.
	 * @param engine The EngineID of the locomotive.
	 * @param wagon The EngineID of the wagons.
	 * @param ordervehicle The vehicle to share orders with. Null, if there is no such vehicle.
	 * @param group The vehicle group this train should be part of.
	 * @param cargo The cargo to transport.
	 * @param station_data A WormStation class object with info about the stations between which rail is being built.
	 * @param engineblacklist The blacklist of engines to which bad engines will be added.
	 * @return True if at least one train was built.
	 */
	function BuildAndStartTrains(number, length, engine, wagon, ordervehicle, group, cargo, station_data, engineblacklist);

	/**
	 * A workaround for refitting the mail wagon separately.
	 * @param mailwagon The mail wagon to be refitted.
	 * @param firstwagon The wagon to which the mail wagon is attached.
	 * @param trainengine The locomotive of the train, used to move the wagons.
	 * @param crg The cargo which the mail wagon will be refitted to.
	 */
	function MailWagonWorkaround(mailwagon, firstwagon, trainengine, crg);

	/**
	 * Remove a continuous segment of rail track starting from a single point. This includes depots
	 * and stations, in all directions and braches. Basically the function deletes all rail tiles
	 * which are reachable by a train from the starting point. This function is not static.
	 * @param start_tile The starting point of the rail.
	 * @param rail_manager The WormRailManager class object.
	 */
	function RemoveRailLine(start_tile, rail_manager);

	/**
	 * Determine whether two tiles are connected with rail directly.
	 * @param tilefrom The first tile to check.
	 * @param tileto The second tile to check.
	 * @return True if the two tiles are connected.
	 */
	function AreRailTilesConnected(tilefrom, tileto);

	/**
	 * Delete a rail station together with the rail line.
	 * Builder class variables used and set:
	 * @param sta The StationID of the station to be deleted.
	 * @param rail_manager The WormRailManager class object.
	 */
	function DeleteRailStation(sta, rail_manager);

	/**
	 * Upgrade a segment of normal rail to electrified rail from a given starting point.
	 * Tiles which are reachable by a train from a given starting point are electrified,
	 * including stations and depots. This function is not static.
	 * @param start_tile The starting point from which rails are electrified.
	 * @param rail_manager The WormRailManager class object.
	 */
	function ElectrifyRail(start_tile, rail_manager);

	/**
	 * Get the platform length of a station.
	 * @param sta The StationID of the station.
	 * @return The length of the station's platform in tiles.
	 */
	function GetRailStationPlatformLength(sta);

	/**
	 * Attach more wagons to a train after it has been sent to the depot.
	 * @param vehicle The VehicleID of the train.
	 * @param rail_manager The WormRailManager class object.
	 */
	function AttachMoreWagons(vehicle, rail_manager);

}

function WormRailBuilder::GetTilesAroundTown(town_id, width, height)
{
	local tiles = AITileList();
	local townplace = AITown.GetLocation(town_id);
	local distedge = AIMap.DistanceFromEdge(townplace);
	local offset = null;
	local radius = 15;
	if (AITown.GetPopulation(town_id) > 5000) radius = 30;
	// A bit different is the town is near the edge of the map
	if (distedge < radius + 1) {
		offset = AIMap.GetTileIndex(distedge - 1, distedge - 1);
	} else {
		offset = AIMap.GetTileIndex(radius, radius);
	}
	tiles.AddRectangle(townplace - offset, townplace + offset);
	tiles.Valuate(WormRailManager.IsRectangleWithinTownInfluence, town_id, width, height);
	tiles.KeepValue(1);
	return tiles;
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
		wagonlist.Valuate(WormValuators.ListContainsValuator, blacklist);
		wagonlist.KeepValue(0);
	}
	wagonlist.Valuate(AIEngine.GetCapacity);
	if (wagonlist.Count() == 0) return null;
	return wagonlist.Begin();
}

function WormRailBuilder::ChooseTrainEngine(cargo, distance, wagon, num_wagons, blacklist)
{
	local enginelist = AIEngineList(AIVehicle.VT_RAIL);
	enginelist.Valuate(AIEngine.HasPowerOnRail, AIRail.GetCurrentRailType());
	enginelist.KeepValue(1);
	enginelist.Valuate(AIEngine.IsWagon);
	enginelist.KeepValue(0);
	enginelist.Valuate(AIEngine.CanPullCargo, cargo);
	enginelist.KeepValue(1);
	if (blacklist != null) {
		enginelist.Valuate(WormValuators.ListContainsValuator, blacklist);
		enginelist.KeepValue(0);
	}
	if (enginelist.IsEmpty()) return null;
	// @todo the money parameter seems not to be used.
	//local money = Banker.GetMaxBankBalance();
	local money = 0;
	local cargo_weight_factor = 0.5;
	if (AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS)) cargo_weight_factor = 0.05;
	if (AICargo.HasCargoClass(cargo, AICargo.CC_BULK) || AICargo.HasCargoClass(cargo, AICargo.CC_LIQUID)) cargo_weight_factor = 1;
	local weight = num_wagons * (AIEngine.GetWeight(wagon) + AIEngine.GetCapacity(wagon) * cargo_weight_factor);
	local max_speed = AIEngine.GetMaxSpeed(wagon);
	if (max_speed == 0) max_speed = 500;
	//AILog.Info("Weight: " + weight + "  Max speed: " + max_speed);
	// @todo the money parameter seems not to be used.
	enginelist.Valuate(WormRailBuilder.TrainEngineValuator, weight, max_speed, money);
	local i = 0;
	/*foreach (engine, value in enginelist) {
		i++;
		AILog.Info(i + ". " + AIEngine.GetName(engine) + " - " + value);
	}*/
	return enginelist.Begin();
}

function WormRailBuilder::TrainEngineValuator(engine, weight, max_speed, money)
{
	local value = 0;
	local weight_with_engine = weight + AIEngine.GetWeight(engine);
	//local hp_break = weight_with_engine.tofloat() * 3.0;
	//local power = AIEngine.GetPower(engine).tofloat();
	//value += (power > hp_break) ? (160 + 240 * power / (3 * hp_break)) : (240 * power / hp_break);
	local hp_per_tonne = AIEngine.GetPower(engine).tofloat() / weight_with_engine.tofloat();
	local power_points = (hp_per_tonne > 4.0) ? ((hp_per_tonne > 16.0) ? (620 + 10 * hp_per_tonne / 4.0) : (420 + 60 * hp_per_tonne / 4.0)) : (-480 + 960 * hp_per_tonne / 4.0);
	value += power_points;
	local speed = AIEngine.GetMaxSpeed(engine);
	local speed_points = (speed > max_speed) ? (360 * max_speed / 112.0) : (360 * speed / 112.0)
	value += speed_points;
	local runningcost_limit = (6000 / Money.GetInflationRate()).tointeger();
	local runningcost = AIEngine.GetRunningCost(engine).tofloat();
	local runningcost_penalty = (runningcost > runningcost_limit) ? ((runningcost > 3 * runningcost_limit) ? (runningcost / 20.0 - 550.0) : (runningcost / 40.0 - 100.0)) : (runningcost / 120.0)
	value -= runningcost_penalty;
	/*AILog.Info(AIEngine.GetName(engine) + " : " + value);
	AILog.Info("     power points: " + power_points);
	AILog.Info("     speed points: " + speed_points);
	AILog.Info("     running cost penalty: " + runningcost_penalty);
	AILog.Info("     railtype: " + AIEngine.GetRailType(engine))*/

	return value.tointeger();
}

function WormRailBuilder::BuildSingleRailStation(is_source, platform_length, route_data, station_data, rail_manager)
{
	local dir, tilelist, otherplace, isneartown = null;
	local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	// Determine the direction of the station, and get tile lists
	if (is_source) {
		dir = WormTiles.GetDirection(route_data.SourceLocation, route_data.DestLocation);
		if (route_data.SourceIsTown) {
			tilelist = WormRailBuilder.GetTilesAroundTown(route_data.SourceID, 1, 1);
			isneartown = true;
		} else {
			tilelist = AITileList_IndustryProducing(route_data.SourceID, rad);
			isneartown = false;
		}
		otherplace = route_data.DestLocation;
	} else {
		dir = WormTiles.GetDirection(route_data.DestLocation, route_data.SourceLocation);
		if (route_data.DestIsTown) {
			tilelist = WormRailBuilder.GetTilesAroundTown(route_data.DestID, 1, 1);
			isneartown = true;
		} else {
			tilelist = AITileList_IndustryAccepting(route_data.DestID, rad);
			tilelist.Valuate(AITile.GetCargoAcceptance, route_data.Cargo, 1, 1, rad);
			tilelist.RemoveBelowValue(8);
			isneartown = false;
		}
		otherplace = route_data.SourceLocation;
	}
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.KeepValue(1);
	// Sort the tile list
	if (isneartown) {
		tilelist.Valuate(AITile.GetCargoAcceptance, route_data.Cargo, 1, 1, rad);
		tilelist.KeepAboveValue(10);
	} else {
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
	}
	tilelist.Sort(AIList.SORT_BY_VALUE, !isneartown);
	local success = false;
	foreach (tile, dummy in tilelist) {
		// Find a place where the station can bee built
		if (WormRailBuilder.CanBuildSingleRailStation(tile, dir, platform_length, station_data)) {
			success = true;
			break;
		} else continue;
	}
	if (!success) return false;

	// Build the station itself
	/*** @todo possibly support for building newgrf stations like SimpleAI does
	if (AIController.GetSetting("newgrf_stations") == 1 && !route_data.SourceIsTown && !route_data.DestIsTown) {
		// Build a NewGRF rail station
		success = success && AIRail.BuildNewGRFRailStation(statop, stationdir, 1, platform_length, AIStation.STATION_NEW,
							route_data.Cargo, AIIndustry.GetIndustryType(route_data.SourceID), AIIndustry.GetIndustryType(route_data.DestID), AIMap.DistanceManhattan(route_data.SourceLocation, route_data.DestLocation), is_source);
	} else { */
		// Build a standard railway station
		success = success && AIRail.BuildRailStation(station_data.statop, station_data.stationdir, 1, platform_length, AIStation.STATION_NEW);
	/*}*/
	if (!success) {
		AILog.Error("Station could not be built: " + AIError.GetLastErrorString());
		return false;
	}

	// Build the rails and the depot
	success = success && AIRail.BuildRail(station_data.statile, station_data.depfront, station_data.stafront);
	success = success && AIRail.BuildRail(station_data.statile, station_data.depfront, station_data.deptile);
	success = success && AIRail.BuildRail(station_data.deptile, station_data.depfront, station_data.stafront);
	success = success && AIRail.BuildRail(station_data.depfront, station_data.stafront, station_data.frontfront);
	success = success && AIRail.BuildRailDepot(station_data.deptile, station_data.depfront);

	if (AIController.GetSetting("signaltype") == 3) {
		// Build an extra path signal according to the setting
		success = success && AIRail.BuildSignal(station_data.stafront, station_data.depfront, AIRail.SIGNALTYPE_PBS);
	}

	if (!success) {
		// If we couldn't build the station for any reason
		AILog.Warning("Station construction was interrupted.")
		WormRailBuilder.RemoveRailLine(station_data.statile, rail_manager);
		return false;
	}

	// Register the station
	if (is_source) {
		station_data.stasrc = AIStation.GetStationID(station_data.statile);
		station_data.homedepot = station_data.deptile;
	} else {
		station_data.stadst = AIStation.GetStationID(station_data.statile);
	}
	return true;
}

function WormRailBuilder::CanBuildSingleRailStation(tile, direction, platform_length, station_data)
{
	if (!AITile.IsBuildable(tile)) return false;
	local vector, rvector = null;

	// Determine some direction vectors
	switch (direction) {
		case DIR_NW:
			vector = AIMap.GetTileIndex(0, -1);
			rvector = AIMap.GetTileIndex(-1, 0);
			station_data.stationdir = AIRail.RAILTRACK_NW_SE;
			break;
		case DIR_NE:
			vector = AIMap.GetTileIndex(-1, 0);
			rvector = AIMap.GetTileIndex(0, 1);
			station_data.stationdir = AIRail.RAILTRACK_NE_SW;
			break;
		case DIR_SW:
			vector = AIMap.GetTileIndex(1, 0);
			rvector = AIMap.GetTileIndex(0, -1);
			station_data.stationdir = AIRail.RAILTRACK_NE_SW;
			break;
		case DIR_SE:
			vector = AIMap.GetTileIndex(0, 1);
			rvector = AIMap.GetTileIndex(1, 0);
			station_data.stationdir = AIRail.RAILTRACK_NW_SE;
			break;
	}

	// Determine the top and the bottom tile of the station, used for building the station itself
	if (direction == DIR_NW || direction == DIR_NE) {
		station_data.stabottom = tile;
		station_data.statop = tile + vector;
		if (platform_length == 3) station_data.statop = station_data.statop + vector;
		station_data.statile = station_data.statop;
	} else {
		station_data.statop = tile;
		station_data.stabottom = tile + vector;
		if (platform_length == 3) station_data.stabottom = station_data.stabottom + vector;
		station_data.statile = station_data.stabottom;
	}

	// Set the other positions
	station_data.depfront = station_data.statile + vector;
	station_data.deptile = station_data.depfront + rvector;
	station_data.stafront = station_data.depfront + vector;
	station_data.frontfront = station_data.stafront + vector;

	// Check if the station can be built
	local test = AITestMode();
	if (!AIRail.BuildRailStation(station_data.statop, station_data.stationdir, 1, platform_length, AIStation.STATION_NEW)) return false;
	if (!AIRail.BuildRailDepot(station_data.deptile, station_data.depfront)) return false;
	if (!AITile.IsBuildable(station_data.depfront)) return false;
	if (!AIRail.BuildRail(station_data.statile, station_data.depfront, station_data.stafront)) return false;
	if (!AIRail.BuildRail(station_data.statile, station_data.depfront, station_data.deptile)) return false;
	if (!AIRail.BuildRail(station_data.deptile, station_data.depfront, station_data.stafront)) return false;
	if (!AITile.IsBuildable(station_data.stafront)) return false;
	if (!AIRail.BuildRail(station_data.depfront, station_data.stafront, station_data.frontfront)) return false;
	if (!AITile.IsBuildable(station_data.frontfront)) return false;
	if (AITile.IsCoastTile(station_data.frontfront)) return false;

	// Check if there is a station just at the back of the proposed station
	if (AIRail.IsRailStationTile(station_data.statile - platform_length * vector)) {
		if (AICompany.IsMine(AITile.GetOwner(station_data.statile - platform_length * vector)) &&
			AIRail.GetRailStationDirection(station_data.statile - platform_length * vector) == station_data.stationdir)
			return false;
	}
	test = null;
	return true;
}

function WormRailBuilder::BuildDoubleRailStation(is_source, route_data, station_data, rail_manager)
{
	local dir, tilelist, otherplace, isneartown = null;
	local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	// Get the tile list
	if (is_source) {
		dir = WormTiles.GetDirection(route_data.SourceLocation, route_data.DestLocation);
		if (route_data.SourceIsTown) {
			tilelist = WormRailBuilder.GetTilesAroundTown(route_data.SourceID, 2, 2);
			isneartown = true;
		} else {
			tilelist = AITileList_IndustryProducing(route_data.SourceID, rad);
			isneartown = false;
		}
		otherplace = route_data.DestLocation;
	} else {
		dir = WormTiles.GetDirection(route_data.DestLocation, route_data.SourceLocation);
		if (route_data.DestIsTown) {
			tilelist = WormRailBuilder.GetTilesAroundTown(route_data.DestID, 2, 2);
			isneartown = true;
		} else {
			tilelist = AITileList_IndustryAccepting(route_data.DestID, rad);
			tilelist.Valuate(AITile.GetCargoAcceptance, route_data.Cargo, 1, 1, rad);
			tilelist.RemoveBelowValue(8);
			isneartown = false;
		}
		otherplace = route_data.SourceLocation;
	}
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.KeepValue(1);

	// Sort the tile list
	if (isneartown) {
		tilelist.Valuate(AITile.GetCargoAcceptance, route_data.Cargo, 1, 1, rad);
		tilelist.KeepAboveValue(10);
	} else {
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
	}
	tilelist.Sort(AIList.SORT_BY_VALUE, !isneartown);
	local success = false;

	// Find a place where the station can be built
	foreach (tile, dummy in tilelist) {
		if (WormRailBuilder.CanBuildDoubleRailStation(tile, dir, station_data)) {
			success = true;
			break;
		} else continue;
	}
	if (!success) return false;

	// Build the station itself
	if (AIController.GetSetting("newgrf_stations") == 1 && !route_data.SourceIsTown && !route_data.DestIsTown) {
		// Build a NewGRF rail station
		success = success && AIRail.BuildNewGRFRailStation(station_data.statop, station_data.stationdir, 2, 3, AIStation.STATION_NEW,
							route_data.Cargo, AIIndustry.GetIndustryType(route_data.SourceID), AIIndustry.GetIndustryType(route_data.DestID), AIMap.DistanceManhattan(route_data.SourceLocation, route_data.DestLocation), is_source);
	} else {
		// Build a standard rail station
		success = success && AIRail.BuildRailStation(station_data.statop, station_data.stationdir, 2, 3, AIStation.STATION_NEW);
	}
	if (!success) {
		AILog.Error("Station could not be built: " + AIError.GetLastErrorString());
		return false;
	}
	// Build the station parts
	success = success && AIRail.BuildRail(station_data.statile, station_data.front1, station_data.depfront);
	success = success && AIRail.BuildRail(station_data.lane2, station_data.front2, station_data.stafront);
	success = success && AIRail.BuildRail(station_data.front1, station_data.depfront, station_data.deptile);
	success = success && AIRail.BuildRail(station_data.front2, station_data.stafront, station_data.frontfront);
	success = success && AIRail.BuildRail(station_data.front1, station_data.depfront, station_data.stafront);
	success = success && AIRail.BuildRail(station_data.front2, station_data.stafront, station_data.depfront);
	success = success && AIRail.BuildRail(station_data.depfront, station_data.stafront, station_data.frontfront);
	success = success && AIRail.BuildRail(station_data.stafront, station_data.depfront, station_data.deptile);
	success = success && AIRail.BuildRail(station_data.stafront, station_data.frontfront, station_data.morefront);
	success = success && AIRail.BuildRailDepot(station_data.deptile, station_data.depfront);

	local signaltype = (AIController.GetSetting("signaltype") >= 2) ? AIRail.SIGNALTYPE_PBS : AIRail.SIGNALTYPE_NORMAL_TWOWAY;
	success = success && AIRail.BuildSignal(station_data.front1, station_data.statile, signaltype);
	success = success && AIRail.BuildSignal(station_data.front2, station_data.lane2, signaltype);

	// Handle it if the construction was interrupted for any reason
	if (!success) {
		AILog.Warning("Station construction was interrupted.");
		WormRailBuilder.RemoveRailLine(statile, rail_manager);
		WormRailBuilder.RemoveRailLine(front2, rail_manager);
		return false;
	}
	// Register the station
	if (is_source) {
		station_data.stasrc = AIStation.GetStationID(station_data.statile);
		station_data.homedepot = station_data.deptile;
	} else {
		station_data.stadst = AIStation.GetStationID(station_data.statile);
	}
	return true;
}

function WormRailBuilder::CanBuildDoubleRailStation(tile, direction, station_data)
{
	if (!AITile.IsBuildable(tile)) return false;
	local vector, rvector = null;
	// Set the direction vectors
	switch (direction) {
		case DIR_NW:
			vector = AIMap.GetTileIndex(0, -1);
			rvector = AIMap.GetTileIndex(1, 0);
			station_data.stationdir = AIRail.RAILTRACK_NW_SE;
			break;
		case DIR_NE:
			vector = AIMap.GetTileIndex(-1, 0);
			rvector = AIMap.GetTileIndex(0, 1);
			station_data.stationdir = AIRail.RAILTRACK_NE_SW;
			break;
		case DIR_SW:
			vector = AIMap.GetTileIndex(1, 0);
			rvector = AIMap.GetTileIndex(0, 1);
			station_data.stationdir = AIRail.RAILTRACK_NE_SW;
			break;
		case DIR_SE:
			vector = AIMap.GetTileIndex(0, 1);
			rvector = AIMap.GetTileIndex(1, 0);
			station_data.stationdir = AIRail.RAILTRACK_NW_SE;
			break;
	}
	// Set the top and the bottom tile of the station
	if (direction == DIR_NW || direction == DIR_NE) {
		station_data.stabottom = tile;
		station_data.statop = tile + vector + vector;
		station_data.statile = station_data.statop;
	} else {
		station_data.statop = tile;
		station_data.stabottom = tile + vector + vector;
		station_data.statile = station_data.stabottom;
	}

	local test = AITestMode();
	// Set the tiles for the station parts
	station_data.lane2 = station_data.statile + rvector;
	station_data.front1 = station_data.statile + vector;
	station_data.front2 = station_data.lane2 + vector;
	station_data.depfront = station_data.front1 + vector;
	station_data.stafront = station_data.front2 + vector;
	station_data.deptile = station_data.depfront + vector;

	// Try the second place for the depot if the first one is not suitable
	if (!AIRail.BuildRailDepot(station_data.deptile, station_data.depfront)) station_data.deptile = station_data.depfront - rvector;
	station_data.frontfront = station_data.stafront + vector;
	station_data.morefront = station_data.frontfront + vector;

	// Try the second place for the station exit if the first one is not suitable
	if ((!AITile.IsBuildable(station_data.frontfront)) || (!AITile.IsBuildable(station_data.morefront)) || 
		(!AIRail.BuildRail(station_data.stafront, station_data.frontfront, station_data.morefront)) ||
		(AITile.IsCoastTile(station_data.morefront))) {
		station_data.frontfront = station_data.stafront + rvector;
		station_data.morefront = station_data.frontfront + rvector;
	}

	// Do the tests
	if (!AIRail.BuildRailStation(station_data.statop, station_data.stationdir, 2, 3, AIStation.STATION_NEW)) return false;
	if (!AITile.IsBuildable(station_data.front1)) return false;
	if (!AIRail.BuildRail(station_data.statile, station_data.front1, station_data.depfront)) return false;
	if (!AITile.IsBuildable(station_data.front2)) return false;
	if (!AIRail.BuildRail(station_data.lane2, station_data.front2, station_data.stafront)) return false;
	if (!AITile.IsBuildable(station_data.depfront)) return false;
	if (!AIRail.BuildRail(station_data.front1, station_data.depfront, station_data.deptile)) return false;
	if (!AITile.IsBuildable(station_data.stafront)) return false;
	if (!AIRail.BuildRail(station_data.front2, station_data.stafront, station_data.frontfront)) return false;
	if (!AIRail.BuildRail(station_data.front1, station_data.depfront, station_data.stafront)) return false;
	if (!AIRail.BuildRail(station_data.front2, station_data.stafront, station_data.depfront)) return false;
	if (!AIRail.BuildRail(station_data.depfront, station_data.stafront, station_data.frontfront)) return false;
	if (!AIRail.BuildRail(station_data.stafront, station_data.depfront, station_data.deptile)) return false;
	if (!AITile.IsBuildable(station_data.frontfront)) return false;
	if (!AITile.IsBuildable(station_data.morefront)) return false;
	if (AITile.IsCoastTile(station_data.morefront)) return false;
	if (!AIRail.BuildRail(station_data.stafront, station_data.frontfront, station_data.morefront)) return false;
	if (!AIRail.BuildRailDepot(station_data.deptile, station_data.depfront)) return false;

	// Check if there is a station just at the back of the proposed station
	if (AIRail.IsRailStationTile(station_data.statile - 3 * vector)) {
		if (AICompany.IsMine(AITile.GetOwner(station_data.statile - 3 * vector)) &&
			AIRail.GetRailStationDirection(station_data.statile - 3 * vector) == station_data.stationdir)
			return false;
	}
	if (AIRail.IsRailStationTile(station_data.lane2 - 3 * vector)) {
		if (AICompany.IsMine(AITile.GetOwner(station_data.lane2 - 3 * vector)) &&
			AIRail.GetRailStationDirection(station_data.lane2 - 3 * vector) == station_data.stationdir)
			return false;
	}
	test = null;
	return true;
}

function WormRailBuilder::BuildRail(head1, head2, railbridges)
{
	local recursiondepth = 0;
	return WormRailBuilder.InternalBuildRail(head1, head2, railbridges, recursiondepth);
}

function WormRailBuilder::InternalBuildRail(head1, head2, railbridges, recursiondepth)
{
	local pathfinder = WormRailPathFinder();
	// Set some pathfinder penalties
	pathfinder._cost_level_crossing = 900;
	pathfinder._cost_slope = 200;
	pathfinder._cost_coast = 100;
	pathfinder._cost_bridge_per_tile = 75;
	pathfinder._cost_tunnel_per_tile = 50;
	pathfinder._max_bridge_length = 20;
	pathfinder._max_tunnel_length = 20;
	pathfinder.InitializePath([head1], [head2]);
	AILog.Info("Pathfinding...");
	local counter = 0;
	local path = false;
	// Try to find a path
	while (path == false && counter < 150) {
		path = pathfinder.FindPath(150);
		counter++;
		AIController.Sleep(1);
	}
	if (path != null && path != false) {
		AILog.Info("Path found. (" + counter + ")");
	} else {
		AILog.Warning("Pathfinding failed.");
		return false;
	}
	local prev = null;
	local prevprev = null;
	local pp1, pp2, pp3 = null;
	while (path != null) {
		if (prevprev != null) {
			if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
				// If we are building a tunnel or a bridge
				if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile()) {
					// If we are building a tunnel
					if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev)) {
						AILog.Info("An error occured while I was building the rail: " + AIError.GetLastErrorString());
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
							AILog.Warning("That tunnel would be too expensive. Construction aborted.");
							return false;
						}
						// Try again if we have the money
						if (!WormRailBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1, railbridges, recursiondepth)) return false;
						else return true;
					}
				} else {
					// If we are building a bridge
					local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
					bridgelist.Valuate(AIBridge.GetMaxSpeed);
					if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridgelist.Begin(), prev, path.GetTile())) {
						AILog.Info("An error occured while I was building the rail: " + AIError.GetLastErrorString());
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
							AILog.Warning("That bridge would be too expensive. Construction aborted.");
							return false;
						}
						// Try again if we have the money
						if (!WormRailBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1, railbridges, recursiondepth)) return false;
						else return true;
					} else {
						// Register the new bridge
						railbridges.AddTile(path.GetTile());
					}
				}
				// Step these variables after a tunnel or bridge was built
				pp3 = pp2;
				pp2 = pp1;
				pp1 = prevprev;
				prevprev = prev;
				prev = path.GetTile();
				path = path.GetParent();
			} else {
				// If we are building a piece of rail track
				if (!AIRail.BuildRail(prevprev, prev, path.GetTile())) {
					AILog.Info("An error occured while I was building the rail: " + AIError.GetLastErrorString());
					if (!WormRailBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1, railbridges, recursiondepth)) return false;
					else return true;
				}
			}
		}
		// Step these variables at the start of the construction
		if (path != null) {
			pp3 = pp2;
			pp2 = pp1;
			pp1 = prevprev;
			prevprev = prev;
			prev = path.GetTile();
			path = path.GetParent();
		}
		// Check if we still have the money
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < (AICompany.GetLoanInterval() + WormMoney.GetMinimumCashNeeded())) {
			if (!WormMoney.GetMoney(AICompany.GetLoanInterval())) {
				AILog.Warning("I don't have enough money to complete the route.");
				return false;
			}
		}
	}
	return true;
}

function WormRailBuilder::RetryRail(prevprev, pp1, pp2, pp3, head1, railbridges, recursiondepth)
{
	// Avoid infinite loops
	recursiondepth++;
	if (recursiondepth > 10) {
		AILog.Error("It looks like I got into an infinite loop.");
		return false;
	}
	// pp1 is null if no track was built at all
	if (pp1 == null) return false;
	local head2 = [null, null];
	local tiles = [pp3, pp2, pp1, prevprev];
	// Set the rail end correctly
	foreach (idx, tile in tiles) {
		if (tile != null) {
			head2[1] = tile;
			break;
		}
	}
	tiles = [prevprev, pp1, pp2, pp3]
	foreach (idx, tile in tiles) {
		if (tile == head2[1]) {
			// Do not remove it if we reach the station
			break;
		} else {
			// Removing rail from a level crossing cannot be done with DemolishTile
			if (AIRail.IsLevelCrossingTile(tile)) {
				local track = AIRail.GetRailTracks(tile);
				if (!AIRail.RemoveRailTrack(tile, track)) {
					// Try again a few times if a road vehicle was in the way
					local counter = 0;
					AIController.Sleep(75);
					while (!AIRail.RemoveRailTrack(tile, track) && counter < 3) {
						counter++;
						AIController.Sleep(75);
					}
				}
			} else {
				AITile.DemolishTile(tile);
			}
			head2[0] = tile;
		}
	}
	// Restart pathfinding from the other end
	if (WormRailBuilder.InternalBuildRail(head2, head1, railbridges, recursiondepth)) return true;
	else return false;
}

function WormRailBuilder::BuildPassingLaneSection(near_source, station_data, rail_manager)
{
	local dir, tilelist, centre;
	local src_x, src_y, dst_x, dst_y, ps_x, ps_y;
	local end = [[], []];
	local reverse = false;
	// Get the direction of the passing lane section
	dir = AIRail.GetRailTracks(AIStation.GetLocation(station_data.stasrc));
	// Get the places of the stations
	src_x = AIMap.GetTileX(AIStation.GetLocation(station_data.stasrc));
	src_y = AIMap.GetTileY(AIStation.GetLocation(station_data.stasrc));
	dst_x = AIMap.GetTileX(AIStation.GetLocation(station_data.stadst));
	dst_y = AIMap.GetTileY(AIStation.GetLocation(station_data.stadst));
	// Determine whether we're building a flipped passing lane section
	if ((!(dst_x > src_x) && (dst_y > src_y)) || ((dst_x > src_x) && !(dst_y > src_y))) reverse = true;
	// Propose a place for the passing lane section, it is 1/3 on the line between the two stations
	if (near_source) {
		ps_x = ((2 * src_x + dst_x) / 3).tointeger();
		ps_y = ((2 * src_y + dst_y) / 3).tointeger();
	} else {
		ps_x = ((src_x + 2 * dst_x) / 3).tointeger();
		ps_y = ((src_y + 2 * dst_y) / 3).tointeger();
	}
	// Get a tile list around the proposed place
	tilelist = AITileList();
	centre = AIMap.GetTileIndex(ps_x, ps_y);
	tilelist.AddRectangle(centre - AIMap.GetTileIndex(10, 10), centre + AIMap.GetTileIndex(10, 10));
	tilelist.Valuate(AIMap.DistanceManhattan, centre);
	tilelist.Sort(AIList.SORT_BY_VALUE, true);
	local success = false;
	local tile = null;
	// Find a place where the passing lane section can be built
	foreach (itile, dummy in tilelist) {
		if (WormRailBuilder.CanBuildPassingLaneSection(itile, dir, reverse)) {
			success = true;
			tile = itile;
			break;
		} else continue;
	}
	if (!success) return null;
	// Get the direction vectors
	local vector, rvector;
	if (dir == AIRail.RAILTRACK_NE_SW) {
		vector = AIMap.GetTileIndex(1, 0);
		rvector = AIMap.GetTileIndex(0, 1);
	} else {
		vector = AIMap.GetTileIndex(0, 1);
		rvector = AIMap.GetTileIndex(1, 0);
	}
	// Determine what signal type to use
	local signaltype = AIRail.SIGNALTYPE_NORMAL;
	if (AIController.GetSetting("signaltype") > 0) {
		signaltype = (AIController.GetSetting("signaltype") < 2) ? AIRail.SIGNALTYPE_TWOWAY : AIRail.SIGNALTYPE_PBS_ONEWAY;
	}
	// Build the passing lane section
	if (reverse) rvector = -rvector;
	centre = tile;
	tile = centre - vector - vector - vector;
	end[0] = [tile - vector, tile];
	for (local x = 0; x < 6; x++) {
		success = success && AIRail.BuildRail(tile - vector, tile, tile + vector);
		tile += vector;
	}
	success = success && AIRail.BuildRail(tile - vector, tile, tile + rvector);
	success = success && AIRail.BuildRail(tile, tile + rvector, tile + rvector + vector);
	tile = centre + rvector + vector + vector + vector + vector;
	end[1] = [tile + vector, tile];
	for (local x = 0; x < 6; x++) {
		success = success && AIRail.BuildRail(tile + vector, tile, tile - vector);
		tile -= vector;
	}
	success = success && AIRail.BuildRail(tile + vector, tile, tile - rvector);
	success = success && AIRail.BuildRail(tile, tile - rvector, tile - rvector - vector);
	success = success && AIRail.BuildSignal(centre - vector, centre - 2*vector, signaltype);
	success = success && AIRail.BuildSignal(centre - 2*vector + rvector, centre - vector + rvector, signaltype);
	success = success && AIRail.BuildSignal(centre + rvector + 2*vector, centre + rvector + 3*vector, signaltype);
	success = success && AIRail.BuildSignal(centre + 3*vector, centre + 2*vector, signaltype);
	if (!success) {
		AILog.Warning("Passing lane construction was interrupted.");
		WormRailBuilder.RemoveRailLine(end[0][1], rail_manager);
		return null;
	}
	return end;
}

function WormRailBuilder::CanBuildPassingLaneSection(centre, direction, reverse)
{
	if (!AITile.IsBuildable(centre)) return false;
	local vector, rvector = null;
	// Get the direction vectors
	if (direction == AIRail.RAILTRACK_NE_SW) {
		vector = AIMap.GetTileIndex(1, 0);
		rvector = AIMap.GetTileIndex(0, 1);
		local topcorner = centre - vector - vector;
		if (reverse) topcorner -= rvector;
		if (!AITile.IsBuildableRectangle(topcorner, 6, 2)) return false;
	} else {
		vector = AIMap.GetTileIndex(0, 1);
		rvector = AIMap.GetTileIndex(1, 0);
		local topcorner = centre - vector - vector;
		if (reverse) topcorner -= rvector;
		if (!AITile.IsBuildableRectangle(topcorner, 2, 6)) return false;
	}
	if (reverse) rvector = -rvector;
	local test = AITestMode();
	local tile = centre - vector - vector - vector;
	// Do the tests
	if (!AITile.IsBuildable(tile)) return false;
	if (!AITile.IsBuildable(tile - vector)) return false;
	// Do not build on the coast
	if (AITile.IsCoastTile(tile - vector)) return false;
	if (!AIRail.BuildRail(tile, tile + vector, tile + vector + rvector)) return false;
	if (!AIRail.BuildRail(tile + vector, tile + vector + rvector, tile + vector + vector + rvector)) return false;
	if (!AIRail.BuildRail(tile + vector + rvector, tile + vector, tile + vector + vector)) return false;
	for (local x = 0; x < 6; x++) {
		if (!AIRail.BuildRail(tile - vector, tile, tile + vector)) return false;
		tile += vector;
	}
	tile = centre + rvector + vector + vector + vector + vector;
	if (!AITile.IsBuildable(tile)) return false;
	if (!AITile.IsBuildable(tile + vector)) return false;
	// Do not build on the coast
	if (AITile.IsCoastTile(tile + vector)) return false;
	if (!AIRail.BuildRail(tile, tile - vector, tile - vector - rvector)) return false;
	if (!AIRail.BuildRail(tile - vector, tile - vector - rvector, tile - vector - vector - rvector)) return false;
	if (!AIRail.BuildRail(tile - vector - rvector, tile - vector, tile - vector - vector)) return false;
	for (local x = 0; x < 6; x++) {
		if (!AIRail.BuildRail(tile + vector, tile, tile - vector)) return false;
		tile -= vector;
	}
	test = null;
	return true;
}

function WormRailBuilder::BuildAndStartTrains(number, length, engine, wagon, ordervehicle, group, cargo, station_data, engineblacklist)
{
	local src_place = AIStation.GetLocation(station_data.stasrc);
	local dst_place = AIStation.GetLocation(station_data.stadst);
	// Check if we can afford building a train
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(engine)) {
		if (!WormMoney.GetMoney(AIEngine.GetPrice(engine), WormMoney.WM_SILENT)) {
			AILog.Warning("I don't have enough money to build the train.");
			return false;
		}
	}
	// Build and refit the train engine if needed
	local trainengine = AIVehicle.BuildVehicle(station_data.homedepot, engine);
	if (!AIVehicle.IsValidVehicle(trainengine)) {
		// safety, suggestion by krinn
		AILog.Error("The train engine did not get built: " + AIError.GetLastErrorString());
		return false;
	}
	AIVehicle.RefitVehicle(trainengine, cargo);

	// Check if we have the money to build at least one wagon
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(wagon)) {
		if (!WormMoney.GetMoney(AIEngine.GetPrice(wagon), WormMoney.WM_SILENT)) {
			AILog.Warning("I don't have enough money to build the train.");
			AIVehicle.SellVehicle(trainengine);
			return false;
		}
	}
	local firstwagon = AIVehicle.BuildVehicle(station_data.homedepot, wagon);
	// Blacklist the wagon if it is too long
	if (AIVehicle.GetLength(firstwagon) > 8) {
		engineblacklist.AddItem(wagon, 0);
		AILog.Warning(AIEngine.GetName(wagon) + " was blacklisted for being too long.");
		AIVehicle.SellVehicle(trainengine);
		AIVehicle.SellVehicle(firstwagon);
		return false;
	}
	// Try whether the engine is compatibile with the wagon
	{
		local testmode = AITestMode();
		if (!AIVehicle.MoveWagonChain(firstwagon, 0, trainengine, 0)) {
			engineblacklist.AddItem(engine, 0);
			AILog.Warning(AIEngine.GetName(engine) + " was blacklisted for not being compatibile with " + AIEngine.GetName(wagon) + ".");
			local execmode = AIExecMode();
			AIVehicle.SellVehicle(trainengine);
			AIVehicle.SellVehicle(firstwagon);
			return false;
		}
	}
	// Build a mail wagon
	local mailwagontype = null, mailwagon = null;
	if ((length > 3) && (AICargo.GetTownEffect(cargo) == AICargo.TE_PASSENGERS)) {
		// Choose a wagon for mail
		local mailcargo = WormPlanner.GetMailCargo();
		mailwagontype = WormRailBuilder.ChooseWagon(mailcargo, engineblacklist);
		if (mailwagontype == null) mailwagontype = wagon;
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(mailwagontype)) {
			WormMoney.GetMoney(AIEngine.GetPrice(mailwagontype));
		}
		mailwagon = AIVehicle.BuildVehicle(station_data.homedepot, mailwagontype);
		if (mailwagon != null) {
			// Try to refit the mail wagon if needed
			local mailwagoncargo = AIEngine.GetCargoType(AIVehicle.GetEngineType(mailwagon));
			if (AICargo.GetTownEffect(mailwagoncargo) != AICargo.TE_MAIL) {
				if (mailwagontype == wagon) {
					// Some workaround if the mail wagon type is the same as the wagon type
					WormRailBuilder.MailWagonWorkaround(mailwagon, firstwagon, trainengine, mailcargo);
				} else {
					if (!AIVehicle.RefitVehicle(mailwagon, mailcargo)) {
						// If no mail wagon was found, and the other wagons needed to be refitted, refit the "mail wagon" as well
						if (mailwagoncargo != cargo) AIVehicle.RefitVehicle(mailwagon, cargo);
					}
				}
			}
		}
	}
	local wagon_length = AIVehicle.GetLength(firstwagon);
	local mailwagon_length = 0;
	if (mailwagon != null) {
		if (mailwagontype == wagon) {
			wagon_length /= 2;
			mailwagon_length = wagon_length;
		} else {
			mailwagon_length = AIVehicle.GetLength(mailwagon);
		}
	}
	local cur_wagons = 1;
	local platform_length = length / 2 + 1;
	while (AIVehicle.GetLength(trainengine) + (cur_wagons + 1) * wagon_length + mailwagon_length <= platform_length * 16) {
		//AILog.Info("Current length: " + (AIVehicle.GetLength(trainengine) + (cur_wagons + 1) * wagon_length + mailwagon_length));
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(wagon)) {
			WormMoney.GetMoney(AIEngine.GetPrice(wagon));
		}
		if (!AIVehicle.BuildVehicle(station_data.homedepot, wagon)) break;
		cur_wagons++;
	}
	local price = AIEngine.GetPrice(engine) + cur_wagons * AIEngine.GetPrice(wagon);
	// Refit the wagons if needed
	if (AIEngine.GetCargoType(wagon) != cargo) AIVehicle.RefitVehicle(firstwagon, cargo);
	// Attach the wagons to the engine
	if (mailwagon != null) {
		price += AIVehicle.GetCurrentValue(mailwagon);
		if (wagon != mailwagontype && !AIVehicle.MoveWagonChain(mailwagon, 0, trainengine, 0) ||
		    wagon == mailwagontype && !AIVehicle.MoveWagon(firstwagon, 1, trainengine, 0)) {
			engineblacklist.AddItem(engine, 0);
			AILog.Warning(AIEngine.GetName(engine) + " was blacklisted for not being compatibile with " + AIEngine.GetName(mailwagontype) + ".");
			AIVehicle.SellVehicle(trainengine);
			AIVehicle.SellWagonChain(firstwagon, 0);
			AIVehicle.SellVehicle(mailwagon);
			return false;
		}
	}
	if (!AIVehicle.MoveWagonChain(firstwagon, 0, trainengine, 0)) {
		AILog.Error("Could not attach the wagons.");
		AIVehicle.SellWagonChain(trainengine, 0);
		AIVehicle.SellWagonChain(firstwagon, 0);
	}
	if (ordervehicle == null) {
		// Set the train's orders
		local firstorderflag = null;
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_PASSENGERS || AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL) {
			// Do not full load a passenger train
			firstorderflag = AIOrder.OF_NON_STOP_INTERMEDIATE;
		} else {
			firstorderflag = AIOrder.OF_FULL_LOAD_ANY + AIOrder.OF_NON_STOP_INTERMEDIATE;
		}
		AIOrder.AppendOrder(trainengine, src_place, firstorderflag);
		AIOrder.AppendOrder(trainengine, dst_place, AIOrder.OF_NON_STOP_INTERMEDIATE);
	} else {
		AIOrder.ShareOrders(trainengine, ordervehicle);
	}
	AIVehicle.StartStopVehicle(trainengine);
	AIGroup.MoveVehicle(group, trainengine);
	// Build the second train if needed
	if (number > 1) {
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < price) {
			WormMoney.GetMoney(price);
		}
		local nexttrain = AIVehicle.CloneVehicle(station_data.homedepot, trainengine, true);
		AIVehicle.StartStopVehicle(nexttrain);
	}
	return true;
}

function WormRailBuilder::MailWagonWorkaround(mailwagon, firstwagon, trainengine, crg)
{
	AIVehicle.MoveWagon(firstwagon, 0, trainengine, 0);
	AIVehicle.RefitVehicle(mailwagon, crg);
	AIVehicle.MoveWagon(trainengine, 1, mailwagon, 0);
	AIVehicle.MoveWagon(mailwagon, 0, trainengine, 0);
	AIVehicle.MoveWagon(trainengine, 1, firstwagon, 0);
}

function WormRailBuilder::RemoveRailLine(start_tile, rail_manager)
{
	if (start_tile == null) return;
	// Rail line removal works without a valid start tile if the rail_manager's object's removelist is not empty, needed for save/load compatibility
	if (!AIMap.IsValidTile(start_tile) && rail_manager.removelist.len() == 0) return;
	// Starting date is needed to avoid infinite loops
	local startingdate = AIDate.GetCurrentDate();
	rail_manager.buildingstage = rail_manager.BS_REMOVING;
	// Get the four directions
	local all_vectors = [AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
	if (AIMap.IsValidTile(start_tile)) rail_manager.removelist = [start_tile];
	local tile = null;
	while (rail_manager.removelist.len() > 0) {
		// Avoid infinite loops
		if (AIDate.GetCurrentDate() - startingdate > 120) {
			AILog.Error("It looks like I got into an infinite loop.");
			rail_manager.removelist = [];
			return;
		}
		tile = rail_manager.removelist.pop();
		// Step further if it is a tunnel or a bridge, because it takes two tiles
		if (AITunnel.IsTunnelTile(tile)) tile = AITunnel.GetOtherTunnelEnd(tile);
		if (AIBridge.IsBridgeTile(tile)) {
			rail_manager.railbridges.RemoveTile(tile);
			tile = AIBridge.GetOtherBridgeEnd(tile);
			rail_manager.railbridges.RemoveTile(tile);
		}
		if (!AIRail.IsRailDepotTile(tile)) {
			// Get the connecting rail tiles
			foreach (idx, vector in all_vectors) {
				if (WormRailBuilder.AreRailTilesConnected(tile, tile + vector)) {
					rail_manager.removelist.push(tile + vector);
				}
			}
		}
		// Removing rail from a level crossing cannot be done with DemolishTile
		if (AIRail.IsLevelCrossingTile(tile)) {
			local track = AIRail.GetRailTracks(tile);
			if (!AIRail.RemoveRailTrack(tile, track)) {
				// Try again a few times if a road vehicle was in the way
				local counter = 0;
				AIController.Sleep(75);
				while (!AIRail.RemoveRailTrack(tile, track) && counter < 3) {
					counter++;
					AIController.Sleep(75);
				}
			}
		} else {
			AITile.DemolishTile(tile);
		}
	}
	rail_manager.buildingstage = rail_manager.BS_NOTHING;
}

function WormRailBuilder::AreRailTilesConnected(tilefrom, tileto)
{
	// Check some preconditions
	if (!AITile.HasTransportType(tilefrom, AITile.TRANSPORT_RAIL)) return false;
	if (!AITile.HasTransportType(tileto, AITile.TRANSPORT_RAIL)) return false;
	if (!AICompany.IsMine(AITile.GetOwner(tilefrom))) return false;
	if (!AICompany.IsMine(AITile.GetOwner(tileto))) return false;
	if (AIRail.GetRailType(tilefrom) != AIRail.GetRailType(tileto)) return false;
	// Determine the dircetion
	local dirfrom = WormTiles.GetDirection(tilefrom, tileto);
	local dirto = null;
	// Some magic bitmasks
	local acceptable = [22, 42, 37, 25];
	// Determine the direction pointing backwards
	if (dirfrom == 0 || dirfrom == 2) dirto = dirfrom + 1;
	else dirto = dirfrom - 1;
	if (AITunnel.IsTunnelTile(tilefrom)) {
		// Check a tunnel
		local otherend = AITunnel.GetOtherTunnelEnd(tilefrom);
		if (WormTiles.GetDirection(otherend, tilefrom) != dirfrom) return false;
	} else {
		if (AIBridge.IsBridgeTile(tilefrom)) {
			// Check a bridge
			local otherend = AIBridge.GetOtherBridgeEnd(tilefrom);
			if (WormTiles.GetDirection(otherend, tilefrom) != dirfrom) return false;
		} else {
			// Check rail tracks
			local tracks = AIRail.GetRailTracks(tilefrom);
			if ((tracks & acceptable[dirfrom]) == 0) return false;
		}
	}
	// Do this check the other way around as well
	if (AITunnel.IsTunnelTile(tileto)) {
		local otherend = AITunnel.GetOtherTunnelEnd(tileto);
		if (WormTiles.GetDirection(otherend, tileto) != dirto) return false;
	} else {
		if (AIBridge.IsBridgeTile(tileto)) {
			local otherend = AIBridge.GetOtherBridgeEnd(tileto);
			if (WormTiles.GetDirection(otherend, tileto) != dirto) return false;
		} else {
			local tracks = AIRail.GetRailTracks(tileto);
			if ((tracks & acceptable[dirto]) == 0) return false;
		}
	}
	return true;
}

function WormRailBuilder::DeleteRailStation(sta, rail_manager)
{
	if (sta == null || !AIStation.IsValidStation(sta)) return;
	// Don't delete the station if there are trains using it
	local vehiclelist = AIVehicleList_Station(sta);
	if (vehiclelist.Count() > 0) {
		AILog.Error(AIStation.GetName(sta) + " cannot be removed, it's still in use!");
		return;
	}
	local place = AIStation.GetLocation(sta);
	if (!AIRail.IsRailStationTile(place)) return;
	// Get the positions of the station parts
	local dir = AIRail.GetRailStationDirection(place);
	local vector, rvector = null;
	local twolane = false;
	local depfront, stafront, depot, frontfront = null;
	if (dir == AIRail.RAILTRACK_NE_SW) {
		vector = AIMap.GetTileIndex(1, 0);
		rvector = AIMap.GetTileIndex(0, 1);
	} else {
		vector = AIMap.GetTileIndex(0, 1);
		rvector = AIMap.GetTileIndex(1, 0);
	}
	// Determine if it is a single or a double rail station
	if (AIRail.IsRailStationTile(place + rvector)) {
		local otherstation = AIStation.GetStationID(place + rvector);
		if (AIStation.IsValidStation(otherstation) && otherstation == sta) twolane = true;
	}
	if (twolane) {
		// Deleting a double rail station
		// Get the front tile of the station
		if (WormRailBuilder.AreRailTilesConnected(place, place - vector)) {
			// The station is pointing upwards
			stafront = place - vector;
		} else {
			// The station is pointing downwards
			stafront = place;
			while (AIRail.IsRailStationTile(stafront)) {
				stafront += vector;
			}
		}
		AITile.DemolishTile(place);
		// Remove the rail line, including the station parts, and the other station if it is connected
		WormRailBuilder.RemoveRailLine(stafront, rail_manager);
	} else {
		// Deleting a single rail station
		if (WormRailBuilder.AreRailTilesConnected(place, place - vector)) {
			// The station is pointing upwards
			depfront = place - vector;
			if (dir == AIRail.RAILTRACK_NE_SW) {
				vector = AIMap.GetTileIndex(-1, 0);
			} else {
				vector = AIMap.GetTileIndex(0, -1);
				rvector = AIMap.GetTileIndex(-1, 0);
			}
		} else {
			// The station is pointing downwards
			depfront = place;
			while (AIRail.IsRailStationTile(depfront)) {
				depfront += vector;
			}
			if (dir == AIRail.RAILTRACK_NE_SW) rvector = AIMap.GetTileIndex(0, -1);
		}
		// Remove the station parts
		stafront = depfront + vector;
		depot = depfront + rvector;
		frontfront = stafront + vector;
		AITile.DemolishTile(place);
		AITile.DemolishTile(depfront);
		AITile.DemolishTile(depot);
		// Remove the rail line, including the other station if it is connected
		WormRailBuilder.RemoveRailLine(stafront, rail_manager);
		AIRail.RemoveRail(depfront, stafront, frontfront)
	}
}

function WormRailBuilder::ElectrifyRail(start_tile, rail_manager)
{
	// The starting date is needed to avoid infinite loops
	local startingdate = AIDate.GetCurrentDate();
	rail_manager.buildingstage = rail_manager.BS_ELECTRIFYING;
	// Get all four directions
	local all_vectors = [AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
	// If start_tile is not a valid tile we're probably loading a game
	if (AIMap.IsValidTile(start_tile)) rail_manager.removelist = [start_tile];
	local tile = null;
	while (rail_manager.removelist.len() > 0) {
		// Avoid infinite loops
		if (AIDate.GetCurrentDate() - startingdate > 120) {
			AILog.Error("It looks like I got into an infinite loop.");
			rail_manager.removelist = [];
			return;
		}
		tile = rail_manager.removelist.pop();
		// Step further if it is a tunnel or a bridge
		if (AITunnel.IsTunnelTile(tile)) tile = AITunnel.GetOtherTunnelEnd(tile);
		if (AIBridge.IsBridgeTile(tile)) tile = AIBridge.GetOtherBridgeEnd(tile);
		if (!AIRail.IsRailDepotTile(tile) && (AIRail.GetRailType(tile) != AIRail.GetCurrentRailType())) {
			// Check the neighboring rail tiles, only tiles from the old railtype are considered
			foreach (idx, vector in all_vectors) {
				if (WormRailBuilder.AreRailTilesConnected(tile, tile + vector)) {
					rail_manager.removelist.push(tile + vector);
				}
			}
		}
		AIRail.ConvertRailType(tile, tile, AIRail.GetCurrentRailType());
	}
	rail_manager.buildingstage = rail_manager.BS_NOTHING;
}

function WormRailBuilder::GetRailStationPlatformLength(sta)
{
	if (!AIStation.IsValidStation(sta)) return 0;
	local place = AIStation.GetLocation(sta);
	if (!AIRail.IsRailStationTile(place)) return 0;
	local dir = AIRail.GetRailStationDirection(place);
	local vector = null;
	if (dir == AIRail.RAILTRACK_NE_SW) vector = AIMap.GetTileIndex(1, 0);
	else vector = AIMap.GetTileIndex(0, 1);
	local length = 0;
	while (AIRail.IsRailStationTile(place) && AIStation.GetStationID(place) == sta) {
		length++;
		place += vector;
	}
	return length;
}

function WormRailBuilder::AttachMoreWagons(vehicle, rail_manager)
{
	// Get information about the train's group
	local group = AIVehicle.GetGroupID(vehicle);
	local route = rail_manager.routes[rail_manager.groups.GetValue(group)];
	local railtype = AIRail.GetCurrentRailType();
	AIRail.SetCurrentRailType(route.railtype);
	local depot = AIVehicle.GetLocation(vehicle);
	// Choose a wagon
	local wagon = WormRailBuilder.ChooseWagon(route.crg, rail_manager.engine_blacklist);
	if (wagon == null) return;
	// Build the first wagon
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(wagon)) {
		if (!WormMoney.GetMoney(AIEngine.GetPrice(wagon), WormMoney.WM_SILENT)) {
			AILog.Warning("I don't have enough money to attach more wagons.");
			return;
		}
	}
	local firstwagon = AIVehicle.BuildVehicle(depot, wagon);
	// Blacklist the wagon if it is too long
	if (AIVehicle.GetLength(firstwagon) > 8) {
		rail_manager.engine_blacklist.AddItem(wagon, 0);
		AILog.Warning(AIEngine.GetName(wagon) + " was blacklisted for being too long.");
		AIVehicle.SellVehicle(firstwagon);
		return;
	}
	// Attach additional wagons
	local wagon_length = AIVehicle.GetLength(firstwagon);
	local cur_wagons = 1;
	local platform_length = WormRailBuilder.GetRailStationPlatformLength(route.stasrc);
	while (AIVehicle.GetLength(vehicle) + (cur_wagons + 1) * wagon_length <= platform_length * 16) {
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(wagon)) {
			WormMoney.GetMoney(AIEngine.GetPrice(wagon), WormMoney.WM_SILENT);
		}
		if (!AIVehicle.BuildVehicle(depot, wagon)) break;
		cur_wagons++;
	}
	// Refit the wagons if needed
	if (AIEngine.GetCargoType(wagon) != route.crg) AIVehicle.RefitVehicle(firstwagon, route.crg);
	// Attach the wagons to the engine
	AIVehicle.MoveWagonChain(firstwagon, 0, vehicle, AIVehicle.GetNumWagons(vehicle) - 1);
	AILog.Info("Added more wagons to " + AIVehicle.GetName(vehicle) + ".");
	// Restore the previous railtype
	AIRail.SetCurrentRailType(railtype);
}

