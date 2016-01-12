#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
    name = "Suicide",
    author = "yed_",
    description = "suicide plugin",
    version = "0.1",
    url = "https://github.com/yedpodtrzitko/ndix"
};
 
public OnPluginStart()
{
    RegConsoleCmd("sm_kill", Command_suicide);
    RegConsoleCmd("sm_die", Command_suicide);
    RegConsoleCmd("sm_stuck", Command_suicide);
    RegConsoleCmd("sm_suicide", Command_suicide);
}

public Action:Command_suicide(client, args)
{   
    if(!client || !IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }

    ForcePlayerSuicide(client);
    return Plugin_Handled;
}
