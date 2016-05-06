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
	}
}

/**
 * Define the WormPlanner class which handles planning
 */
class WormPlanner
{

	route = null;				///< Details about the route we planned.
	_rail_manager = null;
	
	constructor (rail_manager)
	{
		route = WormRoute();
		_rail_manager = rail_manager;
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
	 * Builder class variables set: crglist, crg, srclist, src, dstlist, dst,
	 *   srcistown, dstistown, srcplace, dstplace
	 * @return True if a potential connection was found.
	 */
	function GetRoute(planned_route);

	/**
	 *  Plan a rail route.
	 */
	function PlanRailRoute();
}

function WormPlanner::GetSubsidizedRoute(planned_route)
{
	planned_route.IsSubsidy = true;
	local subs = AISubsidyList();
	// Exclude subsidies which have already been awarded to someone
	subs.Valuate(AISubsidy.IsAwarded);
	subs.KeepValue(0);
	if (subs.Count() == 0) return false;
	subs.Valuate(AIBase.RandItem);
	// WormAI: We don't want random but optimal profit
	// @todo Think of another sorting algorithm for optimal profit.
	foreach (sub, dummy in subs) {
		planned_route.Cargo = AISubsidy.GetCargoType(sub);
		planned_route.SourceIsTown = (AISubsidy.GetSourceType(sub) == AISubsidy.SPT_TOWN);
		planned_route.SourceID = AISubsidy.GetSourceIndex(sub); // ID of Town or Industry
		
		// Skip if we are already transporting this cargo from this source.
		if (_rail_manager._serviced.HasItem(planned_route.SourceID * 256 + planned_route.Cargo)) continue;
		
		// Some random chance not to choose this subsidy
		//if (!AIBase.Chance(AIController.GetSetting("subsidy_chance"), 11) || (!root.use_roadvehs && !root.use_trains)) continue;
		
		if (planned_route.SourceIsTown) {
			planned_route.SourceLocation = AITown.GetLocation(planned_route.SourceID);
		} else {
			planned_route.SourceLocation = AIIndustry.GetLocation(planned_route.SourceID);
			// Skip this if there is already heavy competition there
			/// @todo Instead of GetSetting we should define a value for ourselves...
			//if (AIIndustry.GetLastMonthTransported(planned_route.SourceID, planned_route.cargo) > AIController.GetSetting("max_transported")) continue;
		}
		planned_route.DestIsTown = (AISubsidy.GetDestinationType(sub) == AISubsidy.SPT_TOWN);
		planned_route.DestID = AISubsidy.GetDestinationIndex(sub);
		if (planned_route.DestIsTown) {
			planned_route.DestLocation = AITown.GetLocation(planned_route.DestID);
		} else {
			planned_route.DestLocation = AIIndustry.GetLocation(planned_route.DestID);
		}
		// Check the distance
		// @todo Change the values here to constants!
		if (AIMap.DistanceManhattan(planned_route.SourceLocation, planned_route.DestLocation) > 200) continue;
		if (AIMap.DistanceManhattan(planned_route.SourceLocation, planned_route.DestLocation) < 40) continue;
		return true;
	}
	return false;
}

function WormPlanner::GetRoute(planned_route)
{
	planned_route.IsSubsidy = false;
	planned_route.CargoList = AICargoList();
	planned_route.CargoList.Valuate(AIBase.RandItem);
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
			//planned_route.SourceList.Valuate(cBuilder.GetLastMonthTransportedPercentage, icrg);
			//planned_route.SourceList.KeepBelowValue(AIController.GetSetting("max_transported"));
			planned_route.SourceIsTown = false;
		} else {
			// If the source is a town
			planned_route.SourceList = AITownList();
			planned_route.SourceList.Valuate(AITown.GetLastMonthProduction, icrg);
			/// @todo adapt this value (40) move it to a constant or var
			planned_route.SourceList.KeepAboveValue(40);
			planned_route.SourceIsTown = true;
		}
		planned_route.SourceList.Valuate(AIBase.RandItem);
		foreach (isrc, dummy2 in planned_route.SourceList) {
			// Skip source if already serviced
			if (_rail_manager._serviced.HasItem(isrc * 256 + icrg)) continue;
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
						planned_route.DestList.KeepAboveValue(100);
						break;
					case AICargo.TE_GOODS:
						planned_route.DestList.Valuate(AITown.GetPopulation);
						planned_route.DestList.KeepAboveValue(1500);
						break;
					default:
						planned_route.DestList.Valuate(AITown.GetLastMonthProduction, icrg);
						planned_route.DestList.KeepAboveValue(40); ///@todo change to const
						break;
				}
				planned_route.DestIsTown = true;
				planned_route.DestList.Valuate(AITown.GetDistanceManhattanToTile, planned_route.SourceLocation);
			}
			// Check the distance of the source and the destination
			planned_route.DestList.KeepBelowValue(200);
			planned_route.DestList.KeepAboveValue(40);
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
		AILog.Warning("-- Subsidy found");
	}
	else {
		AILog.Warning("-- Subsidy NOT found, try find a normal route");
		// Reset route info
		route.ResetRoute();
		// Find a normal route
		if (this.GetRoute(route)) {
			AILog.Warning("-- Route found");
		}
		else {
			AILog.Warning("-- NO ROUTE found");
		}
	}
}

