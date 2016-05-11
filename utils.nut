/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file utils.nut Class with utility functions for WormAI.
 * Requirement: AILib.List library which is expected to be loaded as "ExtendedList".
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2016.
 *
 */ 

/**
 * Define the WormUtils class which holds the utility functions.
 */
class WormUtils
{
	/**
	 * Convert an AIList to an array then store that in a table. If the AIList is null nothing is stored.
	 * @param table The table to store the AIList in.
	 * @param table_entry The string representation of the row in the table where the AIList should be saved to.
	 * @param list The AIList to be stored.
	 * @return Boolean: true when the AIList was stored in the table, otherwise false.
	 * @pre table should be a valid table, table_entry should be a valid non empty string.
	 */
	static function ListToTableEntry(table, table_entry, list);

	/**
	 * Convert a table entry containing an array to an AIList.
	 * @param table The table to load the AIList from.
	 * @param table_entry The string representation of the row in the table where the AIList was stored.
	 * @param list The AIList where the data from the table entry should be saved to.
	 * @return Boolean: true when table_entry was found in table, otherwise false.
	 * @pre table should be a valid table, table_entry should be a valid non empty string, list should be a valid AIList.
	 */
	static function TableEntryToList(table, table_entry, list);

}

function WormUtils::ListToTableEntry(table, table_entry, list)
{
	/* List's can be null when data is saved before we have initialized everything. */
	if (list == null)
		return false;
	local t = ExtendedList();
	t.AddList(list);
	table.rawset(table_entry, t.toarray());
	return true;
}

function WormUtils::TableEntryToList(table, table_entry, list)
{
	if (table.rawin(table_entry)) {
		local t = ExtendedList();
		t.AddFromArray(table.rawget(table_entry));
		list.AddList(t);
		return true;
	}
	return false;
}
