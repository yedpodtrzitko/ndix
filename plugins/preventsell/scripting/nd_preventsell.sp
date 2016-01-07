/*
    A rough fix for crashing server by selling sonic turrets

    0.1     initial version

*/


#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "0.1.0"
#define DEBUG 0

public Plugin:myinfo = {
    name = "Sonic crasher",
    author = "yed_",
    description = "Prevent server crash by disabling selling the sonic turret",
    version = PLUGIN_VERSION,
    url = "git@vanyli.net:nd-plugins"
}

public OnPluginStart() {
    CreateConVar("sm_nd_preventsell_version", PLUGIN_VERSION, "ND Preventsell Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public OnEntityCreated(entity, const String:classname[]){
    if(StrEqual(classname, "struct_sonic_turret", false)){
        new currentFlags = GetEntProp(entity, Prop_Send, "m_iStructFlags");
        new newFlags = currentFlags | 4; //eNDStructFlags[NDFLAG_CANT_SELL];
        SetEntProp(entity, Prop_Send, "m_iStructFlags", newFlags);
    } else if(StrEqual(classname, "struct_flamethrower_turret", false)){
        // not needed, but make it fair
        new currentFlags = GetEntProp(entity, Prop_Send, "m_iStructFlags");
        new newFlags = currentFlags | 4; //eNDStructFlags[NDFLAG_CANT_SELL];
        SetEntProp(entity, Prop_Send, "m_iStructFlags", newFlags);
    }
}
