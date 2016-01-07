#include <sourcemod>
#include <sdktools>
#include <ndix>

#define PLUGIN_VERSION "0.1.0"
#define DEBUG 0

public Plugin:myinfo =
{
	name = "Surrender",
	author = "yed_",
	description = "Another way how to surrender",
	version = PLUGIN_VERSION,
	url = "git@vanyli.net:nd-plugins"
};

new Handle:g_Cvar_Needed = INVALID_HANDLE;
new Handle:g_Cvar_MinPlayers = INVALID_HANDLE;
new Handle:g_Cvar_InitialDelay = INVALID_HANDLE;

new bool:g_CanSurrender = false;		// True if Surrender loaded maps and is active.
new bool:g_SurrenderAllowed = false;	// True if Surrender is available to players. Used to delay surrender votes.
new g_TeamSize[4] = {0,...};				// Total voters connected. Doesn't include fake clients.
new g_TeamVotes[4] = {0,...};				// Total number of "say surrender" votes
new g_VotesNeeded[4] = {0,...};
new bool:g_ClientVoted[MAXPLAYERS+1] = {false, ...};
new Float:g_iVotesNeeded;

public OnPluginStart()
{
	g_Cvar_Needed = CreateConVar("sm_surrender_needed", "0.60", "Percentage of players needed to surrender (Def 60%)", 0, true, 0.05, true, 1.0);
	g_Cvar_MinPlayers = CreateConVar("sm_surrender_minplayers", "0", "Number of players required before Surrender will be enabled.", 0, true, 0.0, true, float(MAXPLAYERS));
	g_Cvar_InitialDelay = CreateConVar("sm_surrender_initialdelay", "300.0", "Time (in seconds) before surrender can be used", 0, true, 0.00);
	g_iVotesNeeded = GetConVarFloat(g_Cvar_Needed);

	RegConsoleCmd("sm_surrender", Command_Surrender);

	HookEvent("player_team", Event_ChangeTeam);

	AutoExecConfig(true, "surrender");

	ResetSurrender();
}

public OnMapStart()
{
	ResetSurrender();
}

public OnMapEnd()
{
	g_CanSurrender = false;	
	g_SurrenderAllowed = false;
}

public Action:Timer_DelaySurrender(Handle:timer)
{
	g_SurrenderAllowed = true;
}

public OnConfigsExecuted()
{	
	g_CanSurrender = true;
	g_SurrenderAllowed = false;
	CreateTimer(GetConVarFloat(g_Cvar_InitialDelay), Timer_DelaySurrender, _, TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientDisconnect(client)
{
	if(!client || IsFakeClient(client))
		return;

	RemoveVote(client);
	RecalculateVotes();
}

public Action:Event_ChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new user = GetEventInt(event, "userid")
	new client = GetClientOfUserId(user);
	if(!IsClientInGame(client) || IsFakeClient(client))
		return;

	RemoveVote(client);
	RecalculateVotes();
}


RecalculateVotes(bool:check=true) {
	new team = 0;
	g_TeamSize = {0,0,0,0};
	g_TeamVotes = {0,0,0,0};

	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		team = GetClientTeam(i);
		if (team < 2)
			continue;

		g_TeamSize[team]++;
		if (g_ClientVoted[i]) {
			g_TeamVotes[team]++;
		}
	}

	for (team=2; team<=3; team++) {
		g_VotesNeeded[team] = RoundToCeil(float(g_TeamSize[team]) * g_iVotesNeeded);
	}

	if (check) {
		CheckSurrender();
	}
}

CheckSurrender() {
	for (new xteam=2; xteam<=3; xteam++)
	{
		if (g_TeamVotes[xteam] > 1 && g_TeamVotes[xteam] >= g_VotesNeeded[xteam]) {
			new String:loser[32] = "Empire";
			if (xteam == 2) {
				loser = "Consortium";
			}
			for (new repeat=0; repeat<2; repeat++){
				PrintToChatAll("\x05HEAR THE NEWS! %s has surrendered!", loser);
			}

			CreateTimer(3.0, DoSurrender, xteam, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Command_Surrender(client, args)
{
	if (!g_CanSurrender || !IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] Surrender not allowed");
		//return Plugin_Handled;
	}

	if (!g_SurrenderAllowed)
	{
		ReplyToCommand(client, "[SM] Surrender not allowed yet");
		//return Plugin_Handled;
	}

	if (GetClientCount(true) < GetConVarInt(g_Cvar_MinPlayers))
	{
		ReplyToCommand(client, "[SM] Minimal Players Not Met");
		//return Plugin_Handled;
	}

	new team = GetClientTeam(client);
	if (g_ClientVoted[client]) {
		ReplyToCommand(client, "[SM] You have already voted to surrender via !surrender (%d votes, ~%d required)", g_TeamVotes[team], g_VotesNeeded[team]);
		return Plugin_Handled;
	}

	AddVote(client);
	RecalculateVotes(false);

	new String:msg[256];
	Format(msg, sizeof(msg), "\x03[SM] %N voted to surrender via !surrender (%d votes, ~%d required)", client, g_TeamVotes[team], g_VotesNeeded[team]);
	PrintToChatTeam(team, msg);

	CheckSurrender();

	return Plugin_Handled;
}


AddVote(client) {
	g_ClientVoted[client] = true;
}

RemoveVote(client) {
	g_ClientVoted[client] = false;
}

ResetSurrender()
{
	g_TeamSize = {0,0,0,0};
	for (new i=0; i<=MAXPLAYERS; i++) {
		g_ClientVoted[i] = false;
	}
	g_TeamVotes[2] = 0;
	g_TeamVotes[3] = 0;
	g_VotesNeeded = {0,0,0,0};

}

public Action:Timer_ChangeMap(Handle:hTimer)
{

	LogMessage("Surrender changing map manually");
	
	new String:map[65];
	if (GetNextMap(map, sizeof(map)))
	{	
		ForceChangeLevel(map, "Surrender after mapvote");
	}
	
	return Plugin_Stop;
}

public Action:DoSurrender(Handle:Timer, any:team)
{
	new ent = FindEntityByClassname(-1, "nd_logic_custom"),
		Handle:event = CreateEvent("round_win");

	if (ent == -1)
	{
		ent = CreateEntityByName("nd_logic_custom");
		DispatchSpawn(ent);
	}

	SetEventInt(event, "type", 3);
	SetEventInt(event, "team", (5 - team));

	AcceptEntityInput(ent, "EndRoundAuto");
	FireEvent(event);

	return Plugin_Continue;
}
