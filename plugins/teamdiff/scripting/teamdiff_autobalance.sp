#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define NAME "ND Teamdiff"
#define PLUGIN_VERSION "0.1.0"
#define DEBUG 0

#define TEAM_CON 2
#define TEAM_EMP 3
#define TEAMDIFF 165
#define TEAMSWITCH 30

public Plugin:myinfo =
{
	name = NAME,
	author = "yed_",
	description = "Shows teamdiff value.",
	version = PLUGIN_VERSION,
	url = "http://ndix.vanyli.net"
}


enum Bools
{
	PluginEnabled,
	BalancerEnabled,
};

enum Handles
{
	Handle:PluginEnabled,
	Handle:HudText,
	Handle:BalancerEnabled,
};

//global variables
new	bool:g_Bool[Bools],
	g_Handle[Handles] = {INVALID_HANDLE, ...},
	PlayerManager,
	StackWarning;

/*
StackWarning = 0 # show warning
StackWarning = 1 # run timer
StackWarning = 2 # timer in progress, dont do anything else
*/

public OnPluginStart()
{
	CreateConVar("ndix_teamdiff_version", PLUGIN_VERSION, NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_Handle[PluginEnabled] 	= 	CreateConVar("ndix_teamdiff_active", "1", "0 to disabled teamdiff");
	g_Handle[BalancerEnabled] 	= 	CreateConVar("ndix_ingame_balance", "1", "enable automatic balancing");

	RegConsoleCmd("sm_teamdiff", CMD_TeamDiff);
	RegConsoleCmd("sm_stacked", CMD_TeamDiff);

	g_Handle[HudText] = CreateHudSynchronizer();

	AutoExecConfig(true, "ndix_teamdiff");
}

public OnMapStart() {
	GetConVarData();

	PlayerManager = FindEntityByClassname(-1, "nd_player_manager");

	CreateTimer(0.1, UpdateTeamDiffLabel);
	CreateTimer(5.0, UpdateTeamDiffLabel, _, TIMER_REPEAT);
}


public Action:UpdateTeamDiffLabel(Handle:timer) {
	new TeamDiff = GetTeamDiff();
	decl String:buffer[512];
	new stackedTeamId;

	if (TeamDiff < 0)
	{
		stackedTeamId = TEAM_EMP;
		TeamDiff *= -1;
		Format(buffer, sizeof(buffer), "EMP stack: %d", TeamDiff);
	} else {
		stackedTeamId = TEAM_CON;
		Format(buffer, sizeof(buffer), "CN stack: %d", TeamDiff);
	}

	new rgb[3] = {200, ...};
	if (TeamDiff > 300) {
		rgb = {255, 0,  50};
	} else if (TeamDiff > 140) {
		rgb = {255, 150, 0};
	} else {
		rgb = {255,255,255};
	}

	SetHudTextParams(1.0, 0.0, 30.0, rgb[0], rgb[1], rgb[2], 150);

	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			 ShowSyncHudText(i, g_Handle[HudText], buffer);
			 //ShowHudText(i, -1, buffer);
		}
	}

	if (TeamDiff >= TEAMDIFF && g_Bool[BalancerEnabled]) {
		if (StackWarning == 1) {
			StackWarning = 2;
			CreateTimer(float(TEAMSWITCH+1), InGameBalance, stackedTeamId);
		} else if (StackWarning == 0) {
			StackWarning = 1;
			SetHudTextParams(-1.0, 0.0, 5.0, 255, 255, 255, 150);
			for (new i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i)) {
					ShowSyncHudText(i, g_Handle[HudText], "Autobalancing in %ds", TEAMSWITCH);
				}
			}
		}
	}

	return Plugin_Continue;
}


GetTeamDiff() {
	new TeamDiff,
		i = 1;

	for (; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			switch (GetClientTeam(i))
			{
				case TEAM_CON:
				TeamDiff += GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, i);
				case TEAM_EMP:
				TeamDiff -= GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, i);
			}
		}
	}
	return TeamDiff;
}

public Action:CMD_TeamDiff(client, args)
{
	StackWarning = 1;
	ReplyToCommand(client, "Teamdiff is in the top right corner");
	return Plugin_Handled;
}


public Action:InGameBalance(Handle:timer, any:stackedTeamId) {
	new CountDiff = 0;
	new TeamDiff = 0;
	// [team][score, level, client]
	new lowPlayer[4][3];
	// looking for high level, low score
	lowPlayer[stackedTeamId] = {0,2000,-1};
	// looking for low level, low level
	lowPlayer[5 - stackedTeamId] = {80,2000,-1};
	new rank, score;

	new comms[2];
	comms[0] = GameRules_GetPropEnt("m_hCommanders", 0);
	comms[1] = GameRules_GetPropEnt("m_hCommanders", 1);

	for (new client=0; client <= MaxClients; client++) {
		if (!client || !IsClientInGame(client) || IsFakeClient(client)) {
			continue;
		}

		rank = GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, client);
		switch (GetClientTeam(client)) {
			case TEAM_CON:
			TeamDiff += rank;
			case TEAM_EMP:
			TeamDiff -= rank;
		}

		if (client == comms[0] || client == comms[1]) {
			continue;
		}

		// stacked team; looking for high level, low score
		if (GetClientTeam(client) == stackedTeamId)
		{
			score = GetEntProp(PlayerManager, Prop_Send, "m_iScore", _, client);
			if (rank >= lowPlayer[stackedTeamId][0] && score < lowPlayer[stackedTeamId][1])
			{
				lowPlayer[stackedTeamId][0] = rank;
				lowPlayer[stackedTeamId][1] = score;
				lowPlayer[stackedTeamId][2] = client;
			}

			CountDiff += 1;
		}
		// opposite team; looking for low level, low score
		else if (GetClientTeam(client) == (5 - stackedTeamId))
		{
			rank = GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, client);
			score = GetEntProp(PlayerManager, Prop_Send, "m_iScore", _, client);

			if (rank <= lowPlayer[5 - stackedTeamId][0] && score < lowPlayer[5 - stackedTeamId][1])
			{
				lowPlayer[5 - stackedTeamId][0] = rank;
				lowPlayer[5 - stackedTeamId][1] = score;
				lowPlayer[5 - stackedTeamId][2] = client;
			}

			CountDiff -= 1;
		}
	}

	if (CountDiff < 2 && CountDiff > -2) {
		if (TeamDiff < TEAMDIFF && TeamDiff > (TEAMDIFF * -1)) {
			StackWarning = 0;
			return Plugin_Handled;
		}
	}

	// non-stacked team has more players
	new swapped;
	if (CountDiff < 0) {
		swapped = lowPlayer[5 - stackedTeamId][2];
		if (swapped != -1) {
			PrintToChat(swapped, "\x04[NDix] You've been chosen to switch because you've a low score");
			ChangeClientTeam(swapped, stackedTeamId);
			DispatchSpawn(swapped);
		}
	}

	swapped = lowPlayer[stackedTeamId][2];
	if (swapped != -1) {
		PrintToChat(swapped, "\x04[NDix] You've been chosen to switch because you've a low score");
		ChangeClientTeam(swapped, (5 - stackedTeamId));
		DispatchSpawn(swapped);
	}
	StackWarning = 0;
	return Plugin_Handled;
}

//run from OnMapStart
GetConVarData()
{
	g_Bool[PluginEnabled] = GetConVarBool(g_Handle[PluginEnabled]);
	g_Bool[BalancerEnabled] = GetConVarBool(g_Handle[BalancerEnabled]);
	g_Bool[StackWarning] = true;
}
