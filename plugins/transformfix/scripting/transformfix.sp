/*
public Action:Event_ArmouryMenu(client, const String:command[], args)
{
	if (!client || !IsClientInGame(client)) {
		return Plugin_Handled;
	}

	looking at it now. the server marks the player as being in the armory when they "Use" it, right before sending the player_opened_armoury_menu event that you're hooking
	[02:30am] psychonic:
	but then the server never clears that on it's own
	[02:30am] psychonic:
	the state doesn't clear until the player sends its "readytoplay" command from closing the menu
	[02:30am] psychonic:
	:facepalm:
	you'd want to hook whatever the command for changing class is
	not the event that proceeds it
	joinclass is the command
	you can either check and then block the command
	or check and then set m_bArmouryClassChange to false
	it's not a sendprop, but it's directly after m_flLastSpawnTime, so you could get the offset of that and add 4, then use SetEntData
	then instead of ignoring the command, it would just treat it like a non-armory one, changing them on next spawn
	^ where is this flag from? I grepped netprops dump, and didnt found anything containing "(.*)armo(.*)"
	it's not a netprop
	https://www.irccloud.com/pastebin/wMxy3SO0
		//CNetworkVar( float, m_flLastSpawnTime );
		//bool m_bArmouryClassChange;
	it does come right after a netprop, so you can assume that the offset is just +4 from the one before it
	if you want to get fancy, you can hook StartTouch and EndTouch on the armory, setting that var manually for any players
	and then not have to worry about hooking joinclass
	or the event
	actually, just EndTouch to clear it. you don't want changes to work when just touching the outside of an armory
	and it will still auto set as true when doing a valid Use inside of the armory

	//offset = FindSendPropInfo("CNDPlayer", "m_flLastSpawnTime");
	//PrintToChatAll("offset %d", offset);
*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define NAME "Transform Fix"
#define PLUGIN_VERSION "0.1.0"
#define DEBUG 0

new PlayerClass[MAXPLAYERS + 1] = {0,...};
new PlayerSubclass[MAXPLAYERS + 1] = {0,...};


public Plugin:myinfo =
{
	name = NAME,
	author = "yed_",
	description = "Class Transform Fix",
	version = PLUGIN_VERSION,
	url = "http://ndix.vanyli.net"
}

public OnPluginStart()
{
	CreateConVar("ndix_transformfix_version", PLUGIN_VERSION, NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	//AddCommandListener(Event_ArmouryMenu, "joinclass");

	HookEvent("player_spawned_at_tgate", Event_Spawned, EventHookMode_Pre);
	HookEvent("player_changeclass", Event_ArmouryMenuPre, EventHookMode_Pre);
}

public Action:Event_Spawned(Handle:event, const String:name[], bool:dontBroadcast)
{
 	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client)) {
		return Plugin_Continue;
	}

	PlayerClass[client] = GetEntProp(client, Prop_Send, "m_iPlayerClass");
	PlayerSubclass[client] = GetEntProp(client, Prop_Send, "m_iPlayerSubclass");

	#if DEBUG == 1
		PrintToChatAll("setting info to %d, %d", GetEntProp(client, Prop_Send, "m_iPlayerClass"), 	GetEntProp(client, Prop_Send, "m_iPlayerSubclass"));
	#endif

	return Plugin_Continue;
}

public Action:Event_ArmouryMenuPre(Handle:event, const String:name[], bool:dontBroadcast)
{
 	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client)) {
		return Plugin_Continue;
	}

	if (!IsPlayerAlive(client)) {
		return Plugin_Continue;
	}

	new new_class =  GetEntProp(client, Prop_Send, "m_iPlayerClass") ;
	new new_subclass =  GetEntProp(client, Prop_Send, "m_iPlayerSubclass");

	#if DEBUG == 1
		PrintToChatAll("pre, setting to %d - %d", new_class, new_subclass);
	#endif

	new ent;
	new team = GetClientTeam(client);
	new Float:player_position[3];
	new Float:armoury_position[3];
	new Float:distance;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", player_position);

	if (PlayerClass[client] == new_class && PlayerSubclass[client] == new_subclass) {
		return Plugin_Continue;
	}

	while ((ent = FindEntityByClassname(ent, "struct_armoury")) != -1)
	{
		new teamNum = GetEntProp(ent, Prop_Send, "m_iTeamNum");
		if(teamNum == team) {
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", armoury_position);
			distance = distanceBetweenPts(player_position, armoury_position);
			if (distance < 200) {
				PlayerClass[client] = new_class;
				PlayerSubclass[client] = new_subclass;
				return Plugin_Continue;
			}
		}
	}

	#if DEBUG == 1
		PrintToChatAll("killing");
	#endif

	ForcePlayerSuicide(client);
	return Plugin_Handled;
}

//gets the distance in game units between the specified points
public Float:distanceBetweenPts(Float:pt1[3], Float:pt2[3]){
	return SquareRoot(Pow(pt1[0]-pt2[0],2.0) + Pow(pt1[1]-pt2[1],2.0) + Pow(pt1[2]-pt2[2],2.0));
}

public pointOn2dLine(Float:line1[3], Float:line2[3], Float:toProject[3], Float:result[3])
{
    new Float:m = (line2[1] - line1[1]) / (line2[0] - line1[0]);
    new Float:b = line1[1] - (m * line1[0]);

    new Float:x = (m * toProject[1] + toProject[0] - m * b) / (m * m + 1);
    new Float:y = (m * m * toProject[1] + m * toProject[0] + b) / (m * m + 1);

    result[0]=x;
    result[1]=y;
    result[2]=0.0;
}

public Float:min(Float:x, Float:y){
	if(x <= y){ return x; }
	return y;
}

public Float:max(Float:x, Float:y){
	if(x >= y){ return x; }
	return y;
}
