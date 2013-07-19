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
import("util.superlib", "SuperLib", 32);	// TODO: add version number in version.nut and use python to update that number */

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
const AIRCRAFT_LOW_PRICE_CUT = 500000;			/* Bank balance below which we will try to buy a low price aircraft. */
const AIRCRAFT_MEDIUM_PRICE_CUT = 2000000;		/* Bank balance below which we will try to buy a medium price aircraft. */
const AIRCRAFT_LOW_PRICE = 50000;				/* Maximum price of a low price aircraft. */
const AIRCRAFT_MEDIUM_PRICE = 250000;			/* Maximum price of a medium price aircraft. */
const AIRCRAFT_HIGH_PRICE = 1500000;			/* Maximum price of a high price aircraft. */
const DEFAULT_DELAY_BUILD_AIRPORT = 750; 		/* Default delay before building a new airport route. */
const BAD_YEARLY_PROFIT = 10000;				/* Yearly profit limit below which profit is deemed bad. */


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
	aircraft_disabled_shown = 0;		/* Has the aircraft disabled in game settings message been shown (1) or not (0). */
	aircraft_max0_shown = 0;			/* Has the max aircraft is 0 in game settings message been shown. */

	function Start();

	constructor() {
		loaded_from_save = false;
		this.towns_used = AIList();
		this.route_1 = AIList();
		this.route_2 = AIList();
		this.engine_usefullness = AIList();

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
	if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) >= this.route_1.Count()) {
		AILog.Info("We already have the maximum number of aircraft. No sense in building an airport.");
		return -10;
	}
	
	local airport_type = (AIAirport.IsValidAirportType(AIAirport.AT_LARGE) ? AIAirport.AT_LARGE : AIAirport.AT_SMALL);

	/* Get enough money to work with */
	this.GetMoney(150000);

	/* Show some info about what we are doing */
	AILog.Info(Helper.GetCurrentDateString() + " Trying to build an airport route");

	local tile_1 = this.FindSuitableAirportSpot(airport_type, 0);
	if (tile_1 < 0) return -1;
	local tile_2 = this.FindSuitableAirportSpot(airport_type, tile_1);
	if (tile_2 < 0) {
		this.towns_used.RemoveValue(tile_1);
		return -2;
	}

	/* Build the airports for real */
	if (!AIAirport.BuildAirport(tile_1, airport_type, AIStation.STATION_NEW)) {
		AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + tile_1 + ".");
		this.towns_used.RemoveValue(tile_1);
		this.towns_used.RemoveValue(tile_2);
		return -3;
	}
	if (!AIAirport.BuildAirport(tile_2, airport_type, AIStation.STATION_NEW)) {
		AILog.Error("Although the testing told us we could build 2 airports, it still failed on the second airport at tile " + tile_2 + ".");
		AIAirport.RemoveAirport(tile_1);
		this.towns_used.RemoveValue(tile_1);
		this.towns_used.RemoveValue(tile_2);
		return -4;
	}

	local ret = this.BuildAircraft(tile_1, tile_2);
	if (ret < 0) {
		AIAirport.RemoveAirport(tile_1);
		AIAirport.RemoveAirport(tile_2);
		this.towns_used.RemoveValue(tile_1);
		this.towns_used.RemoveValue(tile_2);
	}
	else {
		AILog.Info("Done building a route");
	}

	AILog.Info("");
	
	return ret;
}

/**
 * Build an aircraft with orders from tile_1 to tile_2.
 *  The best available aircraft of that time will be bought.
 */
function WormAI::BuildAircraft(tile_1, tile_2)
{
	// Don't try to build aircraft if we already have the max (or more because amount can be changed in game)
	if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) >= this.route_1.Count()) {
		AILog.Info("We already have the maximum number of aircraft. No sense in building an airport.");
		return -10;
	}

	/* Build an aircraft */
	local hangar = AIAirport.GetHangarOfAirport(tile_1);
	local engine = null;
	local eng_price = 0;

	local engine_list = AIEngineList(AIVehicle.VT_AIR);

	/* When bank balance < AIRCRAFT_LOW_PRICE_CUT, buy cheaper planes */
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	
	/* Balance below a certain minimum? Wait until we buy more planes. */
	if (balance < MINIMUM_BALANCE_AIRCRAFT) {
		AILog.Warning("We are low on money (" + balance + "). We are not gonna buy an aircraft right now.");
		return -6;
	}
	
	engine_list.Valuate(AIEngine.GetPrice);
	engine_list.KeepBelowValue(balance < AIRCRAFT_LOW_PRICE_CUT ? AIRCRAFT_LOW_PRICE : (balance < AIRCRAFT_MEDIUM_PRICE_CUT ? AIRCRAFT_MEDIUM_PRICE : AIRCRAFT_HIGH_PRICE));

	engine_list.Valuate(AIEngine.GetCargoType);
	engine_list.KeepValue(this.passenger_cargo_id);

	//engine_list.Valuate(AIEngine.GetCapacity);
	//engine_list.KeepTop(1);
	engine_list.Valuate(WormAI.GetCostFactor, this.engine_usefullness);
	engine_list.KeepBottom(1);

	engine = engine_list.Begin();

	if (!AIEngine.IsValidEngine(engine)) {
		AILog.Warning("Couldn't find a suitable aircraft. Most likely we don't have enough available funds,");
		return -5;
	}
	/* Price of cheapest engine can be more than our bank balance, check for that. */
	eng_price = AIEngine.GetPrice(engine);
	if (eng_price > balance) {
		AILog.Warning("Can't buy aircraft. The cheapest selected aircraft (" + eng_price + ") costs more than our available funds (" + balance + ").");
		return -6;
	}
	local vehicle = AIVehicle.BuildVehicle(hangar, engine);
	if (!AIVehicle.IsValidVehicle(vehicle)) {
		AILog.Error("Couldn't build the aircraft: " + AIEngine.GetName(engine));
		return -6;
	}
	/* Send him on his way */
	AIOrder.AppendOrder(vehicle, tile_1, AIOrder.OF_NONE);
	AIOrder.AppendOrder(vehicle, tile_2, AIOrder.OF_NONE);
	AIVehicle.StartStopVehicle(vehicle);
	this.distance_of_route.rawset(vehicle, AIMap.DistanceManhattan(tile_1, tile_2));
	this.route_1.AddItem(vehicle, tile_1);
	this.route_2.AddItem(vehicle, tile_2);

	AILog.Info("Finished building aircraft " + AIVehicle.GetName(vehicle) + ", type: " + 
		AIEngine.GetName(engine) + ", price: " + eng_price );
	AILog.Info("Yearly running costs: " + AIEngine.GetRunningCost(engine) + ",  capacity: " + 
		AIEngine.GetCapacity(engine) + ", Maximum speed: " + AIEngine.GetMaxSpeed(engine) +
		", Maximum distance: " + AIEngine.GetMaximumOrderDistance(engine));

	return 0;
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
	/* Keep the best 10, if we can't find 2 stations in there, just leave it anyway */
	town_list.KeepTop(10);
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
			/* If we have a tile defined, we don't want to be within 25 tiles of this tile */
			list.Valuate(AITile.GetDistanceSquareToTile, center_tile);
			list.KeepAboveValue(625);
		}
		/* Sort on acceptance, remove places that don't have acceptance */
		list.Valuate(AITile.GetCargoAcceptance, this.passenger_cargo_id, airport_x, airport_y, airport_rad);
		list.RemoveBelowValue(10);

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

			/* Did we found a place to build the airport on? */
			if (good_tile == 0) continue;
		}

		AILog.Info("Found a good spot for an airport in " + AITown.GetName(town) + " (id: "+ town + ", tile " + tile + ").");

		/* Make the town as used, so we don't use it again */
		this.towns_used.AddItem(town, tile);

		return tile;
	}

	AILog.Info("Couldn't find a suitable town to build an airport in");
	return -1;
}

function WormAI::ManageAirRoutes()
{
	local list = AIVehicleList();
	
	/* Show some info about what we are doing */
	AILog.Info(Helper.GetCurrentDateString() + " Managing air routes.");
	
	list.Valuate(AIVehicle.GetAge);
	/* Give the plane at least 2 full years to make a difference, thus check for 3 years old. */
	list.KeepAboveValue(365 * 3);
	list.Valuate(AIVehicle.GetProfitLastYear);

	for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
		local profit = list.GetValue(i);
		/* Profit last year and this year bad? Let's sell the vehicle */
		if (profit < BAD_YEARLY_PROFIT && AIVehicle.GetProfitThisYear(i) < BAD_YEARLY_PROFIT) {
			/* Send the vehicle to depot if we didn't do so yet */
			if (!vehicle_to_depot.rawin(i) || vehicle_to_depot.rawget(i) != true) {
				AILog.Info("Sending " + i + " to depot as profit is: " + profit + " / " + AIVehicle.GetProfitThisYear(i));
				AIVehicle.SendVehicleToDepot(i);
				vehicle_to_depot.rawset(i, true);
			}
		}
		/* Try to sell it over and over till it really is in the depot */
		if (vehicle_to_depot.rawin(i) && vehicle_to_depot.rawget(i) == true) {
			if (AIVehicle.SellVehicle(i)) {
				AILog.Info("Selling " + i + " as it finally is in a depot.");
				/* Check if we are the last one serving those airports; else sell the airports */
				local list2 = AIVehicleList_Station(AIStation.GetStationID(this.route_1.GetValue(i)));
				if (list2.Count() == 0) this.SellAirports(i);
				vehicle_to_depot.rawdelete(i);
			}
		}
	}

	/* Don't try to add planes when we are short on cash */
	if (!this.HasMoney(AIRCRAFT_LOW_PRICE)) return;
	else if (Vehicle.GetVehicleLimit(AIVehicle.VT_AIR) >= this.route_1.Count()) {
		// No sense building plane if we already have the max (or more because amount can be changed in game)
		AILog.Info("We already have the maximum number of aircraft. No sens in checking if we need to add planes.");
		return -10;
	}


	list = AIStationList(AIStation.STATION_AIRPORT);
	list.Valuate(AIStation.GetCargoWaiting, this.passenger_cargo_id);
	list.KeepAboveValue(250);

	for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
		local list2 = AIVehicleList_Station(i);
		/* No vehicles going to this station, abort and sell */
		if (list2.Count() == 0) {
			this.SellAirports(i);
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

		return this.BuildAircraft(this.route_1.GetValue(v), this.route_2.GetValue(v));
	}
}

/**
  * Sells the airports from route index i
  * Removes towns from towns_used list too
  */
function WormAI::SellAirports(i) {
	/* Remove the airports */
	AILog.Info("Removing airports as nobody serves them anymore.");
	AIAirport.RemoveAirport(this.route_1.GetValue(i));
	AIAirport.RemoveAirport(this.route_2.GetValue(i));
	/* Free the towns_used entries */
	this.towns_used.RemoveValue(this.route_1.GetValue(i));
	this.towns_used.RemoveValue(this.route_2.GetValue(i));
	/* Remove the route */
	this.route_1.RemoveItem(i);
	this.route_2.RemoveItem(i);
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
				this.BuildAircraft(this.route_1.GetValue(v), this.route_2.GetValue(v));
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
		local _eval_distance = 100000;	// assumed distance for passengers to travel
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
			if ((ticker % 25000 == 0 || ticker == 0)) {
				this.EvaluateAircraft();
			}
			/* Once in a while, with enough money, try to build something */
			if ((ticker % this.delay_build_airport_route == 0 || ticker == 0) && this.HasMoney(MINIMUM_BALANCE_BUILD_AIRPORT)) {
				local ret = this.BuildAirportRoute();
				if (ret == -1 && ticker != 0) {
					/* No more route found, delay even more before trying to find an other */
					this.delay_build_airport_route = 10 * DEFAULT_DELAY_BUILD_AIRPORT;
				}
				else if (ret < 0 && ticker == 0 && !loaded_from_save) {
					/* The AI failed to build a first airport and is deemed */
					/* AICompany.SetName("Failed " + this.name); */
					AILog.Error("Failed to build first airport route. Repaying loan.");
					AICompany.SetLoanAmount(0);
					/* return; - Wormnest: we don't wanna end with a crash even if we can't build anything! */
				}
			}
			/* Manage the routes once in a while */
			if (ticker % 2000 == 0) {
				this.ManageAirRoutes();
			}
			/* Try to get rid of our loan once in a while */
			if (ticker % 5000 == 0) {
				AICompany.SetLoanAmount(0);
			}
			/* Check for events once in a while */
			if (ticker % 100 == 0) {
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
	
    //TODO: Add your save data to the table.

    /* Debugging info */
    DebugListTownsUsed();
    DebugListRouteInfo();
   
/* only use for debugging:
    AILog.Info("Tick: " + this.GetTick() );
*/
    MyOps2 = this.GetOpsTillSuspend();
    AILog.Info("Saving: ops till suspend: " + MyOps2 + ", ops used in save: " + (MyOps1-MyOps2) );
    AILog.Info("");
   
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
    AILog.Info("Loading: ops till suspend: " + MyOps2 + ", ops used in load: " + (MyOps1-MyOps2) );
    AILog.Info("");
 }
 