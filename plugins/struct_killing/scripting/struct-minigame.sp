#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <smlib>
#include <ndix>
#include <clientprefs>

#define PLGN_VRSN "1.0.3"

bool cookiesEnabled = false;
Handle cookie;
bool enabledForClient[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "ND Structure Killing Mini-Game",
	author = "databomb",
	description = "Provides a mini-game and announcement for structure killing",
	version = PLGN_VRSN,
	url = "vintagejailbreak.org"
};

public OnClientCookiesCached(client)
{
	if (IsClientInGame(client)) {
		ClientIngameAndCookiesCached(client);
	}
}

public OnClientPutInServer(client)
{
	if (cookiesEnabled && AreClientCookiesCached(client)) {
		ClientIngameAndCookiesCached(client);
	}
}

public OnClientConnected(client)
{
	enabledForClient[client] = true;
}

public void OnPluginStart()
{
	HookEvent("structure_death", Event_StructDeath);

	cookiesEnabled = (GetExtensionFileStatus("clientprefs.ext") == 1);
	if (cookiesEnabled) {
		SetCookieMenuItem(PrefMenu, 0, "Show Buildings Kills");
		cookie = RegClientCookie("Show Buildings Kills", "", CookieAccess_Private);
	}
}

public PrefMenu(client, CookieMenuAction action, any info, char[] buffer, maxlen)
{
	if (action == CookieMenuAction_SelectOption) {
		DisplaySettingsMenu(client);
	}
}

public void Event_StructDeath(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "attacker"));
	int ent = GetEventInt(event, "entindex");
	int team = GetClientTeam(client);
	int type = GetEventInt(event, "type");

	char buildingname[32];
	// get building name
	switch (type)
	{
		case 0:
		{
			Format(buildingname, sizeof(buildingname), "the Command Bunker");
		}
		case 1:
		{
			Format(buildingname, sizeof(buildingname), "a Machinegun Turret");
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

	char sName[64];
	GetEntityClassname(ent, sName, sizeof(sName));

	ReplaceString(sName, sizeof(sName), "struct_", "", false);
	char playerId[32];
	LOOP_CLIENTS(c, CLIENTFILTER_INGAME | CLIENTFILTER_NOBOTS) {
		GetClientAuthId(c, AuthId_Steam2, playerId, sizeof(playerId));
		if (!enabledForClient[c]) {
			continue;
		}

		if (team == ND_TEAM_CN)
		{
			CPrintToChat(c, "{red}%N {lightgreen}destroyed %s for {red}the Consortium", client, buildingname);
		}
		else if (team == ND_TEAM_EMP)
		{
			CPrintToChat(c, "{blue}%N {lightgreen}destroyed %s for {blue}the Empire", client, buildingname);
		}
	}
}


void DisplaySettingsMenu(client)
{
	char MenuItem[128];
	Menu prefmenu = CreateMenu(PrefMenuHandler);

	Format(MenuItem, sizeof(MenuItem), "name");
	SetMenuTitle(prefmenu, MenuItem);

	new String:checked[] = String:0x9A88E2;

	Format(MenuItem, sizeof(MenuItem), "enabled [%s]", enabledForClient[client] ? checked : "   ");
	AddMenuItem(prefmenu, "1", MenuItem);

	Format(MenuItem, sizeof(MenuItem), "disabled [%s]", enabledForClient[client] ? "   " : checked);
	AddMenuItem(prefmenu, "0", MenuItem);

	DisplayMenu(prefmenu, client, MENU_TIME_FOREVER);
}

public PrefMenuHandler(Handle prefmenu, MenuAction action, client, item)
{
	if (action == MenuAction_Select) {
		char preference[8];

		GetMenuItem(prefmenu, item, preference, sizeof(preference));

		enabledForClient[client] = bool:StringToInt(preference);

		if (enabledForClient[client]) {
			SetClientCookie(client, cookie, "on");
		} else {
			SetClientCookie(client, cookie, "off");
		}

		DisplaySettingsMenu(client);
	} else if (action == MenuAction_End) {
		CloseHandle(prefmenu);
	}
}

void ClientIngameAndCookiesCached(client)
{
	char preference[8];
	GetClientCookie(client, cookie, preference, sizeof(preference));

	if (StrEqual(preference, "")) {
		enabledForClient[client] = true;
	}
	else {
		enabledForClient[client] = !StrEqual(preference, "off", false);
	}

	//CreateTimer(announceTime, Timer_Announce, GetClientSerial(client));
}