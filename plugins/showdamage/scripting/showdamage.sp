#include <sourcemod>
#include <clientprefs>
#include <colors>

#define PLUGIN_VERSION "1.0.8"

public Plugin myinfo =
{
	name = "Show Damage",
	author = "exvel",
	description = "Shows damage in the center of the screen.",
	version = PLUGIN_VERSION,
	url = "www.sourcemod.net"
}

int player_damage[MAXPLAYERS + 1];
bool block_timer[MAXPLAYERS + 1] = {false,...};
char DamageEventName[16];
int MaxDamage = 10000000;
bool option_show_damage[MAXPLAYERS + 1] = {true,...};
Handle cookie_show_damage = INVALID_HANDLE;
bool ignoredPlayers[MAXPLAYERS + 1] = {false,};

//CVars
ConVar cvar_show_damage;
ConVar cvar_show_damage_ff;
ConVar cvar_show_damage_own_dmg;
ConVar cvar_show_damage_text_area ;


public void OnPluginStart()
{
	char gameName[80];
	GetGameFolderName(gameName, 80);
	if (StrEqual(gameName, "cstrike") || StrEqual(gameName, "insurgency") || StrEqual(gameName, "nucleardawn"))
	{
		HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
		DamageEventName = "dmg_health";
	}
	else if (StrEqual(gameName, "left4dead") || StrEqual(gameName, "left4dead2"))
	{
		HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
		HookEvent("infected_hurt", Event_InfectedHurt, EventHookMode_Post);
		MaxDamage = 2000;
		DamageEventName = "dmg_health";
	}
	else if (StrEqual(gameName, "dod") || StrEqual(gameName, "hidden"))
	{
		HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
		DamageEventName = "damage";
	}

	CreateConVar("sm_show_damage_version", PLUGIN_VERSION, "Show Damage Version", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	cvar_show_damage = CreateConVar("sm_show_damage", "1", "Enabled/Disabled show damage functionality, 0 = off/1 = on", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_show_damage_ff = CreateConVar("sm_show_damage_ff", "0", "Show friendly fire damage, 0 = off/1 = on", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_show_damage_own_dmg = CreateConVar("sm_show_damage_own_dmg", "0", "Show your own damage, 0 = off/1 = on", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_show_damage_text_area = CreateConVar("sm_show_damage_text_area", "1", "Defines the area for damage text:\n 1 = in the center of the screen\n 2 = in the hint text area \n 3 = in chat area of screen", FCVAR_NONE, true, 1.0, true, 3.0);

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_entered_commander_mode", Event_CommandingStart, EventHookMode_Post);
	HookEvent("player_left_commander_mode", Event_CommandingStop, EventHookMode_Post);

	AutoExecConfig(true, "plugin.showdamage");
	LoadTranslations("common.phrases");
	LoadTranslations("showdamage.phrases");

	cookie_show_damage = RegClientCookie("Show Damage On/Off", "", CookieAccess_Private);
	new info;
	SetCookieMenuItem(CookieMenuHandler_ShowDamage, info, "Show Damage");
}

public Action Event_CommandingStart(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ignoredPlayers[client] = true;
	return Plugin_Continue;
}

public Action Event_CommandingStop(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ignoredPlayers[client] = false;
	return Plugin_Continue;
}

public void CookieMenuHandler_ShowDamage(client, CookieMenuAction action, any info, char[] buffer, maxlen)
{
	if (action == CookieMenuAction_DisplayOption)
	{
		char status[10];
		if (option_show_damage[client])
		{
			Format(status, sizeof(status), "%T", "On", client);
		}
		else
		{
			Format(status, sizeof(status), "%T", "Off", client);
		}

		Format(buffer, maxlen, "%T: %s", "Cookie Show Damage", client, status);
	}
	// CookieMenuAction_SelectOption
	else
	{
		option_show_damage[client] = !option_show_damage[client];

		if (option_show_damage[client])
		{
			SetClientCookie(client, cookie_show_damage, "On");
		}
		else
		{
			SetClientCookie(client, cookie_show_damage, "Off");
		}

		ShowCookieMenu(client);
	}
}

public void OnClientCookiesCached(client)
{
	option_show_damage[client] = GetCookieShowDamage(client);
}

bool GetCookieShowDamage(client)
{
	char buffer[10];
	GetClientCookie(client, cookie_show_damage, buffer, sizeof(buffer));

	return !StrEqual(buffer, "Off");
}

public Action Event_PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	block_timer[client] = false;

	return Plugin_Continue;
}

public Action ShowDamage(Handle timer, any client)
{
	block_timer[client] = false;

	if (player_damage[client] <= 0 || !client)
	{
		return;
	}

	if (!IsClientInGame(client) || ignoredPlayers[client])
	{
		return;
	}

	switch (cvar_show_damage_text_area.IntValue)
	{
		case 1:
		{
			PrintCenterText(client, "%t", "CenterText Damage Text", player_damage[client]);
		}

		case 2:
		{
			PrintHintText(client, "%t", "HintText Damage Text", player_damage[client]);
		}

		case 3:
		{
			CPrintToChat(client, "%t", "Chat Damage Text", player_damage[client]);
		}
	}

	player_damage[client] = 0;
}

public Action Event_PlayerHurt(Handle event, char[] name, bool dontBroadcast)
{
	new client_attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	int damage = GetEventInt(event, DamageEventName);

	char weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	if (StrContains(weapon, "turret") == -1) {
		CalcDamage(client, client_attacker, damage);
	}

	return Plugin_Continue;
}

public Action Event_InfectedHurt(Handle event, char[] name, bool dontBroadcast)
{
	new client_attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int damage = GetEventInt(event, "amount");

	CalcDamage(0, client_attacker, damage);

	return Plugin_Continue;
}



void CalcDamage(client, client_attacker, damage)
{
	if (!cvar_show_damage.BoolValue || !option_show_damage[client_attacker])
	{
		return;
	}

	if (client_attacker == 0)
	{
		return;
	}

	if (IsFakeClient(client_attacker) || !IsClientInGame(client_attacker))
	{
		return;
	}

	//If client == 0 than skip this verifying. It can be an infected or something else without client index.
	if (client != 0)
	{
		if (client == client_attacker)
		{
			if (!cvar_show_damage_own_dmg.BoolValue)
			{
				return;
			}
		}
		else if (GetClientTeam(client) == GetClientTeam(client_attacker))
		{
			if (!cvar_show_damage_ff.BoolValue)
			{
				return;
			}
		}
	}

	//This is a fix for Left 4 Dead. When tank dies the game fires hurt event with 5000 dmg that is a bug.
	if (damage > MaxDamage)
	{
		return;
	}

	player_damage[client_attacker] += damage;

	if (block_timer[client_attacker])
	{
		return;
	}

	CreateTimer(0.01, ShowDamage, client_attacker);
	block_timer[client_attacker] = true;
}
