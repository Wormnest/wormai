// ---------------------------------------
// WormAI: A test in writing an OpenTTD AI
// First version based on WrightAI
// ---------------------------------------
//
// License: GNU GPL - version 2 (see license.txt)
// Author: Wormnest (Jacob Boerema)
// Copyright: Jacob Boerema - 2013-2013
//
// 

// Import SuperLib
import("util.superlib", "SuperLib", 33);	// TODO: add version number in version.nut and use python to update that number */

Result <- SuperLib.Result;
Log <- SuperLib.Log;
Helper <- SuperLib.Helper;
Data <- SuperLib.DataStore;
ScoreList <- SuperLib.ScoreList;
Money <- SuperLib.Money;

Tile <- SuperLib.Tile;
Direction <- SuperLib.Direction;

Engine <- SuperLib.Engine;
Vehicle <- SuperLib.Vehicle;

Station <- SuperLib.Station;
Airport <- SuperLib.Airport;
Industry <- SuperLib.Industry;
Town <- SuperLib.Town;

Order <- SuperLib.Order;
OrderList <- SuperLib.OrderList;

Road <- SuperLib.Road;
RoadBuilder <- SuperLib.RoadBuilder;

// Import List library
import("AILib.List", "ExtendedList", 3);	// TODO: add version number in version.nut and use python to update that number */


/* Wormnest: define some constants for easier maintenance. */
const MINIMUM_BALANCE_BUILD_AIRPORT = 100000;	/* Minimum bank balance to start building airports. */
const MINIMUM_BALANCE_AIRCRAFT = 25000;			/* Minimum bank balance to allow buying a new aircraft. */
const MINIMUM_BALANCE_TWO_AIRCRAFT = 5000000;	/* Minimum bank balance to allow buying 2 aircraft at once. */
const AIRCRAFT_LOW_PRICE_CUT = 500000;			/* Bank balance below which we will try to buy a low price aircraft. */
const AIRCRAFT_MEDIUM_PRICE_CUT = 2000000;		/* Bank balance below which we will try to buy a medium price aircraft. */
const AIRCRAFT_LOW_PRICE = 50000;				/* Maximum price of a low price aircraft. */
const AIRCRAFT_MEDIUM_PRICE = 250000;			/* Maximum price of a medium price aircraft. */
const AIRCRAFT_HIGH_PRICE = 1500000;			/* Maximum price of a high price aircraft. */
const DEFAULT_DELAY_EVALUATE_AIRCRAFT = 25000;	/* Default delay for evaluating aircraft usefullness. */
const DEFAULT_DELAY_BUILD_AIRPORT = 500; 		/* Default delay before building a new airport route. */
const DEFAULT_DELAY_MANAGE_ROUTES = 1000;		/* Default delay for managing air routes. */
const DEFAULT_DELAY_HANDLE_LOAN = 2500;			/* Default delay for handling our loan. */
const DEFAULT_DELAY_HANDLE_EVENTS = 100;		/* Default delay for handling events. */
const STARTING_ACCEPTANCE_LIMIT = 150;			/* Starting limit in acceptance for finding suitable airport tile. */
const BAD_YEARLY_PROFIT = 10000;				/* Yearly profit limit below which profit is deemed bad. */

/* ERROR CODE constants */
const ALL_OK = 0;
const ERROR_FIND_AIRPORT1	= -1;				/* There was an error finding a spot for airport 1. */
const ERROR_FIND_AIRPORT2	= -2;				/* There was an error finding a spot for airport 2. */
const ERROR_BUILD_AIRPORT1	= -3;				/* There was an error building airport 1. */
const ERROR_BUILD_AIRPORT2	= -4;				/* There was an error building airport 2. */
const ERROR_MAX_AIRCRAFT = -10;					/* We have reached the maximum allowed number of aircraft. */
const ERROR_NOT_ENOUGH_MONEY = -20;				/* We don't have enough money. */
const ERROR_BUILD_AIRCRAFT = -30;				/* General error trying to build an aircraft. */
const ERROR_BUILD_AIRCRAFT_INVALID = -31;		/* No suitable aircraft found when trying to build an aircraft. */

class WormAI extends AIController {
	name = null;
	towns_used = null;
	route_1 = null;
	route_2 = null;
	distance_of_route = {};
	vehicle_to_depot = {};
	delay_build_airport_route = DEFAULT_DELAY_BUILD_AIRPORT;
	passenger_cargo_id = -1;

	/* WormAI: New variables added. */
	/* Variables that need to be saved into a savegame. */
	
	/* DO NOT SAVE variables below this line. These will not be saved. */ 
	loaded_from_save = false;
	engine_usefullness = null;
	acceptance_limit = STARTING_ACCEPTANCE_LIMIT;	/* Starting limit for passenger acceptance for airport finding. */
	aircraft_disabled_shown = 0;		/* Has the aircraft disabled in game settings message been shown (1) or not (0). */
	aircraft_max0_shown = 0;			/* Has the max aircraft is 0 in game settings message been shown. */

	function Start();

	constructor() {
		this.loaded_from_save = false;
		this.towns_used = AIList();
		this.route_1 = AIList();
		this.route_2 = AIList();
		this.engine_usefullness = AIList();
		this.acceptance_limit = STARTING_ACCEPTANCE_LIMIT;

		local list = AICargoList();
		for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
			if (AICargo.HasCargoClass(i, AICargo.CC_PASSENGERS)) {
				this.passenger_cargo_id = i;
				break;
			}
		}
	}
};

//////////////////////////////////////////////////////////////////////////
//	Debugging functions

function WormAI::DebugListTownsUsed()
{
	AILog.Info("---------- DEBUG towns_used ----------");
	if (!this.towns_used) {
		AILog.Warning("WARNING: towns_used is null!");
	}
	else {
		AILog.Info("Number of towns used: " + this.towns_used.Count())
		//foreach(t in towns_used) {
		for (local t = towns_used.Begin(); !towns_used.IsEnd(); t = towns_used.Next()) {
			AILog.Info("Town: " + AITown.GetName(t) + " (id: " + t + ", tile " + towns_used.GetValue(t) + ").")
		}
	}
	AILog.Info("");
}

function WormAI::DebugListRoute1()
{
	//this.route_1.AddItem(vehicle, tile_1);
	//this.route_2.AddItem(vehicle, tile_2);
	AILog.Info("---------- DEBUG route_1 ----------");
	if (!this.route_1) {
		AILog.Warning("WARNING: route_1 is null!");
	}
	else {
		AILog.Info("Number or routes used: " + this.route_1.Count());
		for (local r = route_1.Begin(); !route_1.IsEnd(); r = route_1.Next()) {
			AILog.Info("Aircraft: " + AIVehicle.GetName(r) + " (id: " + r + ", tile " + route_1.GetValue(r) + ").");
		}
	}
	AILog.Info("");
}

function WormAI::DebugListRouteInfo()
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

function WormAI::DebugListRoute2()
{
	//this.route_1.AddItem(vehicle, tile_1);
	//this.route_2.AddItem(vehicle, tile_2);
	AILog.Info("---------- DEBUG route_2 ----------");
	if (!this.route_1) {
		AILog.Warning("WARNING: route_2 is null!");
	}
	else {
		AILog.Info("Number routes used: " + this.route_2.Count());
		for (local r = route_2.Begin(); !route_2.IsEnd(); r = route_2.Next()) {
			AILog.Info("Aircraft: " + AIVehicle.GetName(r) + " (id: " + r + ", tile " + route_2.GetValue(r) + ").");
		}
	}
	AILog.Info("");
}

function WormAI::DebugListDistanceOfRoute()
{
	//this.distance_of_route.rawset(vehicle, AIMap.DistanceManhattan(tile_1, tile_2));
	AILog.Info("---------- DEBUG distance_of_route ----------");
	if (!this.route_1) {
		AILog.Warning("WARNING: route_2 is null!");
	}
	else {
		AILog.Info("Number routes used: " + this.route_2.Count());
		for (local r = route_2.Begin(); !route_2.IsEnd(); r = route_2.Next()) {
			AILog.Info("Aircraft: " + AIVehicle.GetName(r) + " (id: " + r + ", tile " + route_2.GetValue(r) + ").");
		}
	}
	AILog.Info("");
}

//	End debugging functions
//////////////////////////////////////////////////////////////////////////

/**
 * Check if we have enough money (via loan and on bank).
 */
function WormAI::HasMoney(money)
{
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) + (AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount()) > money) return true;
	return false;
}

/**
 * Get the amount of money requested, loan if needed.
 */
function WormAI::GetMoney(money)
{
	if (!this.HasMoney(money)) return;
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > money) return;

	local loan = money - AICompany.GetBankBalance(AICompany.COMPANY_SELF) + AICompany.GetLoanInterval() + AICompany.GetLoanAmount();
	loan = loan - loan % AICompany.GetLoanInterval();
	AILog.Info("Need a loan to get " + money + ": " + loan);
	AICompany.SetLoanAmount(loan);
}

/**
 * Build an airport route. Find 2 cities that are big enough and try to build airport in both cities.
 *  Then we can build an aircraft and make some money.
 */
function WormAI::BuildAirportRoute()
{
	// No sense building airports if we already have the max (or more because amount can be changed in game)
	if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) <= this.route_1.Count()) {
		AILog.Info("We already have the maximum number of aircraft. No sense in building an airport.");
		return ERROR_MAX_AIRCRAFT;
	}
	
	local airport_type = (AIAirport.IsValidAirportType(AIAirport.AT_LARGE) ? AIAirport.AT_LARGE : AIAirport.AT_SMALL);

	/* Get enough money to work with */
	this.GetMoney(150000);

	/* Show some info about what we are doing */
	AILog.Info(Helper.GetCurrentDateString() + " Trying to build an airport route");

	local tile_1 = this.FindSuitableAirportSpot(airport_type, 0);
	if (tile_1 < 0) return ERROR_FIND_AIRPORT1;
	local tile_2 = this.FindSuitableAirportSpot(airport_type, tile_1);
	if (tile_2 < 0) {
		this.towns_used.RemoveValue(tile_1);
		return ERROR_FIND_AIRPORT2;
	}

	/* Build the airports for real */
	if (!AIAirport.BuildAirport(tile_1, airport_type, AIStation.STATION_NEW)) {
		AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + tile_1 + ".");
		this.towns_used.RemoveValue(tile_1);
		this.towns_used.RemoveValue(tile_2);
		return ERROR_BUILD_AIRPORT1;
	}
	if (!AIAirport.BuildAirport(tile_2, airport_type, AIStation.STATION_NEW)) {
		AILog.Error("Although the testing told us we could build 2 airports, it still failed on the second airport at tile " + tile_2 + ".");
		AIAirport.RemoveAirport(tile_1);
		this.towns_used.RemoveValue(tile_1);
		this.towns_used.RemoveValue(tile_2);
		return ERROR_BUILD_AIRPORT1;
	}

	local ret = this.BuildAircraft(tile_1, tile_2, tile_1);
	if (ret < 0) {
		AIAirport.RemoveAirport(tile_1);
		AIAirport.RemoveAirport(tile_2);
		this.towns_used.RemoveValue(tile_1);
		this.towns_used.RemoveValue(tile_2);
	}
	else {
		local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
		if ((balance >= MINIMUM_BALANCE_TWO_AIRCRAFT) && (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) > this.route_1.Count())) {
			/* Build a second aircraft and start it at the other airport. */
			ret = this.BuildAircraft(tile_1, tile_2, tile_2);
		}
		AILog.Info("Done building a route");
	}

	AILog.Info("");
	
	return ret;
}

function WormAI::GetMaximumDistance(engine) {
	local max_dist = AIEngine.GetMaximumOrderDistance(engine);
	if (max_dist == 0) {
		/* Unlimited distance. Since we need to be able to keep values above a squared distance
		We set it to a predefined maximum value. Maps can be maximum 2048x2048. Diagonal will
		be more than that. To be safe we compute 10000 * 10000. */
		return 10000 * 10000;
	}
	else {
		return max_dist;
	}
}

/**
 * Build an aircraft with orders from tile_1 to tile_2.
 * The best available aircraft of that time will be bought.
 * start_tile is the tile where the airplane should start, or 0 to start at the first tile.
 */
function WormAI::BuildAircraft(tile_1, tile_2, start_tile)
{
	// Don't try to build aircraft if we already have the max (or more because amount can be changed in game)
	if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) <= this.route_1.Count()) {
		AILog.Warning("We already have the maximum number of aircraft. No sense in building an airport.");
		AILog.Info("");
		return ERROR_MAX_AIRCRAFT;
	}

	/* order_start_tile: where our order should start */
	local order_start_tile = start_tile;
	if (start_tile == 0) {
		order_start_tile = tile_1;
	}
	/* Build an aircraft */
	local hangar = AIAirport.GetHangarOfAirport(order_start_tile);
	local engine = null;
	local eng_price = 0;

	local engine_list = AIEngineList(AIVehicle.VT_AIR);

	/* When bank balance < AIRCRAFT_LOW_PRICE_CUT, buy cheaper planes */
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	
	/* Balance below a certain minimum? Wait until we buy more planes. */
	if (balance < MINIMUM_BALANCE_AIRCRAFT) {
		AILog.Warning("We are low on money (" + balance + "). We are not gonna buy an aircraft right now.");
		AILog.Info("");
		return ERROR_NOT_ENOUGH_MONEY;
	}
	
	engine_list.Valuate(AIEngine.GetPrice);
	engine_list.KeepBelowValue(balance < AIRCRAFT_LOW_PRICE_CUT ? AIRCRAFT_LOW_PRICE : (balance < AIRCRAFT_MEDIUM_PRICE_CUT ? AIRCRAFT_MEDIUM_PRICE : AIRCRAFT_HIGH_PRICE));

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

	//engine_list.Valuate(AIEngine.GetCapacity);
	//engine_list.KeepTop(1);
	engine_list.Valuate(WormAI.GetCostFactor, this.engine_usefullness);
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
		AILog.Info("++ Not the first vehicle: share orders.");
	}
	else {
		/* First vehicle with these orders. */
		//AIOrder.AppendOrder(vehicle, tile_1, AIOrder.OF_NONE);
		//AIOrder.AppendOrder(vehicle, tile_2, AIOrder.OF_NONE);
		// Test using full load
		AIOrder.AppendOrder(vehicle, tile_1, AIOrder.OF_FULL_LOAD_ANY);
		AIOrder.AppendOrder(vehicle, tile_2, AIOrder.OF_FULL_LOAD_ANY);
		AILog.Info("+ First vehicle: set orders.");
	}
	/* If vehicle should be started at another tile than tile_1 then skip to that order. */
	/* Currently always assumes it is tile_2 and that that is the second order, thus 1. */
	if (order_start_tile != tile_1) {
		AILog.Info("-- Order: skipping to other tile.");
		AIOrder.SkipToOrder(vehicle, 1);
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
 *  When a town is used, it is marked as such and not re-used.
 */
function WormAI::FindSuitableAirportSpot(airport_type, center_tile)
{
	local airport_x, airport_y, airport_rad;

	airport_x = AIAirport.GetAirportWidth(airport_type);
	airport_y = AIAirport.GetAirportHeight(airport_type);
	airport_rad = AIAirport.GetAirportCoverageRadius(airport_type);

	local town_list = AITownList();
	/* Remove all the towns we already used */
	town_list.RemoveList(this.towns_used);

	town_list.Valuate(AITown.GetPopulation);
	town_list.KeepAboveValue(GetSetting("min_town_size"));
	/* Keep the best 20, if we can't find 2 stations in there, just leave it anyway */
	/* Original value was 10. We increase it to 20 to make it more likely we will find
	   a town in case there are a lot of unsuitable locations. */
	town_list.KeepTop(20);
	town_list.Valuate(AIBase.RandItem);

	/* Now find 2 suitable towns */
	for (local town = town_list.Begin(); !town_list.IsEnd(); town = town_list.Next()) {
		/* Don't make this a CPU hog */
		Sleep(1);

		local tile = AITown.GetLocation(town);

		/* Create a 30x30 grid around the core of the town and see if we can find a spot for a small airport */
		local list = AITileList();
		/* XXX -- We assume we are more than 15 tiles away from the border! */
		list.AddRectangle(tile - AIMap.GetTileIndex(15, 15), tile + AIMap.GetTileIndex(15, 15));
		list.Valuate(AITile.IsBuildableRectangle, airport_x, airport_y);
		list.KeepValue(1);
		if (center_tile != 0) {
			/* If we have a tile defined, check to see if it's within the minimum and maximum allowed. */
			list.Valuate(AITile.GetDistanceSquareToTile, center_tile);
			local min_distance = GetSetting("min_airport_distance");
			local max_distance = GetSetting("max_airport_distance");
			/* Keep above minimum distance. */
			list.KeepAboveValue(min_distance * min_distance);
			/* Keep below maximum distance. */
			list.KeepBelowValue(max_distance * max_distance);
			// TODO: In early games with low maximum speeds we may need to adjust maximum and
			// maybe even minimum distance to get a round trip within a year.
		}
		/* Sort on acceptance, remove places that don't have acceptance */
		list.Valuate(AITile.GetCargoAcceptance, this.passenger_cargo_id, airport_x, airport_y, airport_rad);
		list.RemoveBelowValue(this.acceptance_limit);
		
		/** debug off
		for (tile = list.Begin(); !list.IsEnd(); tile = list.Next()) {
			AILog.Info("Town: " + AITown.GetName(town) + ", Tile: " + tile +
				", Passenger Acceptance: " + list.GetValue(tile));
		} **/

		/* Couldn't find a suitable place for this town, skip to the next */
		if (list.Count() == 0) continue;
		/* Walk all the tiles and see if we can build the airport at all */
		{
			local test = AITestMode();
			local good_tile = 0;

			for (tile = list.Begin(); !list.IsEnd(); tile = list.Next()) {
				Sleep(1);
				if (!AIAirport.BuildAirport(tile, airport_type, AIStation.STATION_NEW)) continue;
				good_tile = tile;
				break;
			}

			/* Did we find a place to build the airport on? */
			if (good_tile == 0) continue;
		}

		AILog.Info("Found a good spot for an airport in " + AITown.GetName(town) + " (id: "+ town + 
			", tile " + tile + ", acceptance: " + list.GetValue(tile) + ").");

		/* Mark the town as used, so we don't use it again */
		this.towns_used.AddItem(town, tile);

		return tile;
	}

	if (this.acceptance_limit > 25) {
		this.acceptance_limit -= 25;
		AILog.Info("Lowering acceptance limit for suitable airports to " + this.acceptance_limit );
	}
	else {
		this.acceptance_limit = 10;
	}
	AILog.Info("Couldn't find a suitable town to build an airport in");
	return -1;
}

function WormAI::ManageAirRoutes()
{
	local list = AIVehicleList();
	local low_profit_limit = 0;
	
	/* Show some info about what we are doing */
	AILog.Info(Helper.GetCurrentDateString() + " Managing air routes.");
	
	list.Valuate(AIVehicle.GetAge);
	/* Give the plane at least 2 full years to make a difference, thus check for 3 years old. */
	list.KeepAboveValue(365 * 3);
	list.Valuate(AIVehicle.GetProfitLastYear);

	/* Decide on the best low profit limit at this moment. */
	if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) > this.route_1.Count()) {
		/* Since we can still add more planes keep all planes that make at least some profit. */
		low_profit_limit = 0;
		list.KeepAboveValue(low_profit_limit);
	}
	else {
		// TODO: More extensive computation for limit.
		local list_count = 0;
		// Maybe something like 10% of highest profit aircraft?
		low_profit_limit = BAD_YEARLY_PROFIT;
		list_count = list.Count();
		list.KeepAboveValue(low_profit_limit);
		if ((list_count == list.Count()) && (list_count > 0)) {
			// All profits are above our current low_profit_limit
			// Get vehicle with last years highest profit
			local highest = AIList();
			highest.AddList(list);
			highest.KeepTop(1);
			local v = highest.Begin();
			high_profit = highest.GetValue(v);
			// get profits below 20% of that
			low_profit_limit = high_profit * 20 / 100;
			list.KeepAboveValue(low_profit_limit);
			AILog.Info("...Computed low_profit_limit: " + low_profit_limit);
		}
		
	}

	for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
		local profit = list.GetValue(i);
		/* Profit last year and this year bad? Let's sell the vehicle */
		/* If we are below maximum number of aircraft use a less strict value. */
		if (profit < low_profit_limit && AIVehicle.GetProfitThisYear(i) < low_profit_limit) {
			/* Send the vehicle to depot if we didn't do so yet */
			if (!vehicle_to_depot.rawin(i) || vehicle_to_depot.rawget(i) != true) {
				AILog.Info("--> Sending " + AIVehicle.GetName(i) + " (id: " + i + ") to depot as profit is: " + profit + " / " + AIVehicle.GetProfitThisYear(i));
				AIVehicle.SendVehicleToDepot(i);
				vehicle_to_depot.rawset(i, true);
			}
		}
		/* Try to sell it over and over till it really is in the depot */
		if (vehicle_to_depot.rawin(i) && vehicle_to_depot.rawget(i) == true) {
			local veh_name = AIVehicle.GetName(i);
			if (AIVehicle.SellVehicle(i)) {
				AILog.Info("--> Sold " + veh_name + " (id: " + i + ").");
				/* Check if we are the last one serving those airports; else sell the airports */
				local list2 = AIVehicleList_Station(AIStation.GetStationID(this.route_1.GetValue(i)));
				if (list2.Count() == 0) {
					local t1 = this.route_1.GetValue(i);
					local t2 = this.route_2.GetValue(i);
					this.SellAirports(t1, t2);
				}
				/* Remove the aircraft from the routes. */
				this.route_1.RemoveItem(i);
				this.route_2.RemoveItem(i);
				/* Remove aircraft from our to_depot list. */
				vehicle_to_depot.rawdelete(i);
			}
		}
	}

	/* Don't try to add planes when we are short on cash */
	if (!this.HasMoney(AIRCRAFT_LOW_PRICE)) return ERROR_NOT_ENOUGH_MONEY;
	else if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) <= this.route_1.Count()) {
		// No sense building plane if we already have the max (or more because amount can be changed in game)
		AILog.Info("We already have the maximum number of aircraft. No sense in checking if we need to add planes.");
		return ERROR_MAX_AIRCRAFT;
	}


	list = AIStationList(AIStation.STATION_AIRPORT);
	list.Valuate(AIStation.GetCargoWaiting, this.passenger_cargo_id);
	list.KeepAboveValue(250);

	for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
		local list2 = AIVehicleList_Station(i);
		/* No vehicles going to this station, abort and sell */
		if (list2.Count() == 0) {
			AILog.Warning("***** Encountered station without vehicles, should not happen? *****");
			local t1 = this.route_1.GetValue(i);
			local t2 = this.route_2.GetValue(i);
			this.SellAirports(t1, t2);
			continue;
		};

		/* Find the first vehicle that is going to this station */
		local v = list2.Begin();
		local dist = this.distance_of_route.rawget(v);

		list2.Valuate(AIVehicle.GetAge);
		list2.KeepBelowValue(dist);
		/* Do not build a new vehicle if we bought a new one in the last DISTANCE days */
		if (list2.Count() != 0) continue;

		AILog.Info("Station " + AIStation.GetName(i) + "(id: " + i + ", location: " + AIStation.GetLocation(i) + ") has a lot of waiting passengers (cargo), adding a new aircraft for the route.");

		/* Make sure we have enough money */
		this.GetMoney(AIRCRAFT_LOW_PRICE);

		return this.BuildAircraft(this.route_1.GetValue(v), this.route_2.GetValue(v), 0);
	}
}

/**
  * Sells the airports from tile_1 and tile_2
  * Removes towns from towns_used list too
  */
function WormAI::SellAirports(airport_1_tile, airport_2_tile) {
	/* Remove the airports */
	AILog.Info("==> Removing airports at tile " + airport_1_tile + " and " + 
		airport_2_tile + " since they are not used anymore");
	AIAirport.RemoveAirport(airport_1_tile);
	AIAirport.RemoveAirport(airport_2_tile);
	/* Free the towns_used entries */
	this.towns_used.RemoveValue(airport_1_tile);
	this.towns_used.RemoveValue(airport_2_tile);
}

function WormAI::HandleEvents()
{
	while (AIEventController.IsEventWaiting()) {
		local e = AIEventController.GetNextEvent();
		switch (e.GetEventType()) {
			case AIEvent.ET_VEHICLE_CRASHED: {
				local ec = AIEventVehicleCrashed.Convert(e);
				local v = ec.GetVehicleID();
				AILog.Info("We have a crashed aircraft (" + v + "), buying a new one as replacement");
				this.BuildAircraft(this.route_1.GetValue(v), this.route_2.GetValue(v), 0);
				this.route_1.RemoveItem(v);
				this.route_2.RemoveItem(v);
			} break;

			default:
				break;
		}
	}
}

function WormAI::EvaluateAircraft() {
	/* Show some info about what we are doing */
	AILog.Info(Helper.GetCurrentDateString() + " Evaluating aircraft.");
	
	local engine_list = AIEngineList(AIVehicle.VT_AIR);
	//engine_list.Valuate(AIEngine.GetPrice);
	//engine_list.KeepBelowValue(balance < AIRCRAFT_LOW_PRICE_CUT ? AIRCRAFT_LOW_PRICE : (balance < AIRCRAFT_MEDIUM_PRICE_CUT ? AIRCRAFT_MEDIUM_PRICE : AIRCRAFT_HIGH_PRICE));

	engine_list.Valuate(AIEngine.GetCargoType);
	engine_list.KeepValue(this.passenger_cargo_id);

	// Only use this one when debugging:
	//engine_list.Valuate(AIEngine.GetCapacity);
	
	// First fill temporary list with our usefullness factors
	local factor_list = AIList();
	
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
			AILog.Info("Engine: " + AIEngine.GetName(engine) + ", price: " + AIEngine.GetPrice(engine) +
				", yearly running costs: " + AIEngine.GetRunningCost(engine));
			AILog.Info( "    Capacity: " + AIEngine.GetCapacity(engine) + ", Maximum speed: " + 
				AIEngine.GetMaxSpeed(engine) + ", Maximum distance: " + AIEngine.GetMaximumOrderDistance(engine));
			AILog.Warning("    Aircraft usefulness factors d: " + distance_per_year + ", p: " + pass_per_year +
				", pass cost factor: " + cost_per_pass);

			// Add the cost factor to our temporary list
			factor_list.AddItem(engine,cost_per_pass);
		}
	}
	this.engine_usefullness.Clear();
	this.engine_usefullness.AddList(factor_list);
	AILog.Info("usefullness list count: " + this.engine_usefullness.Count());
}

function WormAI::GetCostFactor(engine, costfactor_list) {
	// For some reason we can't access this.engine_usefullness from inside the Valuate function,
	// thus we add that as a parameter
	//AILog.Info("usefullness list count: " + costfactor_list.Count());
	if (costfactor_list == null) {
		return 0;
	}
	else {
		return costfactor_list.GetValue(engine);
		//return AIEngine.GetCapacity(engine);
	}
}

function WormAI::Start()
{
	if (this.passenger_cargo_id == -1) {
		AILog.Error("WormAI could not find the passenger cargo");
		return;
	}

	/* Give the boy a name */
	if (!AICompany.SetName("WormAI")) {
		local i = 2;
		while (!AICompany.SetName("WormAI #" + i)) {
			i++;
		}
	}
	this.name = AICompany.GetName(AICompany.COMPANY_SELF);
	/* Say hello to the user */
	AILog.Info("Welcome to WormAI. I am currently in development.");
	AILog.Info("These are our current AI settings:");
	AILog.Info("- Minimum Town Size: " + GetSetting("min_town_size"));
	AILog.Info("- Minimum Airport Distance: " + GetSetting("min_airport_distance"));
	AILog.Info("- Maximum Airport Distance: " + GetSetting("max_airport_distance"));
	AILog.Info("----------------------------------");

	if (loaded_from_save) {
		/* Debugging info */
		DebugListTownsUsed();
		// We need to redo distance_of_route table
		foreach( veh, tile_1 in route_1) {
			local tile_2 = route_2.GetValue(veh);
			AILog.Info("Vehicle: " + veh + " tile1: " + tile_1 + " tile2: " + tile_2);
			AILog.Info("Distance: " + AIMap.DistanceManhattan(tile_1, tile_2));
			this.distance_of_route.rawset(veh, AIMap.DistanceManhattan(tile_1, tile_2));
		}
		/* Debugging info */
		DebugListRouteInfo();
	}
	
	/* We start with almost no loan, and we take a loan when we want to build something */
	AICompany.SetLoanAmount(AICompany.GetLoanInterval());

	/* We need our local ticker, as GetTick() will skip ticks */
	local ticker = 0;
	/* Determine time we may sleep */
	local sleepingtime = 100;
	if (this.delay_build_airport_route < sleepingtime)
		sleepingtime = this.delay_build_airport_route;

	/* Let's go on for ever */
	while (true) {
		/* Need to check if we can build aircraft and how many. Since this can change we do it inside the loop. */
		if (AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_AIR)) {
			if (aircraft_disabled_shown == 0) {
				AILog.Warning("Using aircraft is disabled in your game settings. Since this AI currently only uses aircraft it will not build anything until you change this setting.")
				aircraft_disabled_shown = 1;
			}
		}
		else if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) == 0) {
			if (aircraft_max0_shown == 0) {
				AILog.Warning("Amount of allowed aircraft for AI is set to 0 in your game settings. This means we can't build any aircraft which is currently our only option.")
				aircraft_max0_shown = 1;
			}
		}
		else {
			/* Evaluate the available aircraft once in a while. */
			if ((ticker % DEFAULT_DELAY_EVALUATE_AIRCRAFT == 0 || ticker == 0)) {
				this.EvaluateAircraft();
				/* Debugging info 
				DebugListTownsUsed();
				DebugListRouteInfo(); */
			}
			/* Once in a while, with enough money, try to build something */
			if ((ticker % this.delay_build_airport_route == 0 || ticker == 0) && this.HasMoney(MINIMUM_BALANCE_BUILD_AIRPORT)) {
				local ret = this.BuildAirportRoute();
				if ((ret == ERROR_FIND_AIRPORT1) || (ret == ERROR_MAX_AIRCRAFT)&& ticker != 0) {
					/* No more route found or we have max allowed aircraft, delay even more before trying to find an other */
					this.delay_build_airport_route = 10 * DEFAULT_DELAY_BUILD_AIRPORT;
				}
				else {
					/* Set default delay back in case we had it increased, see above. */
					this.delay_build_airport_route = DEFAULT_DELAY_BUILD_AIRPORT;
				}
			}
			/* Manage the routes once in a while */
			if (ticker % DEFAULT_DELAY_MANAGE_ROUTES == 0) {
				this.ManageAirRoutes();
			}
			/* Try to get rid of our loan once in a while */
			if (ticker % DEFAULT_DELAY_HANDLE_LOAN == 0) {
				AICompany.SetLoanAmount(0);
			}
			/* Check for events once in a while */
			if (ticker % DEFAULT_DELAY_HANDLE_EVENTS == 0) {
				this.HandleEvents();
			}
		}

		/* Make sure we do not create infinite loops */
		Sleep(sleepingtime);
		ticker += sleepingtime;
	}
}

 function WormAI::Save()
 {
   /* Debugging info */
	local MyOps1 = this.GetOpsTillSuspend();
	local MyOps2 = 0;
/* only use for debugging:
    AILog.Warning("Saving data to savegame not implemented yet!");
    AILog.Info("Ops till suspend: " + this.GetOpsTillSuspend());
    AILog.Info("");
*/
    /* Save the data */
    local table = {
		townsused = null,
		route1 = null,
		route2 = null,
	};
	local t = ExtendedList();
	local r1 = ExtendedList();
	local r2 = ExtendedList();
	t.AddList(this.towns_used);
	table.townsused = t.toarray();
	r1.AddList(this.route_1);
	table.route1 = r1.toarray();
	r2.AddList(this.route_2);
	table.route2 = r2.toarray();
	
    /* Debugging info 
    DebugListTownsUsed();
    DebugListRouteInfo();
*/   
/* only use for debugging:
    AILog.Info("Tick: " + this.GetTick() );
*/
    MyOps2 = this.GetOpsTillSuspend();
	if (MyOps2 < 10000) {
		AILog.Error("SAVE: Using almost all allowed ops: " + MyOps2 );
	}
	else if (MyOps2 < 20000) {
		AILog.Warning("SAVE: Using a high amount of ops: " + MyOps2 );
	}
	else {
		AILog.Info("Saving WormAI game data. Used ops: " + (MyOps1-MyOps2) );
	}
   
    return table;
 }
 
 function WormAI::Load(version, data)
 {
   /* Debugging info */
	local MyOps1 = this.GetOpsTillSuspend();
	local MyOps2 = 0;
	AILog.Info("Loading savegame saved by WormAI version " + version);
	// TODO: load data in temp values then later unpack it because
	// load has limited time available
	if ("townsused" in data) {
		local t = ExtendedList();
		t.AddFromArray(data.townsused)
		towns_used.AddList(t);
	}
	if ("route1" in data) {
		local r = ExtendedList();
		r.AddFromArray(data.route1)
		route_1.AddList(r);
	}
	if ("route2" in data) {
		local r = ExtendedList();
		r.AddFromArray(data.route2)
		route_2.AddList(r);
	}
	loaded_from_save = true;

    /* Debugging info */
    MyOps2 = this.GetOpsTillSuspend();
	if (MyOps2 < 10000) {
		AILog.Error("LOAD: Using almost all allowed ops: " + MyOps2 );
	}
	else if (MyOps2 < 20000) {
		AILog.Warning("LOAD: Using a high amount of ops: " + MyOps2 );
	}
	else {
		AILog.Info("Loading WormAI game data. Used ops: " + (MyOps1-MyOps2) );
		//AILog.Info("Loading: ops till suspend: " + MyOps2 + ", ops used in load: " + (MyOps1-MyOps2) );
	}
 }
 