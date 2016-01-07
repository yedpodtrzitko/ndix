/*
    Trigger Stalemate on ...stalemate, you know

    0.1     initial version

*/


#include <sourcemod>
#include <sdktools>


#define PLUGIN_VERSION "0.1.0"
#define DEBUG 0

enum Bools {
    Enabled,
}

enum Handles {
    Handle:Enabled,
}

new g_Handle[Handles] = {INVALID_HANDLE},
    bool:g_Bools[Bools];


public Plugin:myinfo = {
    name = "Stalemate trigger",
    author = "yed_",
    description = "Trigger stalemate on T zero",
    version = PLUGIN_VERSION,
    url = "http://ndix.vanyli.net"
}

public OnPluginStart() {
    CreateConVar("sm_cake_event_version", PLUGIN_VERSION, "ND Stalemate version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    g_Handle[Enabled] = CreateConVar("sm_stalemate_enabled", "1", "Flag to (de)activate the plugin");
    g_Bools[Enabled] = GetConVarBool(g_Handle[Enabled]);
    HookConVarChange(g_Handle[Enabled], OnCVarChange);

    HookEvent("round_win", Event_RoundEnd, EventHookMode_Pre);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
    new type = GetEventInt(event, "type");
    if (type == 4) {
        new ent = FindEntityByClassname(-1, "nd_logic_custom");
        new Handle:evt = CreateEvent("round_win");

        if (ent == -1)
        {
            ent = CreateEntityByName("nd_logic_custom");
            DispatchSpawn(ent);
        }

        SetEventInt(evt, "type", 2);
        SetEventInt(evt, "team", 0);

        AcceptEntityInput(ent, "EndRoundAuto");
        FireEvent(evt);
    	return Plugin_Handled;
    }

    return Plugin_Continue;
}



public OnCVarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	GetCVars();
}

GetCVars()
{
	g_Bools[Enabled] = GetConVarBool(g_Handle[Enabled]);
}
