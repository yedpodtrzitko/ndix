#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <sdkhooks>

#define NAME "ND Teamdiff"
#define PLUGIN_VERSION "0.1.1"
#define DEBUG 0

#define TEAM_CON 2
#define TEAM_EMP 3
#define TEAMDIFF 140
#define TEAMSWITCH 20

public Plugin:myinfo =
{
	name = NAME,
	author = "yed_",
	description = "Shows teamdiff value.",
	version = PLUGIN_VERSION,
    url = "https://github.com/yedpodtrzitko/ndix"
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

bool g_Bool[Bools];
Handle g_Handle[Handles] = {INVALID_HANDLE, ...};
int PlayerManager;
bool activated;
int stackedTeam = 0;
float damageMultiplier = 1.0;

public OnPluginStart()
{
	CreateConVar("ndix_teamdiff_version", PLUGIN_VERSION, NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_Handle[PluginEnabled] 	= 	CreateConVar("ndix_teamdiff_active", "1", "0 to disabled teamdiff");
	g_Handle[BalancerEnabled] 	= 	CreateConVar("ndix_ingame_balance", "1", "enable automatic balancing");

	RegConsoleCmd("sm_teamdiff", CMD_TeamDiff);
	RegConsoleCmd("sm_stacked", CMD_TeamDiff);

	g_Handle[HudText] = CreateHudSynchronizer();

	AutoExecConfig(true, "ndix_teamdiff");
	activated = false;
}


public OnMapStart() {
	GetConVarData();

	PlayerManager = FindEntityByClassname(-1, "nd_player_manager");
	activated = false;
	stackedTeam = 0;
	damageMultiplier = 1.0;
	CreateTimer(80.0, ActivateTeamdiff);
}

public OnMapEnd() {
	activated = false;
}

public Action ActivateTeamdiff(Handle timer) {
	activated = true;
	//CreateTimer(5.0, UpdateTeamDiffLabel, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, UpdateTeamDiffLabel, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}


public OnEntityCreated(entity, const String:classname[]){
    if (strncmp(classname, "struct_", 7) == 0) {
        SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (1 <= attacker <= MaxClients)
	{
		if (GetClientTeam(attacker) == stackedTeam) {
			damage *= damageMultiplier;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public Action UpdateTeamDiffLabel(Handle:timer) {
	int TeamDiff = GetTeamDiff();
	char buffer[512];
	int stackedTeamId;
	int rgb[3] = {200, ...};

	if (TeamDiff < 0)
	{
		stackedTeamId = TEAM_EMP;
		TeamDiff *= -1;
		Format(buffer, sizeof(buffer), "EMP +%d", TeamDiff);
	} else {
		stackedTeamId = TEAM_CON;
		Format(buffer, sizeof(buffer), "CN +%d", TeamDiff);
	}

	if (TeamDiff > 300) {
		rgb = {255, 0,  50};
	} else if (TeamDiff > 140) {
		rgb = {255, 150, 0};
	} else {
		rgb = {255,255,255};
	}

	SetHudTextParams(1.0, 0.0, 30.0, rgb[0], rgb[1], rgb[2], 100);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			 ShowSyncHudText(i, g_Handle[HudText], buffer);
			 //ShowHudText(i, -1, buffer);
		}
	}

	if (TeamDiff >= TEAMDIFF){// && g_Bool[BalancerEnabled]) {
		damageMultiplier = 1.0 - ((TeamDiff - 100.0)/ 440.0);
		stackedTeam = stackedTeamId;
	} else {
		damageMultiplier = 1.0;
		stackedTeam = 0;
	}

	return Plugin_Continue;
}


GetTeamDiff() {
	int TeamDiff;
	LOOP_CLIENTS(i, CLIENTFILTER_INGAME | CLIENTFILTER_NOBOTS) {
		switch (GetClientTeam(i))
		{
			case TEAM_CON:
			TeamDiff += GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, i);
			case TEAM_EMP:
			TeamDiff -= GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, i);
		}
	}
	return TeamDiff;
}

public Action CMD_TeamDiff(client, args)
{
	if (!activated) {
		CreateTimer(0.1, UpdateTeamDiffLabel);
		CreateTimer(5.0, UpdateTeamDiffLabel, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		activated = true;
	}

	ReplyToCommand(client, "Teamdiff is in the top right corner");
	return Plugin_Handled;
}


//run from OnMapStart
GetConVarData()
{
	g_Bool[PluginEnabled] = GetConVarBool(g_Handle[PluginEnabled]);
	g_Bool[BalancerEnabled] = GetConVarBool(g_Handle[BalancerEnabled]);
}
