/*
    Snipers Limit

    Author: yed_

    0.8     something, idk

    0.7     whitelist of good snipers (and me :p)
            fixed the loophole for Armoury

    0.6     cleaned some shit

    0.5     fix the class detection

    0.4     dont declare inner function as public Action:
            added some debug messages

	0.3 	edited by stickz
			enumeration classes and handles
			renaming of variables to be more clear
			reduction of unneeded defines and global variables
			GetTeamName() function from SM API is now used
			alot of strings now use decl for casting (faster)
			added else if statements to skip redundant value checking

    0.2     added `strict` flag
            added `enabled` flag

    0.1     initial version

*/


#include <sourcemod>
#include <sdktools>
#include <colors>
#include <smlib>

#define PLUGIN_VERSION "0.7.1"
#define DEBUG 0

#define TEAM_CON 2
#define TEAM_EMP 3

#define ASSAULT_CLASS 0
#define ASSAULT_INFANTRY 0
#define ASSAULT_MARKSMAN 2

#define SNIPER_CLASS 2
#define SNIPER_SNIPER 1

#define m_iDesiredPlayerClass(%1) (GetEntProp(%1, Prop_Send, "m_iDesiredPlayerClass"))
#define m_iDesiredPlayerSubclass(%1) (GetEntProp(%1, Prop_Send, "m_iDesiredPlayerSubclass"))

int CurrentCount[4] = {0,0,0,0};
int LimitValue[4] = {0,0,0,0};
Handle h_Enabled;
Handle h_Limit;

char AllowedPlayers[][] = {
    "STEAM_1:1:53763028",    //Wrecked Em
    "STEAM_1:1:32804464",    //Digger404
    "STEAM_1:0:35010700",    //FirstBlood
    "STEAM_1:0:16995602",    //vaskrist
    "STEAM_1:0:29258395",    //djfishfish
    "STEAM_1:0:48630697",    //gingershavenosoul
    "STEAM_1:0:7971298",     //UltraSpaceMarine
    "STEAM_1:0:27135895",    //NDS: TheGuardians13
    "STEAM_1:0:68095718",    //NDS: NemezisFromHell
    "STEAM_0:1:53653141",    //NDS: Bibouchko 0:1
    "STEAM_1:1:53653141",    //NDS: Bibouchko 1:1
    "STEAM_1:0:1791281",     //NDS: Prort
    "STEAM_1:0:33657626",    //12 yed_
};

public Plugin:myinfo = {
    name = "Sniper Limiter",
    author = "yed_",
    description = "Limit the number of snipers in the team",
    version = PLUGIN_VERSION,
    url = "https://github.com/yedpodtrzitko/ndix/"
}

public OnPluginStart() {
    h_Enabled =CreateConVar("sm_maxsnipers_enabled", "1", "Flag to (de)activate the plugin");
    h_Limit = CreateConVar("sm_maxsnipers_limit", "2", "Limit the number of snipers in a team (Default 2)");
    CreateConVar("sm_maxsnipers_version", PLUGIN_VERSION, "ND Maxsnipers Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    RegAdminCmd("sm_maxsnipers_admin", CMD_ChangeSnipersLimit, ADMFLAG_GENERIC, "!maxsnipers_admin <team> <amount>");
    RegConsoleCmd("sm_maxsnipers", CMD_ChangeTeamSnipersLimit, "Change the maximum number of snipers in the team: !maxsnipers <amount>");

    HookEvent("player_changeclass", Event_ChangeClass, EventHookMode_Pre);
    HookEvent("player_death", Event_PlayerDied, EventHookMode_Post);

    ResetLimits();
}

public OnMapStart() {
    ResetLimits();
}

RecountClasses(client) {
    int client_team = GetClientTeam(client);
    int cls = 0
    int subcls = 0;
    int recalced = 0;

    LOOP_CLIENTS(i, CLIENTFILTER_INGAME | CLIENTFILTER_NOBOTS) {
        if (IsValidClient(i)) {
            if (client_team == GetClientTeam(i)) {
                cls = m_iDesiredPlayerClass(i);
                subcls = m_iDesiredPlayerSubclass(i);
                if (IsSniperClass(cls, subcls)) {
                    recalced++;
                }
            }
        }
    }

    #if DEBUG == 1
        PrintToChat(client, "recalced %i - %i ", client_team, recalced);
    #endif

    CurrentCount[client_team] = recalced;
}

public Action:Event_ChangeClass(Handle:event, const String:name[], bool:dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int cls = GetEventInt(event, "class");
    int subcls = GetEventInt(event, "subclass");

    #if DEBUG == 1
        PrintToChat(client, "chosen %i - %i", cls, subcls);
    #endif

    RecountClasses(client);
    if (IsAllowedPlayer(client)) {
        return Plugin_Continue;
    }

    if (IsSniperClass(cls, subcls)) {
        #if DEBUG == 1
            PrintToChat(client, "chosen sniper class");
        #endif

        if (IsTooMuchSnipers(client)) {
            ResetClass(client);
            return Plugin_Continue;
        }
    }

    return Plugin_Continue;
}

IsAllowedPlayer(client) {
    char playerId[32];
    GetClientAuthId(client, AuthId_Steam2, playerId, sizeof(playerId));
    return Array_FindString(AllowedPlayers, sizeof(AllowedPlayers), playerId) != -1;
}

public Action:Event_PlayerDied(Handle:event, const String:name[], bool:dontBroadcast) {
    if (GetConVarInt(h_Enabled) != 1 ) {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int cls = m_iDesiredPlayerClass(client);
    int subcls = m_iDesiredPlayerSubclass(client);

    #if DEBUG == 1
        PrintToChat(client, "chosen %i - %i", cls, subcls);
    #endif

    RecountClasses(client);

    if (IsSniperClass(cls, subcls)) {
        if (IsAllowedPlayer(client)) {
            return Plugin_Continue;
        }

        if (IsTooMuchSnipers(client)) {
            ResetClass(client);
            return Plugin_Continue;
        }
    }

    return Plugin_Continue;
}


// CHANGE LIMIT
public Action:CMD_ChangeSnipersLimit(client, args) {
    if (GetConVarInt(h_Enabled) != 1 ) {
        return Plugin_Continue;
    }

    if (!IsValidClient(client)) {
        return Plugin_Handled;
    }

    if (args != 2) {
        PrintToChat(client, "[NDix] maxsnipers_admin: Invalid number of arguments: <team> <amount>");
        return Plugin_Handled;
    }

    decl String:strteam[32];
    GetCmdArg(1, strteam, sizeof(strteam));
    int team = StringToInt(strteam);

    decl String:strvalue[32];
    GetCmdArg(2, strvalue, sizeof(strvalue));
    int value = StringToInt(strvalue);

    ChangeSnipersLimit(client, team+2, value);
    return Plugin_Handled;
}

public Action:CMD_ChangeTeamSnipersLimit(client, args) {
    if (GetConVarInt(h_Enabled) != 1 ) {
        return Plugin_Continue;
    }

    if (!IsValidClient(client)) {
        return Plugin_Handled;
    }

    int client_team = GetClientTeam(client);

    #if DEBUG == 1
        PrintToChat(client, "client team %i", client_team);
    #endif

    if (client_team < 2) {
        return Plugin_Handled;
    }

    if (args == 0) {
        PrintToChat(client, "[NDix] current snipers limit is %i", LimitValue[client_team]);
        return Plugin_Handled;
    }

    if (GameRules_GetPropEnt("m_hCommanders", (client_team-2)) != client) {
        PrintToChat(client, "[NDix] snipers limiting is available only for Commander");
        return Plugin_Handled;
    }

    decl String:strvalue[32];
    GetCmdArg(1, strvalue, sizeof(strvalue));
    int value = StringToInt(strvalue);

    #if DEBUG == 1
        PrintToChat(client, "acount to change");
    #endif

    ChangeSnipersLimit(client, client_team, value);
    return Plugin_Handled;
}




// HELPER FUNCTIONS
IsTooMuchSnipers(client) {
    int client_team = GetClientTeam(client);

    #if DEBUG == 1
        PrintToChat(client, "current %i, allowed %i, team %i",  CurrentCount[client_team], LimitValue[client_team], client_team);
    #endif

    return CurrentCount[client_team] > LimitValue[client_team];
}

IsSniperClass(class, subclass) {
    return (class == ASSAULT_CLASS && subclass == ASSAULT_MARKSMAN) || (class == SNIPER_CLASS && subclass == SNIPER_SNIPER)
}

ResetClass(client) {
    SetEntProp(client, Prop_Send, "m_iPlayerClass", ASSAULT_CLASS);
    SetEntProp(client, Prop_Send, "m_iPlayerSubclass", ASSAULT_INFANTRY);
    SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", ASSAULT_CLASS);
    SetEntProp(client, Prop_Send, "m_iDesiredPlayerSubclass", ASSAULT_INFANTRY);
    SetEntProp(client, Prop_Send, "m_iDesiredGizmo", 0);

    PrintToChat(client, "[NDix] Snipers limit reached, resetting to Assault");
}

ResetLimits() {
    LimitValue[TEAM_EMP] = GetConVarInt(h_Limit);
    LimitValue[TEAM_CON] = GetConVarInt(h_Limit);
}

stock bool:IsValidClient(client, bool:nobots = true)
{
    if (client < 1 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
        return false;

    return IsClientInGame(client);
}

ChangeSnipersLimit(client, team, value)
{
	if (team != 2 && team != 3)
	{
		PrintToChat(client, "[NDix] maxsnipers: Invalid team id (0 CON, 1 EMP)");
		return;
	}

	if (value > 10)
        value = 10;

	else if (value < 0)
        value = 0;

	LimitValue[team] = value;

    #if DEBUG == 1
    	PrintToChat(client, "limit set to %i for %i", value, team);
    #endif

	char teamName[16];
	PrintToChat(client, "[NDix] %s: snipers limit set to %i", GetTeamName(team, teamName, 16), value);
}
