/*
CNDCommanderElectionMgr::AddCandidate(CNDPlayer *)

AddCandidate is called by
CNDPlayer::ClientCommand(CCommand  const&)

specifically tied to the string: "applyforcommander". It is confirmed on the CNDPlayer's think with:
CNDCommanderElectionMgr::IsPlayerACommanderCandidate(CNDPlayer *)
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ndix>
#include <smlib>

#define NAME "[ND] Commander Sh*t"
#define VERSION "0.2.0"

public Plugin:myinfo =
{
	name = "Comm Sh*t",
	author = "yed_",
	description = "Commander-related functionality (mutiny, restrictions, info)",
	version = VERSION,
	url = "http://ndix.vanyli.net"
}

enum Handles
{
	Handle:HudText,
	Handle:MutinyNeeded
}


new	g_iRankOffset,
	g_iPlayerManager,
	Float:g_iMutinyNeeded;

new g_TeamSize[4] = {0,...};
new g_TeamVotes[4] = {0,...};
new g_VotesNeeded[4] = {0,...};
new bool:g_ClientVoted[MAXPLAYERS+1] = {false, ...};
new teamSittingCommanders[4] = {0,...};

new g_Handle[Handles] = {INVALID_HANDLE, ...};


public OnPluginStart()
{
	CreateConVar("sm_nd_com_shirt_version", VERSION, NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_Handle[MutinyNeeded] = CreateConVar("sm_com_mutiny_needed", "0.4", "Percentage of players needed to demote comm (Def 40%)", 0, true, 0.05, true, 1.0);
	g_iMutinyNeeded = GetConVarFloat(g_Handle[MutinyNeeded]);
	g_iRankOffset = FindSendPropInfo("CNDPlayerResource", "m_iPlayerRank");
	g_Handle[HudText] = CreateHudSynchronizer();

	//AddCommandListener(Command_UnApply, "unapplyforcommander");
	AddCommandListener(Command_Startmutiny,  "startmutiny");

	HookEvent("player_entered_commander_mode",OnCommEntered);
	HookEvent("player_left_commander_mode",OnCommLeft);
	HookEvent("player_team", Event_ChangeTeam, EventHookMode_Pre);

	RegConsoleCmd("sm_mutiny", CMD_Startmutiny);
	RegConsoleCmd("sm_demote", CMD_Startmutiny);
}

public Action:OnCommEntered(Handle:event, const String:name[], bool:dontBroadcast){
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int teamNum = GetClientTeam(client);
	teamSittingCommanders[teamNum] = client;
	return Plugin_Continue;
}

public Action:OnCommLeft(Handle:event, const String:name[], bool:dontBroadcast){
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int teamNum = GetClientTeam(client);
	teamSittingCommanders[teamNum] = -1;
	return Plugin_Continue;
}

public OnMapStart()
{
	g_iPlayerManager = FindEntityByClassname(-1, "nd_player_manager");
	ResetVotes();

	teamSittingCommanders = {0,0,0,0};
}

ResetVotes(int team=0) {
	int iTeam;

	if (team == ND_TEAM_EMP || team == ND_TEAM_CN) {
		g_TeamVotes[team] = 0;
	}
	else
	{
		g_TeamVotes = {0,0,0,0};
	}

	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		iTeam = GetClientTeam(i);
		if (iTeam < 2)
			continue;

		if (!team) {
			g_ClientVoted[i] = false;
		} else if (team == iTeam) {
			g_ClientVoted[i] = false;
		}
	}
}

public Event_ChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int oldteam = GetEventInt(event, "oldteam");
	if (oldteam > 2) {
		int comm = GameRules_GetPropEnt("m_hCommanders", (oldteam-2));
		if (comm == client) {
			DemoteComm(oldteam);
			ResetVotes(oldteam);
		}
	}

	RemoveVote(client);
	RecalculateVotes();
}


public Action:Command_Startmutiny(client, const String:command[], argc)
{
	int rank = GetEntData(g_iPlayerManager, g_iRankOffset + 4*client);
	int team = GetClientTeam(client);
	int comm = GameRules_GetPropEnt("m_hCommanders", (team-2));

	if (rank < 15 && comm != client) {
		PrintToChat(client, "\x04Players with level < 15 cant start mutiny, sorry .(");
		return Plugin_Handled;
	}

	if (teamSittingCommanders[team] == client) {
		FakeClientCommand(client, "rtsview");
	} else {
		AddVote(client);
	}

	return Plugin_Continue;
}

public Action:CMD_Startmutiny(client, args)
{
	if(!IsClientInGame(client) || IsFakeClient(client)) {
		return Plugin_Continue;
	}

	int team = GetClientTeam(client);
	if (team < 2) {
		PrintToChat(client, "low team");
		return Plugin_Continue;
	}

	int commander = GameRules_GetPropEnt("m_hCommanders", (team-2));
	if (commander == -1) {
		PrintToChat(client, "\x04[NDix] There is no commander to demote");
		return Plugin_Continue;
	}

	if (commander == client)
	{
		PrintToChatAll("\x04[NDix] %N has resigned their command, effective immediately!", commander);
		DemoteComm(team);
		ResetVotes(team);
		return Plugin_Continue;
	}

	AddVote(client);
	Action rv = RecalculateVotes();

	char msg[256];
	Format(msg, sizeof(msg), "\x04[NDix] %N voted to demote commander via !demote (%d votes, ~%d required)", client, g_TeamVotes[team], g_VotesNeeded[team]);
	PrintToChatTeam(team, msg);

	return rv;
}

public OnClientDisconnect(client)
{
	if(!IsClientInGame(client) || IsFakeClient(client))
		return;

	RemoveVote(client);
	RecalculateVotes();
}

AddVote(client) {
	g_ClientVoted[client] = true;
}

RemoveVote(client) {
	g_ClientVoted[client] = false;
}


Action:RecalculateVotes(bool:check=true) {
	int team = 0;
	g_TeamSize = {0,0,0,0};
	g_TeamVotes = {0,0,0,0};

	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		team = GetClientTeam(i);
		if (team < 2)
			continue;

		g_TeamSize[team]++;
		if (g_ClientVoted[i])
			g_TeamVotes[team]++;
	}

	for (int x=2; x<=3; x++) {
		g_VotesNeeded[x] = RoundToCeil(float(g_TeamSize[x]) * g_iMutinyNeeded);
	}

	if (check) {
		return CheckMutiny();
	}
	return Plugin_Continue;
}

Action:CheckMutiny() {
	for (int team=2; team<=3; team++)
	{
		if (g_TeamVotes[team] && g_TeamVotes[team] >= g_VotesNeeded[team]) {
			DemoteComm(team);
			ResetVotes(team);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}


public RefreshCvars(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (cvar == g_Handle[MutinyNeeded]) {
		g_iMutinyNeeded = GetConVarFloat(g_Handle[MutinyNeeded]);
	}
}
