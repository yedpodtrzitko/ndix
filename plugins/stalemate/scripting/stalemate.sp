/*
    Trigger Stalemate on ...stalemate, you know

    0.1     initial version

*/


#include <sourcemod>
#include <sdktools>


#define PLUGIN_VERSION "0.1.0"
#define DEBUG 0

public Plugin:myinfo = {
    name = "Stalemate trigger",
    author = "yed_",
    description = "Trigger stalemate on T zero",
    version = PLUGIN_VERSION,
    url = "http://ndix.vanyli.net"
}

public OnPluginStart() {
    CreateConVar("sm_cake_event_version", PLUGIN_VERSION, "ND Stalemate version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    HookEvent("round_win", Event_RoundEnd, EventHookMode_Pre);
}

public Action:Event_RoundEnd(Handle event, const String:name[], bool dontBroadcast) {
    int type = GetEventInt(event, "type");
    if (type == 4) {
        int ent = FindEntityByClassname(-1, "nd_logic_custom");
        Handle evt = CreateEvent("round_win");

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
