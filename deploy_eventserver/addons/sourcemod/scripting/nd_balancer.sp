#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define NAME "ND Warmup Round and Team Balancer"
#define PLUGIN_VERSION "1.2.6"
#define DEBUG 0

#define TEAM_CON 2
#define TEAM_EMP 3


public Plugin:myinfo =
{
	name = NAME,
	author = "Xander",
	description = "Includes an a warmup round and level balancer.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=186001"
}

enum Integers
{
	CountDown,
	ModGravity
};

enum Bools
{
	BalancerActive,
	InGameBalance,
	TeamDiffAllowed,
	ModFF,
	OrigFF
};

enum Handles
{
	Handle:EnableBalancer,
	Handle:InGameBalance,
	Handle:WarmupTime,
	Handle:WarmupEndMessage,
	Handle:WarmupTextColor,
	Handle:ModFF,
	Handle:ModGravity,
	Handle:FF,
	Handle:Gravity,
	Handle:HudText
};

//global variables
new g_Integer[Integers],
	bool:g_Bool[Bools],
	g_Handle[Handles] = {INVALID_HANDLE, ...},
	g_iTextColor[3],
	PlayerManager;

public OnPluginStart()
{
	CreateConVar("sm_nd_warmup_balancer_version", PLUGIN_VERSION, NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_Handle[EnableBalancer] 	= 	CreateConVar("sm_nd_balancer_enable", "1", "0 to disable the balancer. (and only run the warmup round)");
	g_Handle[InGameBalance] 	= 	CreateConVar("sm_nd_balancer_ingame", "1", "0 to disable the ingame balancer.");

	g_Handle[WarmupTime] 		=	CreateConVar("sm_warmup_time", "65.0", "Sets the warmup time.", FCVAR_NONE, true, 5.0, false);
	g_Handle[WarmupEndMessage] 	= 	CreateConVar("sm_warmup_end_message", "Engage Post-Nuclear Combat!", "Sets the warmup end message. [Max Length == 100 characters]");
	g_Handle[WarmupTextColor] 	= 	CreateConVar("sm_warmup_text_color", "0 255 0", "Set the warmup text RGB values seperated by spaces.");

	g_Handle[ModFF] 			= 	CreateConVar("sm_warmup_modify_ff", "0", "(0 / 1) - Enabling this Cvar will turn FF on durning the warmup round, then back off when it ends.");
	g_Handle[ModGravity] 		= 	CreateConVar("sm_warmup_modify_gravity", "0", "0 = Don't change gravity; any > 0 will set gravity to that value, then return to default after the warmup round.", FCVAR_NONE, true, 0.0, false);

	g_Handle[FF]				=	FindConVar("mp_friendlyfire");
	g_Handle[Gravity]			=	FindConVar("sv_gravity");


	RegAdminCmd("sm_balanceteams", CMD_BalanceTeams, ADMFLAG_KICK, "Runs the team balancer immediately");

	RegConsoleCmd("sm_teamdiff", CMD_TeamDiff);
	RegConsoleCmd("sm_stacked", CMD_TeamDiff);
	AddCommandListener(CMD_CancelSpawn, "postpone_spawn");

	HookEvent("player_team", Event_ChangeTeam, EventHookMode_Pre);

	SetConVarBounds(FindConVar("mp_minplayers"), ConVarBound_Upper, true, 100.0);

	g_Handle[HudText] = CreateHudSynchronizer();

	AutoExecConfig(true, "nd_balancer");
}

public OnMapStart()
{
	PlayerManager = FindEntityByClassname(-1, "nd_player_manager");

	GetConVarData();

	ServerCommand("mp_minplayers 100");

	CreateTimer(1.0, WarmupRoundTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	g_Bool[TeamDiffAllowed] = true;

	SetClientSpawnPoint(0);	//find the Tgates' origins

	if (g_Bool[ModFF])
		SetConVarBool(g_Handle[FF], true);

	if (g_Integer[ModGravity] > 0)
		SetConVarInt(g_Handle[Gravity], g_Integer[ModGravity]);
}

public Action:WarmupRoundTimer(Handle:timer)
{
	g_Integer[CountDown]--;

	SetHudTextParams(-1.0, 0.4, 1.0, g_iTextColor[0], g_iTextColor[1], g_iTextColor[2], 255);

	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			 ShowSyncHudText(i, g_Handle[HudText], "Warmup %d", g_Integer[CountDown]);

	if (g_Integer[CountDown] == 5 && g_Bool[BalancerActive])
	{
		BalanceTeams();
		PrintToChatAll("[SM] Balanced Teams");
	}

	else if (g_Integer[CountDown] <= 0)
	{
		if (g_Bool[ModFF])
			SetConVarBool(g_Handle[FF], false);

		if (g_Integer[ModGravity] > 0)
			ResetConVar(g_Handle[Gravity]);

		decl String:szWarmupEndMessage[100];
		GetConVarString(g_Handle[WarmupEndMessage], szWarmupEndMessage, sizeof(szWarmupEndMessage));

		for (new i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i))
				ShowSyncHudText(i, g_Handle[HudText], "%s", szWarmupEndMessage);

		ServerCommand("mp_minplayers 0");

		g_Bool[BalancerActive] = false;

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

//can't cancel spawning to avoid being balanced
public Action:CMD_CancelSpawn(client, const String:command[], args)
{
	if (g_Bool[BalancerActive])
		return Plugin_Handled;

	else
		return Plugin_Continue;
}

//force spawn in warmup round so their level loads
public OnClientPutInServer(client)
{
	if (g_Bool[BalancerActive] && g_Bool[BalancerActive] && !IsFakeClient(client))
		CreateTimer(3.0, ForceSpawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action:ForceSpawn(Handle:timer, any:Userid)
{
	new client = GetClientOfUserId(Userid);

	if (!client || !g_Bool[BalancerActive])
	{}

	else if (IsClientInGame(client))
	{
		FakeClientCommand(client, "jointeam 0");
		FakeClientCommand(client, "joinclass %d 0", GetRandomInt(0,3));
		SetClientSpawnPoint(client);
		FakeClientCommand(client, "readytoplay");
	}

	else
		CreateTimer(0.5, ForceSpawn, Userid, TIMER_FLAG_NO_MAPCHANGE);
}

SetClientSpawnPoint(client)
{
	static Float:CtVec[3], Float:EmpVec[3];

	//	Set the client's spawn point
	if (client)
	{
		switch (GetClientTeam(client))
		{
			case TEAM_CON:
			SetEntPropVector(client, Prop_Send, "m_vecSelectedSpawnArea", CtVec);
			case TEAM_EMP:
			SetEntPropVector(client, Prop_Send, "m_vecSelectedSpawnArea", EmpVec);
		}
	}

	// 0 was passed from OnMapStart, find the Tgates
	else
	{
		new ent = -1;
		while ((ent = FindEntityByClassname(ent, "struct_transport_gate")) != -1)
		{
			switch (GetEntProp(ent, Prop_Send,  "m_iTeamNum"))
			{
				case TEAM_CON:
				GetEntPropVector(ent, Prop_Send, "m_vecOrigin", CtVec);
				case TEAM_EMP:
				GetEntPropVector(ent, Prop_Send, "m_vecOrigin", EmpVec);
			}
		}
	}
}

BalanceTeams()
{
	new Handle:Array = CreateArray(4, MaxClients+1),
		Commanders[2],
		count = 80,
		client = 1,
		bool:team = true;

	Commanders[0] = GameRules_GetPropEnt("m_hCommanders", 0);
	Commanders[1] = GameRules_GetPropEnt("m_hCommanders", 1);

	SetArrayCell(Array, 0, -1);

	for (; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && client != Commanders[0] && client != Commanders[1])
			SetArrayCell(Array, client, GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, client));

		else
			SetArrayCell(Array, client, -1);
	}

	/* Start at 80. search for a level 80. Put him on Consortium. Find the next level 80. Put him on Empire.
			If there are no 80's left, move to 79 and repeat. */

	while (count > -1)
	{
		client = FindValueInArray(Array, count);

		if (client == -1)
			count--;

		else
		{
			ChangeClientTeam(client, 1);
			ChangeClientTeam(client, team ? 2 : 3);
			team = !team;
			SetArrayCell(Array, client, -1);
		}
	}

	CloseHandle(Array);
}

public Action:CMD_BalanceTeams(client,args)
{
	if (g_Bool[BalancerActive])
		ReplyToCommand(client, "[SM] You cannot run the team balancer during the warmup round!");

	else
	{
		//to block the change team chat message
		g_Bool[BalancerActive] = true;

		BalanceTeams();
		LogAction(client, -1, "\"%L\" ran the team balancer.", client);
		ShowActivity2(client, "[SM] ", "Ran the Team Balancer.");
		g_Bool[BalancerActive] = false;
	}

	return Plugin_Handled;
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
	if (g_Bool[BalancerActive]) {
		ReplyToCommand(client, "You cannot use teamdiff during the warmup round!");

	} else if (!g_Bool[TeamDiffAllowed]) {
		ReplyToCommand(client, "You cannot use teamdiff so soon after the last one.");

	} else {

		g_Bool[TeamDiffAllowed] = false;

		new TeamDiff = GetTeamDiff();

		if (TeamDiff < 0)
		{
			TeamDiff *= -1;
			PrintToChatAll("Team Difference: Empire is stacked by %d levels.", TeamDiff);
		} else {
			PrintToChatAll("Team Difference: Consortium is stacked by %d levels.", TeamDiff);
		}
		CreateTimer(10.0, TIMER_EnableTeamDiff);
	}
	return Plugin_Handled;
}

public Action:Event_ChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_Bool[BalancerActive]) {
		SetEventBroadcast(event, true);
		return Plugin_Handled;
	}

	if (!g_Bool[InGameBalance]) {
		return Plugin_Handled;
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

	PrintToServer("player team is %d", GetClientTeam(client));
	PrintToServer("weaker team is %d", weakTeam);

	//SetEventBroadcast(event, true);
	ClientCommand(client, "jointeam %i", weakTeam);
	//ChangeClientTeam(client, weakTeam);
	return Plugin_Handled;
}


GetWeakerTeam(newPlayer) {

	new TeamDiff,
		CountDiff,
		client = 1,
		newPlayerRank;

	for (; client <= MaxClients; client++) {
		if (IsClientInGame(client) && !IsFakeClient(client) && client != newPlayer) {
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

	#if DEBUG ==1
		PrintToServer("coutdiff %d", CountDiff);
		PrintToServer("TeamDiff %d", TeamDiff);
	#endif

	// doesnt matter that much, join underpopulated team
	newPlayerRank = GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, newPlayer);
	if ((TeamDiff < 80 && TeamDiff > -80) || newPlayerRank < 40) {
		if (CountDiff > 0) {
			#if DEBUG == 1
				PrintToServer("cons has more players (%i)", CountDiff);
			#endif
			return TEAM_EMP;
		} else if (CountDiff < 0) {
			#if DEBUG == 1
				PrintToServer("cons has more players (%i)", (CountDiff*-1));
			#endif
			return TEAM_CON;
		} else if (TeamDiff > 0) {
			return TEAM_EMP;
		}

		return TEAM_CON;
	}

	// we're horribly level-stacked
	// it's Empire
	if (TeamDiff < 0) {
		// but is underpopulated, rebalance needed
		if (CountDiff > 1) {
			RebalanceTeams(CountDiff, newPlayerRank);
		}
		return TEAM_EMP;
	}
	// actually it's Consortium. And it's underpopulated - rebalance
	else if (CountDiff < 1) {
		RebalanceTeams(CountDiff, newPlayerRank);
	}

	return TEAM_CON;
}

RebalanceTeams(CountDiff, newPlayerRank) {
	#if DEBUG == 1
		PrintToServer("rebalancing %d", CountDiff);
	#endif

	new Handle:Array = CreateArray(4, MaxClients+1),
		client = 1,
		Commanders[2],
		TeamToPopulate,
		TeamToUnpopulate,
		count = 1;

	Commanders[0] = GameRules_GetPropEnt("m_hCommanders", 0);
	Commanders[1] = GameRules_GetPropEnt("m_hCommanders", 1);

	if (CountDiff < 0) {
		TeamToPopulate = TEAM_CON;
		TeamToUnpopulate = TEAM_EMP;
	} else {
		TeamToPopulate = TEAM_EMP;
		TeamToUnpopulate = TEAM_CON;

	}

	#if DEBUG == 1
		PrintToServer("team to populate %d", TeamToPopulate);
	#endif


	for (; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) &&
			client != Commanders[0] && client != Commanders[1] &&
			GetClientTeam(client) == TeamToUnpopulate) {
			PrintToServer("found someone %d", client);

			SetArrayCell(Array, client, GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, client));
		} else {
			SetArrayCell(Array, client, -1);
		}
	}

	while (count < newPlayerRank)
	{
		client = FindValueInArray(Array, count);

		if (client == -1)
			count++;

		else
		{
			PrintToServer("rebalancing someone %d", client);
			ChangeClientTeam(client, TeamToPopulate);
			SetArrayCell(Array, client, -1);
			break;
			//TODO - rebalance as closest as possible
		}
	}

	CloseHandle(Array);
}


public Action:TIMER_EnableTeamDiff(Handle:timer)
{
	g_Bool[TeamDiffAllowed] = true;
}

//run from OnMapStart
GetConVarData()
{
	g_Bool[BalancerActive] = GetConVarBool(g_Handle[EnableBalancer]);
	g_Bool[InGameBalance] = GetConVarBool(g_Handle[InGameBalance]);
	g_Integer[CountDown] = RoundToFloor(GetConVarFloat(g_Handle[WarmupTime]));
	GetHudTextColors();
	g_Bool[ModFF] = GetConVarBool(g_Handle[ModFF]);
	g_Bool[OrigFF] = GetConVarBool(g_Handle[FF]);
	g_Integer[ModGravity] = GetConVarInt(g_Handle[ModGravity]);
}

GetHudTextColors()
{
	new len, i;
	decl String:Colors[16], String:Temp[16];
	GetConVarString(g_Handle[WarmupTextColor], Colors, 16);

	for (i = 0; i <= 2; i++)
	{
		len += BreakString(Colors[len], Temp, 16);
		g_iTextColor[i] = StringToInt(Temp);

		if (g_iTextColor[i] < 0 || g_iTextColor[i] > 255)
			g_iTextColor[i] = 0;
	}
}
