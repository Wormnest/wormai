/**
 * This file is part of WormAI: An OpenTTD AI.
 *
 * @file planner.nut Class that does planning for WormAI.
 * Based partially on code from SimpleAI.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2016.
 *
 */

/**
 * Define the WormRoute class which holds the details about a planned route.
 */
class WormRoute
{
	Cargo = 0;
	SourceID = 0;
	DestID = 0;
	SourceIsTown = false;
	DestIsTown = false;
	SourceLocation = 0;
	DestLocation = 0;
	IsSubsidy = false;
	SourceList = null;
	DestList = null;
	CargoList = null;
	double = null;
	distance_manhattan = null;

	/**
	 * Constructor for WormRoute class.
	 */
	constructor()
	{
		this.ResetRoute();
	}

	/**
	 * Resets variables in WormRoute class to default values.
	 */
	function ResetRoute()
	{
		Cargo = 0;							///< The cargo selected to be transported.
		SourceID = 0;						///< ID of source town or industry
		DestID = 0;							///< ID of destination town or industry
		SourceIsTown = false;				///< Is the source a town or cargo producing industry
		DestIsTown = false;					///< Is the destination a town or cargo receiving industry
		SourceLocation = 0;					///< Location (tile) of source
		DestLocation = 0;					///< Location (tile) of destionation
		IsSubsidy = false;					///< Whether this route is built to get a subsidy or not
		SourceList = null;
		DestList = null;
		CargoList = null;
		double = null;						///< Are we going to use double rail for this route or not
		distance_manhattan = null;			///< Manhattan distance between SourceLocation and DestLocation
	}
}

/**
 * Define the WormPlanner class which handles planning
 */
class WormPlanner
{
	static MIN_RAIL_ROUTE_LENGTH = 40;
	static MAX_RAIL_ROUTE_LENGTH = 200;
	static MIN_POPULATION_FOR_GOODS = 1500;
	static MIN_POPULATION_FOR_FOOD = 100;
	static MIN_TOWN_EFFECT_PRODUCTION = 40;
	static MAX_TRANSPORTED = 60;

	route = null;				///< Details about the route we planned.
	_rail_manager = null;
	_last_sub_tried = -1;		///< Last subsidy we tried.

	constructor (rail_manager)
	{
		route = WormRoute();
		_rail_manager = rail_manager;
		_last_sub_tried = -1;
	}

	/**
	 * Choose a subsidy if there is one available that suits us.
	 * @param planned_route A WormRoute class that will receive details about the planned route.
	 * @return True if a subsidy was chosen.
	 * @pre planned_route should be a valid WormRoute object.
	 */
	function GetSubsidizedRoute(planned_route);

	/**
	 * Find a cargo, a source and a destination to build a new service.
	 * @param planned_route A WormRoute class that will receive details about the planned route.
	 * @return True if a potential connection was found.
	 */
	function GetRoute(planned_route);

	/**
	 * Plan a rail route.
	 * @return True if we managed to find a route.
	 */
	function PlanRailRoute();

	/**
	 * Gets the CargoID associated with mail.
	 * @note Taken from SimpleAI.
	 * @return The CargoID of mail or null if no mail cargo was found.
	 */
	static function GetMailCargo();

	/**
	 * Get the percentage of transported cargo from a given industry.
	 * @param ind The IndustryID of the industry.
	 * @param cargo The cargo to be checked.
	 * @return The percentage transported, ranging from 0 to 100.
	 */
	static function GetLastMonthTransportedPercentage(ind, cargo);

}

function WormPlanner::GetSubsidizedRoute(planned_route)
{
	planned_route.IsSubsidy = true;
	local subs = AISubsidyList();
	// Exclude subsidies which have already been awarded to someone
	subs.Valuate(AISubsidy.IsAwarded);
	subs.KeepValue(0);
	// Exclude subsidies that will expire soon since pathfinding can take a while...
	subs.Valuate(AISubsidy.GetExpireDate);
	subs.KeepAboveValue(AIDate.GetCurrentDate()+100); // Should expire at least 100 days after today
	/// @todo Check if this gets sorted furthest or nearest expire date first.
	/// I think the highest value (thus furthest expire date) comes fist
	if (subs.Count() == 0) return false;
	//subs.Valuate(AIBase.RandItem);
	// WormAI: We don't want random but optimal profit
	// @todo Think of another sorting algorithm for optimal profit.
	foreach (sub, dummy in subs) {
		// Don't try the same subsidy again and again...
		if (sub == _last_sub_tried) continue;
		planned_route.Cargo = AISubsidy.GetCargoType(sub);
		planned_route.SourceIsTown = (AISubsidy.GetSourceType(sub) == AISubsidy.SPT_TOWN);
		planned_route.SourceID = AISubsidy.GetSourceIndex(sub); // ID of Town or Industry

		// Skip if we are already transporting this cargo from this source.
		if (_rail_manager.serviced.HasItem(planned_route.SourceID * 256 + planned_route.Cargo)) continue;

		if (planned_route.SourceIsTown) {
			planned_route.SourceLocation = AITown.GetLocation(planned_route.SourceID);
		} else {
			planned_route.SourceLocation = AIIndustry.GetLocation(planned_route.SourceID);
			// Skip this if there is already heavy competition there
			/// @todo Instead of GetSetting we should define a value for ourselves...
			/// @todo define a var/const instead of the fixed value we now use...
			if (AIIndustry.GetLastMonthTransported(planned_route.SourceID, planned_route.Cargo) > MAX_TRANSPORTED /*AIController.GetSetting("max_transported")*/) continue;
		}
		planned_route.DestIsTown = (AISubsidy.GetDestinationType(sub) == AISubsidy.SPT_TOWN);
		planned_route.DestID = AISubsidy.GetDestinationIndex(sub);
		if (planned_route.DestIsTown) {
			planned_route.DestLocation = AITown.GetLocation(planned_route.DestID);
		} else {
			planned_route.DestLocation = AIIndustry.GetLocation(planned_route.DestID);
		}
		// Check the distance
		planned_route.distance_manhattan = AIMap.DistanceManhattan(planned_route.SourceLocation, planned_route.DestLocation);
		if (planned_route.distance_manhattan > MAX_RAIL_ROUTE_LENGTH) continue;
		if (planned_route.distance_manhattan < MIN_RAIL_ROUTE_LENGTH) continue;
		_last_sub_tried = sub;
		return true;
	}
	return false;
}

function WormPlanner::GetRoute(planned_route)
{
	planned_route.IsSubsidy = false;
	planned_route.CargoList = AICargoList();
	planned_route.CargoList.Valuate(AIBase.RandItem);

	// If we have enough money then increase the length of the routes...
	local route_length_multiplier = 1;
	if (AICompany.GetLoanAmount() == 0) {
		local cur_money = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
		if (cur_money > WormMoney.InflationCorrection(1000000))
			route_length_multiplier = 2;
		else if (cur_money > WormMoney.InflationCorrection(5000000) &&
			(AIMap.GetMapSizeX() >= 1024) && (AIMap.GetMapSizeY() >= 1024))
			route_length_multiplier = 3;
	}

	// Choose a source
	foreach (icrg, dummy in planned_route.CargoList) {
		// Passengers only if we're using air
		//if (vehtype == AIVehicle.VT_AIR && AICargo.GetTownEffect(icrg) != AICargo.TE_PASSENGERS) continue;
		if (AICargo.GetTownEffect(icrg) != AICargo.TE_PASSENGERS && AICargo.GetTownEffect(icrg) != AICargo.TE_MAIL) {
			// If the source is an industry
			planned_route.SourceList = AIIndustryList_CargoProducing(icrg);
			// Should not be built on water
			planned_route.SourceList.Valuate(AIIndustry.IsBuiltOnWater);
			planned_route.SourceList.KeepValue(0);
			// There should be some production
			planned_route.SourceList.Valuate(AIIndustry.GetLastMonthProduction, icrg)
			planned_route.SourceList.KeepAboveValue(0);
			// Try to avoid excessive competition
			/// @todo !!
			planned_route.SourceList.Valuate(WormPlanner.GetLastMonthTransportedPercentage, icrg);
			planned_route.SourceList.KeepBelowValue(MAX_TRANSPORTED/*AIController.GetSetting("max_transported")*/);
			planned_route.SourceIsTown = false;
		} else {
			// If the source is a town
			planned_route.SourceList = AITownList();
			planned_route.SourceList.Valuate(AITown.GetLastMonthProduction, icrg);
			planned_route.SourceList.KeepAboveValue(MIN_TOWN_EFFECT_PRODUCTION);
			planned_route.SourceIsTown = true;
		}
		planned_route.SourceList.Valuate(AIBase.RandItem);
		foreach (isrc, dummy2 in planned_route.SourceList) {
			// Skip source if already serviced
			if (_rail_manager.serviced.HasItem(isrc * 256 + icrg)) continue;
			// Skip if an airport exists there and it has no free capacity
			/*
			local noairportcapacity = false;
			if (vehtype == AIVehicle.VT_AIR) {
				if (root.airports.HasItem(isrc)) {
					local airport = root.airports.GetValue(isrc);
					local airporttype = AIAirport.GetAirportType(AIStation.GetLocation(airport));
					if ((cBuilder.GetAirportTypeCapacity(airporttype) - AIVehicleList_Station(airport).Count()) < 2) noairportcapacity = true;
				}
			}
			if (noairportcapacity) continue;
			*/
			if (planned_route.SourceIsTown) planned_route.SourceLocation = AITown.GetLocation(isrc);
			else planned_route.SourceLocation = AIIndustry.GetLocation(isrc);
			if (AICargo.GetTownEffect(icrg) == AICargo.TE_NONE || AICargo.GetTownEffect(icrg) == AICargo.TE_WATER) {
				// If the destination is an industry
				planned_route.DestList = AIIndustryList_CargoAccepting(icrg);
				planned_route.DestIsTown = false;
				planned_route.DestList.Valuate(AIIndustry.GetDistanceManhattanToTile, planned_route.SourceLocation);
			} else {
				// If the destination is a town
				planned_route.DestList = AITownList();
				// Some minimum population values for towns
				switch (AICargo.GetTownEffect(icrg)) {
					case AICargo.TE_FOOD:
						planned_route.DestList.Valuate(AITown.GetPopulation);
						planned_route.DestList.KeepAboveValue(MIN_POPULATION_FOR_FOOD);
						break;
					case AICargo.TE_GOODS:
						planned_route.DestList.Valuate(AITown.GetPopulation);
						planned_route.DestList.KeepAboveValue(MIN_POPULATION_FOR_GOODS);
						break;
					default:
						planned_route.DestList.Valuate(AITown.GetLastMonthProduction, icrg);
						planned_route.DestList.KeepAboveValue(MIN_TOWN_EFFECT_PRODUCTION);
						break;
				}
				planned_route.DestIsTown = true;
				planned_route.DestList.Valuate(AITown.GetDistanceManhattanToTile, planned_route.SourceLocation);
			}

			// Check the distance of the source and the destination
			planned_route.DestList.KeepBelowValue(MAX_RAIL_ROUTE_LENGTH*route_length_multiplier);
			planned_route.DestList.KeepAboveValue(MIN_RAIL_ROUTE_LENGTH*route_length_multiplier);
			if (AICargo.GetTownEffect(icrg) == AICargo.TE_MAIL) planned_route.DestList.KeepBelowValue(110);

			planned_route.DestList.Valuate(AIBase.RandItem);
			foreach (idst, dummy3 in planned_route.DestList) {
				// Check if the destination has capacity for more planes
				/* noairportcapacity = false;
				if (vehtype == AIVehicle.VT_AIR) {
					if (root.airports.HasItem(idst)) {
						local airport = root.airports.GetValue(idst);
						local airporttype = AIAirport.GetAirportType(AIStation.GetLocation(airport));
						if ((cBuilder.GetAirportTypeCapacity(airporttype) - AIVehicleList_Station(airport).Count()) < 2) noairportcapacity = true;
					}
				}
				if (noairportcapacity) continue;
				*/
				if (planned_route.DestIsTown)
					planned_route.DestLocation = AITown.GetLocation(idst);
				else planned_route.DestLocation = AIIndustry.GetLocation(idst);
				planned_route.Cargo = icrg;
				planned_route.SourceID = isrc;
				planned_route.DestID = idst;
				return true;
			}
		}
	}
	return false;
}

function WormPlanner::PlanRailRoute()
{
	// Init route.
	route.ResetRoute();
	if (this.GetSubsidizedRoute(route)) {
		//AILog.Warning("-- Subsidy found");
	}
	else {
		//AILog.Warning("-- Subsidy NOT found, try find a normal route");
		// Reset route info
		route.ResetRoute();
		// Find a normal route
		if (this.GetRoute(route)) {
			//AILog.Warning("-- Route found");
		}
		else {
			AILog.Warning("Rail route planner: -- we didn't find a usable route --");
			return false;
		}
	}

	/* Compute distance of the route we planned. */
	route.distance_manhattan = AIMap.DistanceManhattan(route.SourceLocation, route.DestLocation);

	/* Decide whether to use single or double rails. */
	/// @todo replace number by a definied constant
	if (route.distance_manhattan > 80) route.double = true;
	else route.double = false;

	return true;
}

function WormPlanner::GetMailCargo()
{
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist) {
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL) return cargo;
	}
	return null;
}

function WormPlanner::GetLastMonthTransportedPercentage(ind, cargo)
{
	local production = AIIndustry.GetLastMonthProduction(ind, cargo);
	if (production > 0)
		return (100 * AIIndustry.GetLastMonthTransported(ind, cargo) / production);
	else
		return 0;
}

