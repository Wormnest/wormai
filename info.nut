class WormAI extends AIInfo {
	function GetAuthor()      { return "Wormnest"; }
	function GetName()        { return "WormAI"; }
	function GetShortName()   { return "WOAI"; }
	function GetDescription() { return "Wormnest AI testing AI writing"; }
	function GetVersion()     { return SELF_VERSION; }
	function GetDate()        { return "2013-07-15"; }
	function CreateInstance() { return "WormAI"; }
	function GetAPIVersion()  { return "1.2"; } 

	function GetSettings() {
		AddSetting({
			name = "min_town_size",
			description = "The minimum size of towns to be considered for getting an airport",
			min_value = 100,
			max_value = 1000,
			easy_value = 500,
			medium_value = 400,
			hard_value = 300,
			custom_value = 500,
			step_size = 50,
			flags = 0
		});
	}
}

RegisterAI(WormAI());
