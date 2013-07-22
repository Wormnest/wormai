require("version.nut");

class WormAI extends AIInfo {
	function GetAuthor()      { return "Wormnest"; }
	function GetName()        { return "WormAI"; }
	function GetShortName()   { return "WOAI"; }
	function GetDescription() { return "Wormnest AI testing AI writing"; }
	function GetVersion()     { return SELF_VERSION; }
	function GetDate()        { return "2013-07-20"; }
	function CreateInstance() { return "WormAI"; }
	function GetAPIVersion()  { return "1.2"; } 

	function GetSettings() {
		//AddSetting({name = "use_trains", description = "Enable trains", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		//AddSetting({name = "use_rvs", description = "Enable road vehicles", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		AddSetting({name = "use_planes", description = "Enable aircraft", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		//AddSetting({name = "use_ships", description = "Enable ships", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});

		AddSetting({
			name = "ai_speed",
			description = "How fast this AI will think (TODO)",
			min_value = 1,
			max_value = 3,
			easy_value = 1,
			medium_value = 2,
			hard_value = 3,
			custom_value = 2,
			flags = CONFIG_INGAME
		});
		AddLabels("ai_speed", {
		  _1 = "Slow", 
		  _2 = "Normal",
		  _3 = "Fast"
		  });
		AddSetting({
			name = "min_town_size",
			description = "The minimum size of towns to be considered for getting an airport",
			min_value = 100,
			max_value = 5000,
			easy_value = 2500,
			medium_value = 1000,
			hard_value = 500,
			custom_value = 500,
			step_size = 100,
			flags = CONFIG_INGAME
		});
		AddSetting({
			name = "min_airport_distance",
			description = "The minimum distance between airports",
			min_value = 25,
			max_value = 250,
			easy_value = 25,
			medium_value = 50,
			hard_value = 100,
			custom_value = 50,
			step_size = 25,
			flags = CONFIG_INGAME
		});
		AddSetting({
			name = "max_airport_distance",
			description = "The maximum distance between airports",
			min_value = 500,
			max_value = 2000,
			easy_value = 500,
			medium_value = 750,
			hard_value = 1000,
			custom_value = 750,
			step_size = 100,
			flags = CONFIG_INGAME
		});
	}
}

RegisterAI(WormAI());
