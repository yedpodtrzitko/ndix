/*
    allow players to use !report to send a suggestion or anything

    0.1     initial version

*/


#include <sourcemod>
#include <colors>


#define PLUGIN_VERSION "0.1.0"
#define DEBUG 0

enum Bools {
    Enabled,
};

enum Handles {
    Handle:Enabled,
};

new g_Handle[Handles] = {INVALID_HANDLE},
    bool:g_Bools[Bools];


public Plugin:myinfo = {
    name = "Report",
    author = "yed_",
    description = "Enable reporting things to admins",
    version = PLUGIN_VERSION,
    url = "https://github.com/yedpodtrzitko/ndix"
}

public OnPluginStart() {
    CreateConVar("sm_report_version", PLUGIN_VERSION, "ND Report Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    g_Handle[Enabled] = CreateConVar("sm_report_enabled", "1", "Flag to (de)activate the plugin");
    g_Bools[Enabled] = GetConVarBool(g_Handle[Enabled]);

    HookEvent("round_start", Event_RoundStart);

    RegConsoleCmd("sm_report", CMD_Report, "send admins a message");
}

public Action:Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    CreateTimer(1000.0, ConnectMsg);
    return Plugin_Continue;
}

public Action:ConnectMsg(Handle:timer, any:client){
	CPrintToChatAll("You can use {green}!report <message>{default} to send any message to the admins");
	return Plugin_Continue;
}

public Action:CMD_Report(client, args) {
    if (!g_Bools[Enabled]) {
        return Plugin_Handled;
    }

    if(!IsClientInGame(client)) {
        return Plugin_Handled;
    }

    char full[256];
    GetCmdArgString(full, sizeof(full));

    decl String:player_authid[32];
    if (!GetClientAuthId(client, AuthId_Steam2, player_authid, sizeof(player_authid))) {
        strcopy(player_authid, sizeof(player_authid), "UNKNOWN");
    }

    int player_userid = GetClientUserId(client);
    PrintToServer("[report] %N %s", client, full);
    LogToGame("\"%N<%d><%s><%s>\" triggered \"report\" %s", client, player_userid, player_authid, "CONSORTIUM", full);

    ReplyToCommand(client, "\x04[NDix] report sent, thanks");
    return Plugin_Handled;
}
