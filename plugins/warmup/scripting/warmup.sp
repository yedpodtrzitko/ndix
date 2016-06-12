#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <ndix>

#define NAME "ND Warmup Round"
#define PLUGIN_VERSION "1.3.1"
#define DEBUG 0

#define TEAM_CON 2
#define TEAM_EMP 3


public Plugin:myinfo =
{
	name = NAME,
	author = "Xander, yed_",
	description = "Warmup Round for ND",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=186001"
}


ConVar c_PluginEnabled;
ConVar c_WarmupTime;
ConVar c_WarmupTextColor;
ConVar c_ModFF;
ConVar c_FF;
ConVar c_BQ;
ConVar c_ElectionTime;

Handle h_HudText;

int CountDown;
new g_iTextColor[3];
new PlayerManager;
new Commanders[2];
bool PluginEnabled;

int CANDIDATES[MAXPLAYERS+1] = {0, ...};

char PriorityPlayers[][] = {
    "STEAM_1:1:46107040",     //1 McGreger 1:1
    "STEAM_1:0:48021119",     //2 Spade
    "STEAM_1:0:27111230",     //3 muon
    "STEAM_1:0:38614392",     //4 Kinev
    "STEAM_1:1:26929916",     //5 Sexy 1:1
    "STEAM_1:0:41825895",     //6 Scrappy
    "STEAM_1:0:18973999",     //7 Troop
    "STEAM_1:1:32251652",     //8 Tea
    "STEAM_1:0:26518082",     //9 Phi
    "STEAM_1:0:23448816",     //10 Nuke Skywalker
    "STEAM_1:0:31299340",     //11 Bender
    "STEAM_1:0:29258395",      //12 djfish
};

bool lowRestricted = false;
//new g_iPlayerManager;
/*
new String:TaintedPlayers[1][32] = {
	"STEAM_1:0:7307733"		//1 roamn
};
*/

public OnPluginStart()
{
	CreateConVar("ndix_warmup_version", PLUGIN_VERSION, NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	c_PluginEnabled 	=	CreateConVar("sm_warmup_enabled", "1", "0 to disable warmup");
	c_WarmupTime 		=	CreateConVar("sm_warmup_time", "100.0", "Sets the warmup time.", FCVAR_NONE, true, 5.0, false);
	c_WarmupTextColor 	= 	CreateConVar("sm_warmup_text_color", "0 255 0", "Set the warmup text RGB values seperated by spaces.");
	c_ModFF 			= 	CreateConVar("sm_warmup_modify_ff", "1", "Enabling this Cvar will turn FF on durning the warmup round, then back off when it ends.");
	c_FF				=	FindConVar("mp_friendlyfire");
	c_BQ				=	FindConVar("bot_quota");
	c_ElectionTime		=	FindConVar("nd_commander_election_time");

	h_HudText = CreateHudSynchronizer();

	SetConVarBounds(FindConVar("mp_minplayers"), ConVarBound_Upper, true, 100.0);

	AddCommandListener(CMD_CancelSpawn, "postpone_spawn");
	AddCommandListener(Command_Apply, "applyforcommander");
	//HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	AutoExecConfig(true, "ndix_warmup");
}

public OnMapStart()
{
	PluginEnabled = c_PluginEnabled.BoolValue;
	if (!PluginEnabled) {
		return;
	}

	CountDown = RoundToFloor(c_WarmupTime.FloatValue);
	c_ElectionTime.IntValue = CountDown;
	GetHudTextColors();

	//g_iPlayerManager = FindEntityByClassname(-1, "nd_player_manager");
	for (int c=0; c<MAXPLAYERS+1; c++) {
		CANDIDATES[c] = 0;
	}
	Commanders = {0,0};

	PlayerManager = FindEntityByClassname(-1, "nd_player_manager");

	ServerCommand("mp_minplayers 100");

	CreateTimer(1.0, WarmupRoundTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	SetClientSpawnPoint(0);	//find the Tgates' origins

	if (c_ModFF.BoolValue) {
		c_FF.BoolValue = true;
	}

	lowRestricted = false;
	CreateTimer(140.0, RestrictLow, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RestrictLow(Handle hTimer, Handle dp) {
	lowRestricted = false;
	PrintToChatAll("\x04%s low-level commanders restriction removed", SERVER_NAME_TAG);
}


public Action WarmupRoundTimer(Handle timer)
{
	CountDown--;

	SetHudTextParams(-1.0, 0.4, 1.0, g_iTextColor[0], g_iTextColor[1], g_iTextColor[2], 100);
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			if(CANDIDATES[i]) {
				ShowSyncHudText(i, h_HudText, "Your application confirmed\nWait for the end of the election time (%d)", CountDown);
			} else {
				ShowSyncHudText(i, h_HudText, "Apply for commander now (%d)", CountDown);
			}
		}
	}

	if (CountDown == 5 && PluginEnabled)
	{
		BalanceTeams();
		PrintToChatAll("%s Balanced Teams", SERVER_NAME_TAG);
	}

	else if (CountDown <= 0)
	{
		if (c_ModFF.BoolValue) {
			c_FF.BoolValue = false;
		}

		/*
		decl String:szWarmupEndMessage[100];
		GetConVarString(g_Handle[WarmupEndMessage], szWarmupEndMessage, sizeof(szWarmupEndMessage));

		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				ShowSyncHudText(i, g_Handle[HudText], "%s", szWarmupEndMessage);
			}
		}
		*/
		ServerCommand("mp_minplayers 0");

		CreateTimer(2.0, PromoteNow);

		PluginEnabled = false;

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action PromoteNow(Handle Timer) {
	for (int i=0;i<2; i++) {
		if (Commanders[i] && IsClientInGame(Commanders[i])) {
			//FakeClientCommand(Commanders[i], "applyforcommander");
			ServerCommand("_promote_to_commander %d", Commanders[i]);
		}
	}
	return Plugin_Stop;
}
//can't cancel spawning to avoid being balanced
public Action CMD_CancelSpawn(client, const String:command[], args)
{
	if (PluginEnabled) {
		return Plugin_Handled;
	} else {
		return Plugin_Continue;
	}
}


//force spawn in warmup round so their level loads
public OnClientPutInServer(client)
{
	if (PluginEnabled && !IsFakeClient(client))
		CreateTimer(3.0, ForceSpawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action ForceSpawn(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !PluginEnabled)
	{
		return Plugin_Continue;
	}

	if (IsClientInGame(client))
	{
		FakeClientCommand(client, "jointeam 0");
		FakeClientCommand(client, "wjoinclass %d 0", GetRandomInt(0,3));
		SetClientSpawnPoint(client);
		FakeClientCommand(client, "readytoplay");
	} else {
		CreateTimer(0.5, ForceSpawn, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}


SetClientSpawnPoint(client)
{
	float CtVec[3];
	float EmpVec[3];

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
		int ent = -1;
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
	PrintToChatAll("balancing");
	Handle Array = CreateArray(4, MaxClients+1);
	int count = 80;
	int client = 1;
	int found = 0;

	bool team = true;
	SetArrayCell(Array, 0, -1);
	c_BQ.IntValue = 0;

	for (; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client)) {
			SetArrayCell(Array, client, GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, client));
		} else {
			SetArrayCell(Array, client, -1);
		}
	}

	// run through priority players and see if they applied
	for(int c=1; c<MAXPLAYERS; c++) {
		if (!CANDIDATES[c]) {
			continue;
		}

		if (!IsClientInGame(c) || IsFakeClient(c)) {
			continue;
		}

		char playerId[32];
		GetClientAuthId(c, AuthId_Steam2, playerId, sizeof(playerId));

		//if (Array_FindString(TaintedPlayers, sizeof(TaintedPlayers), playerId) != -1) {
		if (Array_FindString(PriorityPlayers, sizeof(PriorityPlayers), playerId) != -1) {
			if (!Commanders[0]) {
				Commanders[0] = CANDIDATES[c];
				CANDIDATES[c] = 0;
				SetArrayCell(Array, c, -1);
			} else if (!Commanders[1]) {
				Commanders[1] = CANDIDATES[c];
				CANDIDATES[c] = 0;
				SetArrayCell(Array, c, -1);
			} else {
				break;
			}
		}
	}

	/* try to find non-privileged comms */
	while (count > -1)
	{
		client = FindValueInArray(Array, count);

		if (client == -1) {
			count--;
		} else if (CANDIDATES[client]){
			if (!Commanders[0]) {
				Commanders[0] = client;
				CANDIDATES[client] = 0;
				SetArrayCell(Array, client, -1);
			} else if (!Commanders[1]) {
				Commanders[1] = client;
				CANDIDATES[client] = 0;
				SetArrayCell(Array, client, -1);
			} else {
				break;
			}
		} else {
			count--;
		}
	}

	for (int i=0; i<2; i++) {
		if (Commanders[i]) {
			ChangeClientTeam(Commanders[i], i+2);
			team = !team;
			found++;
		}
	}

	/* 	Start at 80. search for a level 80. Put him on Consortium.
		Find the next level 80. Put him on Empire.
		If there are no 80's left, move to 79 and repeat. */
	count = 80;
	while (count > -1)
	{
		client = FindValueInArray(Array, count);

		if (client == -1) {
			count--;
		} else {
			ChangeClientTeam(client, 1);
			ChangeClientTeam(client, team ? 2 : 3);
			team = !team;
			SetArrayCell(Array, client, -1);
			found++;
		}
	}

	if (found < 12) {
		c_BQ.IntValue = (12 - found);
	}

	CloseHandle(Array);
}


public Action Command_Apply(int client, const char[] command, args)
{
	/*
	int g_iRankOffset = FindSendPropInfo("CNDPlayerResource", "m_iPlayerRank");
	int rank = GetEntData(g_iPlayerManager, g_iRankOffset + 4*client);
	if (rank < 15 && lowRestricted) {
		PrintToChat(client, "\x04Players with level < 15 cant apply for commander yet, try it in a minute again");
		return Plugin_Handled;
	}*/

	if(!IsClientInGame(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	if (!PluginEnabled) {
		return Plugin_Continue;
	}

	CANDIDATES[client] = client;
	PrintToChat(client, "\x04Your application confirmed, please wait.");

	return Plugin_Continue;
	//return Plugin_Handled;
}

GetHudTextColors()
{
	int len;
	char Colors[16];
	char Temp[16];
	GetConVarString(c_WarmupTextColor, Colors, 16);

	for (int i = 0; i <= 2; i++)
	{
		len += BreakString(Colors[len], Temp, 16);
		g_iTextColor[i] = StringToInt(Temp);

		if (g_iTextColor[i] < 0 || g_iTextColor[i] > 255)
			g_iTextColor[i] = 0;
	}
}
