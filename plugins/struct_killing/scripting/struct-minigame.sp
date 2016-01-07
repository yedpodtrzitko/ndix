#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <smlib>

#define PLGN_VRSN "1.0.2"

public Plugin:myinfo =
{
	name = "ND Structure Killing Mini-Game",
	author = "databomb",
	description = "Provides a mini-game and announcement for structure killing",
	version = PLGN_VRSN,
	url = "vintagejailbreak.org"
};

#define TEAM_EMPIRE		3
#define TEAM_CONSORT	2
#define TEAM_SPEC		1

/*
new String:IgnorePlayers[1][32] = {
	"STEAM_1:0:16635137" // Neko_Baron
}
*/

public OnPluginStart()
{
	HookEvent("structure_death", Event_StructDeath);
}

public Event_StructDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	new ent = GetEventInt(event, "entindex");
	//new team = GetEventInt(event, "team");
	new team = GetClientTeam(client);
	new type = GetEventInt(event, "type");
	
	decl String:buildingname[32];
	// get building name
	switch (type)
	{
		case 0:
		{
			Format(buildingname, sizeof(buildingname), "the Command Bunker");
		}
		case 1:
		{
			Format(buildingname, sizeof(buildingname), "a Machine Gun Turret");
		}
		case 2:
		{
			Format(buildingname, sizeof(buildingname), "a Transport Gate");
		}
		case 3:
		{
			Format(buildingname, sizeof(buildingname), "a Power Station");
		}
		case 4:
		{
			Format(buildingname, sizeof(buildingname), "a Wireless Repeater");
		}
		case 5:
		{
			Format(buildingname, sizeof(buildingname), "a Relay Tower");
		}
		case 6:
		{
			Format(buildingname, sizeof(buildingname), "a Supply Station");
		}
		case 7:
		{
			Format(buildingname, sizeof(buildingname), "an Assembler");
		}
		case 8:
		{
			Format(buildingname, sizeof(buildingname), "an Armory");
		}
		case 9:
		{
			Format(buildingname, sizeof(buildingname), "an Artillery");
		}
		case 10:
		{
			Format(buildingname, sizeof(buildingname), "a Radar Station");
		}
		case 11:
		{
			Format(buildingname, sizeof(buildingname), "a Flamethrower Turret");
		}
		case 12:
		{
			Format(buildingname, sizeof(buildingname), "a Sonic Turret");
		}
		case 13:
		{
			Format(buildingname, sizeof(buildingname), "a Rocket Turret");
		}
		case 14:
		{
			Format(buildingname, sizeof(buildingname), "a Wall");
		}
		case 15:
		{
			Format(buildingname, sizeof(buildingname), "a Barrier");
		}
		default:
		{
			Format(buildingname, sizeof(buildingname), "a %d (?)", type);
		}
	}
	

	decl String:sName[64];
	GetEntityClassname(ent, sName, sizeof(sName));
	
	ReplaceString(sName, sizeof(sName), "struct_", "", false);
	new String:playerId[32];
	new String:ignore[18] = "STEAM_1:0:16635137";
	LOOP_CLIENTS(c, CLIENTFILTER_INGAME | CLIENTFILTER_NOBOTS) {
		GetClientAuthId(c, AuthId_Steam2, playerId, sizeof(playerId));
		if (StrEqual(ignore, playerId, false)) {
			continue;
        }

		if (team == TEAM_CONSORT)
		{
			CPrintToChat(c, "{red}%N {lightgreen}destroyed %s for {red}the Consortium", client, buildingname);
		}
		else if (team == TEAM_EMPIRE)
		{
			CPrintToChat(c, "{blue}%N {lightgreen}destroyed %s for {blue}the Empire", client, buildingname);
		}
	}


}
