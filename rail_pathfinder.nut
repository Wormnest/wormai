/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file rail_pathfinder.nut The rail pathfinder for WormAI.
 * Copy of the rail pathfinder library with changes from several other AI's.
 * Requirement: aystar library.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Changes made by Wormnest (Jacob Boerema) are Copyright Jacob Boerema, 2016.
 *
 */ 

/**
 * A Rail Pathfinder.
 */
class Rail
{
	_aystar_class = import("graph.aystar", "", 4);
	_max_cost = null;              ///< The maximum cost for a route.
	_cost_tile = null;             ///< The cost for a single tile.
	_cost_diagonal_tile = null;    ///< The cost for a diagonal tile.
	_cost_turn = null;             ///< The cost that is added to _cost_tile if the direction changes.
	_cost_slope = null;            ///< The extra cost if a rail tile is sloped.
	_cost_bridge_per_tile = null;  ///< The cost per tile of a new bridge, this is added to _cost_tile.
	_cost_tunnel_per_tile = null;  ///< The cost per tile of a new tunnel, this is added to _cost_tile.
	_cost_coast = null;            ///< The extra cost for a coast tile.
	_pathfinder = null;            ///< A reference to the used AyStar object.
	_max_bridge_length = null;     ///< The maximum length of a bridge that will be built.
	_max_tunnel_length = null;     ///< The maximum length of a tunnel that will be built.
	// From AdmiralAI
//	_cost_no_existing_rail = null; ///< The cost that is added to _cost_tile if new rail has to be built.
	_cost_90_turn = null;          ///< The cost that is added to _cost_tile (and _cost_turn) for 90* turns.
	_cost_level_crossing = null;	///< The cost added if we are crossing a road
	_reverse_signals = null;        ///< Don't pass through signals the right way, only trough the back of signals
	_goal_estimate_tile = null;

	cost = null;                   ///< Used to change the costs.
	_running = null;
	_goals = null;

	constructor()
	{
		this._max_cost = 10000000;
		this._cost_tile = 100;
		this._cost_diagonal_tile = 70;
		this._cost_turn = 50;
		this._cost_slope = 100;
		this._cost_bridge_per_tile = 150;
		this._cost_tunnel_per_tile = 120;
		this._cost_coast = 20;
		this._max_bridge_length = 10;
		this._max_tunnel_length = 15;
		// From AdmiralAI
//		this._cost_no_existing_rail = 10;
		this._cost_90_turn = 140;
		this._cost_level_crossing = 500;
		this._reverse_signals = false;

		this._pathfinder = this._aystar_class(this._Cost, this._Estimate, this._Neighbours, this._CheckDirection, this, this, this, this);

		this.cost = this.Cost(this);
		this._running = false;
	}

	/**
	 * Initialize a path search between sources and goals.
	 * @param sources The source tiles.
	 * @param goals The target tiles.
	 * @param ignored_tiles An array of tiles that cannot occur in the final path.
	 * @see AyStar::InitializePath()
	 */
	function InitializePath(sources, goals, ignored_tiles = []) {
		local nsources = [];

		foreach (node in sources) {
			local path = this._pathfinder.Path(null, node[1], 0xFF, this._Cost, this);
			path = this._pathfinder.Path(path, node[0], 0xFF, this._Cost, this);
			nsources.push(path);
		}
		this._goals = goals;
		this._goal_estimate_tile = goals[0][0];
		foreach (tile in goals) {
			if (AIMap.DistanceManhattan(sources[0][0], tile[0]) < AIMap.DistanceManhattan(sources[0][0], this._goal_estimate_tile)) {
				this._goal_estimate_tile = tile[0];
			}
		}
		this._pathfinder.InitializePath(nsources, goals, ignored_tiles);
	}

	/**
	 * Try to find the path as indicated with InitializePath with the lowest cost.
	 * @param iterations After how many iterations it should abort for a moment.
	 *  This value should either be -1 for infinite, or > 0. Any other value
	 *  aborts immediatly and will never find a path.
	 * @return A route if one was found, or false if the amount of iterations was
	 *  reached, or null if no path was found.
	 *  You can call this function over and over as long as it returns false,
	 *  which is an indication it is not yet done looking for a route.
	 * @see AyStar::FindPath()
	 */
	function FindPath(iterations);
};

class Rail.Cost
{
	_main = null;

	function _set(idx, val)
	{
		if (this._main._running) throw("You are not allowed to change parameters of a running pathfinder.");

		switch (idx) {
			case "max_cost":          this._main._max_cost = val; break;
			case "tile":              this._main._cost_tile = val; break;
			case "diagonal_tile":     this._main._cost_diagonal_tile = val; break;
			case "turn":              this._main._cost_turn = val; break;
			case "slope":             this._main._cost_slope = val; break;
			case "bridge_per_tile":   this._main._cost_bridge_per_tile = val; break;
			case "tunnel_per_tile":   this._main._cost_tunnel_per_tile = val; break;
			case "coast":             this._main._cost_coast = val; break;
			case "max_bridge_length": this._main._max_bridge_length = val; break;
			case "max_tunnel_length": this._main._max_tunnel_length = val; break;
			// From AdmiralAI
//			case "no_existing_rail":  this._main._cost_no_existing_rail = val; break;
			case "level_crossing":    this._main._cost_level_crossing = val; break;
			case "90_turn":           this._main._cost_90_turn = val; break;
			case "reverse_signals":   this._main._reverse_signals = val; break;
			default: throw("the index '" + idx + "' does not exist");
		}

		return val;
	}

	function _get(idx)
	{
		switch (idx) {
			case "max_cost":          return this._main._max_cost;
			case "tile":              return this._main._cost_tile;
			case "diagonal_tile":     return this._main._cost_diagonal_tile;
			case "turn":              return this._main._cost_turn;
			case "slope":             return this._main._cost_slope;
			case "bridge_per_tile":   return this._main._cost_bridge_per_tile;
			case "tunnel_per_tile":   return this._main._cost_tunnel_per_tile;
			case "coast":             return this._main._cost_coast;
			case "max_bridge_length": return this._main._max_bridge_length;
			case "max_tunnel_length": return this._main._max_tunnel_length;
			// From AdmiralAI (which called it new_rail)
//			case "no_existing_rail":  return this._main._cost_no_existing_rail;
			case "level_crossing":    return this._main._cost_level_crossing;
			case "90_turn":           return this._main._cost_90_turn;
			case "reverse_signals":   return this._main._reverse_signals;
			default: throw("the index '" + idx + "' does not exist");
		}
	}

	constructor(main)
	{
		this._main = main;
	}
};

function Rail::FindPath(iterations)
{
	local test_mode = AITestMode();
	local ret = this._pathfinder.FindPath(iterations);
	this._running = (ret == false) ? true : false;
	if (!this._running && ret != null) {
		foreach (goal in this._goals) {
			if (goal[0] == ret.GetTile()) {
				return this._pathfinder.Path(ret, goal[1], 0, this._Cost, this);
			}
		}
	}
	return ret;
}

function Rail::_GetBridgeNumSlopes(end_a, end_b)
{
	local slopes = 0;
	local direction = (end_b - end_a) / AIMap.DistanceManhattan(end_a, end_b);
	local slope = AITile.GetSlope(end_a);
	if (!((slope == AITile.SLOPE_NE && direction == 1) || (slope == AITile.SLOPE_SE && direction == -AIMap.GetMapSizeX()) ||
		(slope == AITile.SLOPE_SW && direction == -1) || (slope == AITile.SLOPE_NW && direction == AIMap.GetMapSizeX()) ||
		 slope == AITile.SLOPE_N || slope == AITile.SLOPE_E || slope == AITile.SLOPE_S || slope == AITile.SLOPE_W)) {
		slopes++;
	}

	local slope = AITile.GetSlope(end_b);
	direction = -direction;
	if (!((slope == AITile.SLOPE_NE && direction == 1) || (slope == AITile.SLOPE_SE && direction == -AIMap.GetMapSizeX()) ||
		(slope == AITile.SLOPE_SW && direction == -1) || (slope == AITile.SLOPE_NW && direction == AIMap.GetMapSizeX()) ||
		 slope == AITile.SLOPE_N || slope == AITile.SLOPE_E || slope == AITile.SLOPE_S || slope == AITile.SLOPE_W)) {
		slopes++;
	}
	return slopes;
}

function Rail::_nonzero(a, b)
{
	return a != 0 ? a : b;
}

function Rail::_Cost(path, new_tile, new_direction, self)
{
	// First line added from AdmiralAI
	if (AITile.GetMaxHeight(new_tile) == 0) return self._max_cost;

	/* path == null means this is the first node of a path, so the cost is 0. */
	if (path == null) return 0;

	local prev_tile = path.GetTile();
	// Add local variables for often used calls, should improve speed a little.
	local path_parent = path.GetParent();
	local parent_tile = null;
	local path_grandparent = null;
	if (path_parent != null) {
		parent_tile = path_parent.GetTile();
		path_grandparent = path_parent.GetParent();
	}

	/* If the new tile is a bridge / tunnel tile, check whether we came from the other
	 *  end of the bridge / tunnel or if we just entered the bridge / tunnel. */
	if (AIBridge.IsBridgeTile(new_tile)) {
		if (AIBridge.GetOtherBridgeEnd(new_tile) != prev_tile) {
			local cost = path.GetCost() + self._cost_tile;
			if (path_parent != null && parent_tile - prev_tile != prev_tile - new_tile) cost += self._cost_turn;
			return cost;
		}
		return path.GetCost() + AIMap.DistanceManhattan(new_tile, prev_tile) * self._cost_tile +
			self._GetBridgeNumSlopes(new_tile, prev_tile) * self._cost_slope;
	}
	if (AITunnel.IsTunnelTile(new_tile)) {
		if (AITunnel.GetOtherTunnelEnd(new_tile) != prev_tile) {
			local cost = path.GetCost() + self._cost_tile;
			if (path_parent != null && parent_tile - prev_tile != prev_tile - new_tile) cost += self._cost_turn;
			return cost;
		}
		return path.GetCost() + AIMap.DistanceManhattan(new_tile, prev_tile) * self._cost_tile;
	}

	/* If the two tiles are more then 1 tile apart, the pathfinder wants a bridge or tunnel
	 *  to be built. It isn't an existing bridge / tunnel, as that case is already handled. */
	local distance_new_prev = AIMap.DistanceManhattan(new_tile, prev_tile);
	if (distance_new_prev > 1) {
		/* Check if we should build a bridge or a tunnel. */
		local cost = path.GetCost();
		if (AITunnel.GetOtherTunnelEnd(new_tile) == prev_tile) {
			cost += distance_new_prev * (self._cost_tile + self._cost_tunnel_per_tile);
		} else {
			cost += distance_new_prev * (self._cost_tile + self._cost_bridge_per_tile) +
				self._GetBridgeNumSlopes(new_tile, prev_tile) * self._cost_slope;
		}
		if (path_parent != null && path_grandparent != null &&
			path_grandparent.GetTile() - parent_tile !=
			max(AIMap.GetTileX(prev_tile) - AIMap.GetTileX(new_tile), AIMap.GetTileY(prev_tile) - AIMap.GetTileY(new_tile))
			/ distance_new_prev) {
			cost += self._cost_turn;
		}
		return cost;
	}

	/* Check for a turn. We do this by substracting the TileID of the current
	 *  node from the TileID of the previous node and comparing that to the
	 *  difference between the tile before the previous node and the node before
	 *  that. */
	local cost = self._cost_tile;
	local diagonal = path_parent != null && AIMap.DistanceManhattan(parent_tile, prev_tile) == 1 &&
		parent_tile - prev_tile != prev_tile - new_tile;
	if (diagonal)
		cost = self._cost_diagonal_tile;
	// if we don't have enough parents to determine a turn, assume diagonal is bad
	// because we want to exit straight from stations and crossings
	local long = path_parent != null && path_grandparent != null;
	if ((long && self._IsTurn(path_grandparent.GetTile(), parent_tile, prev_tile, new_tile)) ||
		(!long && diagonal)) {
		cost += self._cost_turn;
	}

	/* Check for a double turn (AIAI) = 90 degree turn? */
	if (long) {
		local path_greatgrandparent = path_grandparent.GetParent();
		if ((path_greatgrandparent != null) &&
			self._IsTurn(path_greatgrandparent.GetTile(), path_grandparent.GetTile(), parent_tile, prev_tile)) {
			cost += self._cost_90_turn;
		}
	}
	
	/* Check if the new tile is a coast tile. */
	if (AITile.IsCoastTile(new_tile)) {
		cost += self._cost_coast;
	}

	/* Check if the last tile was sloped. */
	if (path_parent != null && !AIBridge.IsBridgeTile(prev_tile) && !AITunnel.IsTunnelTile(prev_tile)) {
		cost += self._GetSlopeCost(path_parent, prev_tile, new_tile);
	}

	/* Check if the next tile is a road tile. */
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_ROAD)) {
		cost += self._cost_level_crossing;
	}

	/* We don't use already existing rail, so the following code is unused. It
	 * assigns if no rail exists along the route.
	 * If we decide to want to reuse rail we will have to uncomment this.
	 */
	/*
	if (path.GetParent() != null && !AIRail.AreTilesConnected(path.GetParent().GetTile(), prev_tile, new_tile)) {
		cost += self._cost_no_existing_rail;
	}
	*/

	return path.GetCost() + cost;
}

function Rail::_Estimate(cur_tile, cur_direction, goal_tiles, self)
{
	local min_cost = self._max_cost;
	/* As estimate we multiply the lowest possible cost for a single tile with
	 *  with the minimum number of tiles we need to traverse. */
	foreach (tile in goal_tiles) {
		local dx = abs(AIMap.GetTileX(cur_tile) - AIMap.GetTileX(tile[0]));
		local dy = abs(AIMap.GetTileY(cur_tile) - AIMap.GetTileY(tile[0]));
		min_cost = min(min_cost, min(dx, dy) * (self._cost_diagonal_tile /*+self._cost_no_existing_rail*/)
			* 2 + (max(dx, dy) - min(dx, dy)) * (self._cost_tile /*+self._cost_no_existing_rail*/));
	}
	return min_cost;
}

function Rail::_Neighbours(path, cur_node, self)
{
	/// @todo If we ever want to reuse some of ourown tracks then we need to comment the next line and
	/// replace part of this function with the implementation from AdmiralAI!
	if (AITile.HasTransportType(cur_node, AITile.TRANSPORT_RAIL)) return [];
	/* self._max_cost is the maximum path cost, if we go over it, the path isn't valid. */
	if (path.GetCost() >= self._max_cost) return [];
	local tiles = [];
	local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	// Add local variables for often used calls, should improve speed a little.
	local path_parent = path.GetParent();
	local parent_tile = null;
	if (path_parent != null) {
		parent_tile = path_parent.GetTile();
	}

	/* Check if the current tile is part of a bridge or tunnel. */
	if (AIBridge.IsBridgeTile(cur_node) || AITunnel.IsTunnelTile(cur_node)) {
		/* We don't use existing rails, so neither existing bridges / tunnels. */
	} else if (path_parent != null && AIMap.DistanceManhattan(cur_node, parent_tile) > 1) {
		local other_end = parent_tile;
		local next_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
		foreach (offset in offsets) {
			if (AIRail.BuildRail(cur_node, next_tile, next_tile + offset)) {
				tiles.push([next_tile, self._GetDirection(other_end, cur_node, next_tile, true)]);
			}
		}
	} else {
		/* Check all tiles adjacent to the current tile. */
		// Move computation of non changing values out of the loop
		local path_grandparent = null;
		local grandparent_tile = null;
		if (path_parent != null) {
			path_grandparent = path_parent.GetParent();
			if (path_grandparent != null)
				grandparent_tile = path_grandparent.GetTile();
		}
		foreach (offset in offsets) {
			local next_tile = cur_node + offset;
			/* Don't turn back */
			if (path_parent != null && next_tile == parent_tile) continue;
			/* Disallow 90 degree turns */
			if (path_grandparent != null &&
				next_tile - cur_node == grandparent_tile - parent_tile) continue;
			/* We add them to the to the neighbours-list if we can build a rail to
			 *  them and no rail exists there. */
			if ((path_parent == null || AIRail.BuildRail(parent_tile, cur_node, next_tile))) {
				if (path_parent != null) {
					tiles.push([next_tile, self._GetDirection(parent_tile, cur_node, next_tile, false)]);
				} else {
					tiles.push([next_tile, self._GetDirection(null, cur_node, next_tile, false)]);
				}
			}
		}
		if (path_grandparent != null) {
			local bridges = self._GetTunnelsBridges(parent_tile, cur_node,
				self._GetDirection(grandparent_tile, parent_tile, cur_node, true));
			foreach (tile in bridges) {
				tiles.push(tile);
			}
		}
	}
	return tiles;
}

function Rail::_CheckDirection(tile, existing_direction, new_direction, self)
{
	return false;
}

function Rail::_dir(from, to)
{
	if (from - to == 1) return 0;
	if (from - to == -1) return 1;
	if (from - to == AIMap.GetMapSizeX()) return 2;
	if (from - to == -AIMap.GetMapSizeX()) return 3;
	throw("Shouldn't come here in _dir");
}

function Rail::_GetDirection(pre_from, from, to, is_bridge)
{
	if (is_bridge) {
		if (from - to == 1) return 1;
		if (from - to == -1) return 2;
		if (from - to == AIMap.GetMapSizeX()) return 4;
		if (from - to == -AIMap.GetMapSizeX()) return 8;
	}
	return 1 << (4 + (pre_from == null ? 0 : 4 * this._dir(pre_from, from)) + this._dir(from, to));
}

/**
 * Get a list of all bridges and tunnels that can be built from the current tile.
 * Bridges will only be built starting on non-flat tiles for performance reasons.
 * Tunnels will only be built if no terraforming is needed on both ends.
 */
function Rail::_GetTunnelsBridges(last_node, cur_node, bridge_dir)
{
	local slope = AITile.GetSlope(cur_node);
	if (slope == AITile.SLOPE_FLAT && AITile.IsBuildable(cur_node + (cur_node - last_node))) return [];
	local tiles = [];

	for (local i = 2; i < this._max_bridge_length; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = cur_node + i * (cur_node - last_node);
		if (!bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_list.Begin(), cur_node, target)) {
			tiles.push([target, bridge_dir]);
		}
	}

	if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE) return tiles;
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(cur_node);
	if (!AIMap.IsValidTile(other_tunnel_end)) return tiles;

	local tunnel_length = AIMap.DistanceManhattan(cur_node, other_tunnel_end);
	local prev_tile = cur_node + (cur_node - other_tunnel_end) / tunnel_length;
	if (AITunnel.GetOtherTunnelEnd(other_tunnel_end) == cur_node && tunnel_length >= 2 &&
			prev_tile == last_node && tunnel_length < _max_tunnel_length && AITunnel.BuildTunnel(AIVehicle.VT_RAIL, cur_node)) {
		tiles.push([other_tunnel_end, bridge_dir]);
	}
	return tiles;
}

function Rail::_IsTurn(pre, start, middle, end)
{
	//AIMap.DistanceManhattan(new_tile, path.GetParent().GetParent().GetTile()) == 3 &&
	//path.GetParent().GetParent().GetTile() - path.GetParent().GetTile() != prev_tile - new_tile) {
	return AIMap.DistanceManhattan(end, pre) == 3 && pre - start != middle - end;
}

function Rail::_NumSlopes(path, prev, cur)
{
	if (this._IsSlopedRail(path.GetTile(), prev, cur)) {
		if (path.GetParent() != null) return 1 + this._NumSlopes(path.GetParent(), path.GetTile(), prev);
		return 1;
	}
	return 0;
}

function Rail::_GetSlopeCost(path, prev, cur)
{
	return this._NumSlopes(path, prev, cur) * this._cost_slope;
}

function Rail::_IsSlopedRail(start, middle, end)
{
	local NW = 0; // Set to true if we want to build a rail to / from the north-west
	local NE = 0; // Set to true if we want to build a rail to / from the north-east
	local SW = 0; // Set to true if we want to build a rail to / from the south-west
	local SE = 0; // Set to true if we want to build a rail to / from the south-east

	if (middle - AIMap.GetMapSizeX() == start || middle - AIMap.GetMapSizeX() == end) NW = 1;
	if (middle - 1 == start || middle - 1 == end) NE = 1;
	if (middle + AIMap.GetMapSizeX() == start || middle + AIMap.GetMapSizeX() == end) SE = 1;
	if (middle + 1 == start || middle + 1 == end) SW = 1;

	/* If there is a turn in the current tile, it can't be sloped. */
	if ((NW || SE) && (NE || SW)) return false;

	local slope = AITile.GetSlope(middle);
	/* A rail on a steep slope is always sloped. */
	if (AITile.IsSteepSlope(slope)) return true;

	/* If only one corner is raised, the rail is sloped. */
	if (slope == AITile.SLOPE_N || slope == AITile.SLOPE_W) return true;
	if (slope == AITile.SLOPE_S || slope == AITile.SLOPE_E) return true;

	if (NW && (slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SE)) return true;
	if (NE && (slope == AITile.SLOPE_NE || slope == AITile.SLOPE_SW)) return true;

	return false;
}
