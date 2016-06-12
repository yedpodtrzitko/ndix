#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <ndix>

#define NAME "Team Balancer"
#define PLUGIN_VERSION "0.1.1"
#define DEBUG 0

#define TEAM_CON 2
#define TEAM_EMP 3


public Plugin:myinfo =
{
	name = NAME,
	author = "yed_",
	description = "Team balancer",
	version = PLUGIN_VERSION,
    url = "https://github.com/yedpodtrzitko/ndix"
}


enum Bools
{
	PluginActive
};

enum Handles
{
	Handle:PluginActive,
};


new bool:g_Bool[Bools],
	g_Handle[Handles] = {INVALID_HANDLE},
	PlayerManager;

public OnPluginStart()
{
	CreateConVar("ndix_balancer_version", PLUGIN_VERSION, NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_Handle[PluginActive] = CreateConVar("sm_nd_balancer_enable", "1", "0 to disable the balancer. (and only run the warmup round)");

	HookEvent("player_team", Event_ChangeTeam, EventHookMode_Pre);

	AutoExecConfig(true, "ndix_balancer");
}

public OnMapStart()
{
	GetConVarData();

	if (!g_Bool[PluginActive]) {
		return;
	}

	PlayerManager = FindEntityByClassname(-1, "nd_player_manager");
}


//can't cancel spawning to avoid being balanced
public Action:CMD_CancelSpawn(client, const String:command[], args)
{
	if (g_Bool[PluginActive]) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:Event_ChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_Bool[PluginActive]) {
		return Plugin_Continue;
	}

 	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client)) {
		return Plugin_Handled;
	}

	new team = GetEventInt(event, "team");
	if (team < 2) {
		return Plugin_Continue;
	}

	new weakTeam = GetWeakerTeam(client);
	if (weakTeam != 0) {
		PrintToChat(client, "\x04%s Assigning to the weaker team.", SERVER_NAME_TAG);
		ClientCommand(client, "jointeam %i", weakTeam);
		//ChangeClientTeam(client, weakTeam);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


GetWeakerTeam(newPlayer) {
	int TeamDiff;
	int CountDiff;
	LOOP_CLIENTS(client, CLIENTFILTER_INGAME | CLIENTFILTER_NOBOTS) {
		if (client != newPlayer) {
			if (GetClientTeam(client) == TEAM_CON)
			{
				TeamDiff += GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, client);
				CountDiff += 1;
			}
			else if (GetClientTeam(client) == TEAM_EMP)
			{
				TeamDiff -= GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, client);
				CountDiff -= 1;
			}
		}
	}

	// Empire is lvl- and count- stacked
	if (TeamDiff < -20 && CountDiff < 0) {
		return TEAM_CON;
	}
	// actually it's Consortium.
	if (TeamDiff > 20 && CountDiff > 0) {
		return TEAM_EMP;
	}

	if (CountDiff > 0) {
		return TEAM_EMP;
	} else if (CountDiff < 0) {
		return TEAM_CON;
	}

	return 0;
}

//run from OnMapStart
GetConVarData()
{
	g_Bool[PluginActive] = GetConVarBool(g_Handle[PluginActive]);
}
