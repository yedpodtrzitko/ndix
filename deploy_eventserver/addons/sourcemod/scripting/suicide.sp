#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

// thank you to Azelphur for helping me waffle up my code
public Plugin:myinfo =
{
    name = "Suicide",
    author = "yed_",
    description = "suicide plugin",
    version = "0.1",
    url = "git@vanyli.net:nd-plugins"
};
 
public OnPluginStart()
{
    RegConsoleCmd("sm_kill", Command_suicide);
}

public Action:Command_suicide(client, args)
{   
    if(!client)
    {
        return Plugin_Handled;
    }

    if(!IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }
    
    ForcePlayerSuicide(client);           
    return Plugin_Handled;
}
