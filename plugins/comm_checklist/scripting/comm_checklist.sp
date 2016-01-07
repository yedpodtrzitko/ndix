#include <sourcemod>
#include <sdktools>

#define COMM_CHECKLIST_VERSION 	"2.7"
#define MAX_TEAMS 	            4
#define CHECKLIST_ITEM_COUNT    5
#define DEBUG					0

//new Handle:g_enabled = INVALID_HANDLE;
Handle g_maxlevel = INVALID_HANDLE;
Handle g_version = INVALID_HANDLE;
Handle g_cVar_hidedone = INVALID_HANDLE;
Handle hudSync;
new String:checklistTasks[CHECKLIST_ITEM_COUNT][25] = {"BUILD_FWD_SPAWN","RESEARCH_TACTICS","BUILD_ARMORY","RESEARCH_KITS","CHAT_MSG"};
int PlayerManager;
int i_maxlevel;

//Commander checklists for each team. Each checklist has one extra field, for 
//marking whether the comm has seen the thankyou msg after completing all tasks.
bool teamChecklists[MAX_TEAMS][CHECKLIST_ITEM_COUNT+1];

//This is mainly for knowing whether the comms are in their chairs,
//so we can only display the checklist when they're in the chair
int teamSittingCommanders[MAX_TEAMS];
bool g_hidedone;

public Plugin:myinfo =
{
	name = "ND Commander Checklist",
	author = "jddunlap",
	description = "Shows a commander checklist for new commanders",
	version = COMM_CHECKLIST_VERSION,
	url = "http://ndix.vanyli.net"
};


public OnPluginStart()
{	
	//con vars
	//g_enabled = CreateConVar("sm_comm_checklist_enabled","1");
	//show it for everyone for now to get some feedback
	g_maxlevel = CreateConVar("sm_comm_checklist_maxlevel","80");
	g_version = CreateConVar("sm_comm_checklist_version", COMM_CHECKLIST_VERSION);
	g_cVar_hidedone = CreateConVar("sm_comm_checklist_hide_done", "1");
	g_hidedone = GetConVarBool(g_cVar_hidedone);

	SetConVarString(g_version, COMM_CHECKLIST_VERSION);

	i_maxlevel = GetConVarInt(g_maxlevel);

	//basic init
	LoadTranslations ("sm_comm_checklist.phrases");
	hudSync = CreateHudSynchronizer();

	//events
	//for showing/hiding HUD
	HookEvent("player_entered_commander_mode",OnCommEntered);
	HookEvent("player_left_commander_mode",OnCommLeft);
	//For updating HUD when field tactics and kits are researched
	HookEvent("research_complete",OnResearchCompleted);
	//For updating HUD when armory is built
	HookEvent("commander_start_structure_build",OnStructureBuildStarted);
	//For updating HUD when a forward spawn is built
	HookEvent("transport_gate_created",OnForwardSpawnCreated);
	//For updating HUD when the comm activate chat
	HookEvent("player_say", OnPlayerChat, EventHookMode_Post);

	//con var events
	//HookConVarChange(g_enabled, CvarChange_Enabled);
	//HookConVarChange(g_maxlevel, CvarChange_MaxLevel);
}

public OnMapStart(){
	//init task arrays
	for (int idx = 2; idx < MAX_TEAMS; idx++){
		teamSittingCommanders[idx] = -1;
		for(int idx2 = 0; idx2 < CHECKLIST_ITEM_COUNT+1; idx2++) {
			teamChecklists[idx][idx2]=false;
		}
	}

	PlayerManager = FindEntityByClassname(-1, "nd_player_manager");
}

/*
//TODO
public CvarChange_Enabled(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if (StringToInt(newvalue) == 0){
	
	} else{

	}
}

//TODO
public CvarChange_MaxLevel(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	
}
*/

public Action:OnPlayerChat(Handle event, const String:name[], bool dontBroadcast){
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client) {
		return Plugin_Continue;
	}

	int teamId = GetClientTeam(client);
	#if DEBUG == 1
		PrintToServer("hooked chat, team %d, client %d, comm %d", teamId, client, teamSittingCommanders[teamId]);
	#endif

	if (teamSittingCommanders[teamId] == client) {
		teamChecklists[teamId][4] = true;
		UpdateCommHud(GetClientTeam(client));
	}

	return Plugin_Continue;
}

public Action:OnStructureBuildStarted(Handle:event, const String:name[], bool:dontBroadcast){
	new structType = GetEventInt(event, "type");
	new teamId = GetEventInt(event, "team");

	#if DEBUG == 1
		PrintToChatAll("Structure build started for team %d: %d", teamId, structType);
	#endif

	//Armory
	if(structType == 8 && !teamChecklists[teamId][2]) {
		teamChecklists[teamId][2] = true;
		UpdateCommHud(teamId);
	}
	return Plugin_Continue;
}

//structure_built and forward_spawn_created do not fire serverside. 
//transport_gate_created fires serverside but before the entity has an origin -
//so we set a timer for the entity and do our checks there.
public Action:OnForwardSpawnCreated(Handle:event, const String:name[], bool:dontBroadcast){
	//new teamId = GetEventInt(event, "teamid");
	new entIdx = GetEventInt(event, "entindex");

	//PrintToChatAll("Forward spawn created for team %d", teamId);
	CreateTimer(1.0, TransportGateTimerCB, entIdx, TIMER_REPEAT);
	return Plugin_Continue;
}

public Action:TransportGateTimerCB(Handle:timer, any:entIdx)
{
	if (entIdx < 1) {
		return Plugin_Stop;
	}
	new teamId = GetEntProp(entIdx, Prop_Send, "m_iTeamNum");

	#if DEBUG == 1
		PrintToChatAll("Forward spawn timer for entity %d and team %d", entIdx, teamId);
	#endif

	if(!teamChecklists[teamId][0]) {
		new Float:pos[3];
		GetEntPropVector(entIdx, Prop_Send, "m_vecOrigin", pos);

		if(pos[0] == 0.0 && pos[1] == 0.0 && pos[2] == 0.0){
			//PrintToChatAll("%d not ready yet", entIdx);
			return Plugin_Continue;
		}

		new friendlyBunker;
		new otherBunker;

		new ent;
		while ((ent = FindEntityByClassname(ent, "struct_command_bunker")) != -1)
		{
			new teamNum = GetEntProp(ent, Prop_Send, "m_iTeamNum");
			if(teamNum == teamId) {
				friendlyBunker = ent;
				//PrintToChatAll("Found friendly bunker");
			} else {
				otherBunker = ent;
				//PrintToChatAll("Found other bunker: %d", teamNum);
			}
		}

		new Float:friendlyBunkerPos[3];
		GetEntPropVector(friendlyBunker, Prop_Send, "m_vecOrigin", friendlyBunkerPos);
		new Float:otherBunkerPos[3];
		GetEntPropVector(otherBunker, Prop_Send, "m_vecOrigin", otherBunkerPos);

		new Float:linePt[3];
		friendlyBunkerPos[2]=0.0;
		otherBunkerPos[2]=0.0;
		pos[2]=0.0;
		pointOn2dLine(friendlyBunkerPos, otherBunkerPos, pos, linePt);
		linePt[2]=0.0;
		new Float:percentAcrossMap = percentageAlongLine(friendlyBunkerPos, otherBunkerPos, linePt);



		/*PrintToChatAll(
			"entindex(%d) Positions: (%f,%f,%f) (%f,%f,%f) (%f,%f,%f) (%f,%f,%f) - [%f,%f]", 
			entIdx,
			friendlyBunkerPos[0],friendlyBunkerPos[1],friendlyBunkerPos[2],
			otherBunkerPos[0],otherBunkerPos[1],otherBunkerPos[2],
			pos[0],pos[1],pos[2],
			linePt[0],linePt[1],linePt[2],
			distanceBetweenPts(friendlyBunkerPos, pos),
			distanceBetweenPts(friendlyBunkerPos, linePt)
		);
		PrintToChatAll("Forward spawn is %f percent across the map", percentAcrossMap);
		*/

		if(percentAcrossMap >= 0.20){
			teamChecklists[teamId][0] = true;
			UpdateCommHud(teamId);
		}
	}
  	return Plugin_Stop;
}  


public Action:OnResearchCompleted(Handle:event, const String:name[], bool:dontBroadcast){
	
	new researchId = GetEventInt(event, "researchid");
	new teamId = GetEventInt(event, "teamid");

	//PrintToChatAll("Research completed for team %d: %d", teamId, researchId);

	//Advanced Kits = 1
	if(researchId == 1){
		teamChecklists[teamId][3] = true;
		UpdateCommHud(teamId);
	}

	//Field Tactics = 2
	if(researchId == 2){
		teamChecklists[teamId][1] = true;
		UpdateCommHud(teamId);
	}

	return Plugin_Continue;
}

public Action:OnCommEntered(Handle:event, const String:name[], bool:dontBroadcast){
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//PrintToChatAll("Player %N entered comm mode", client);
	new teamNum = GetClientTeam(client);
	teamSittingCommanders[teamNum] = client;
	UpdateCommHud(GetClientTeam(client));
	return Plugin_Continue;
}

public Action:OnCommLeft(Handle:event, const String:name[], bool:dontBroadcast){
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//PrintToChatAll("Player %N left comm mode", client);
	new teamNum = GetClientTeam(client);
	teamSittingCommanders[teamNum] = -1;
	UpdateCommHud(GetClientTeam(client));
	return Plugin_Continue;
}

//Updates the commander hud for the specified team.
//Shows or clears hud depending on whether comm is in
//chair and whether he has finished his tasks.
public UpdateCommHud(team){
	#if DEBUG == 1
		PrintToServer("Update Hud for team: %d", team);
	#endif
	new commander = GameRules_GetPropEnt("m_hCommanders", team-2);

	// comm is in the chair
	if(commander != -1 && commander == teamSittingCommanders[team]) {

		#if DEBUG == 1
			PrintToServer("Comm for team %d is: %N", team, commander);
		#endif

		new rank = GetEntProp(PlayerManager, Prop_Send, "m_iPlayerRank", 1, commander);
		if (rank > i_maxlevel) {
			return;
		}

		if(!teamChecklists[team][CHECKLIST_ITEM_COUNT]){
			new String: message[256]; 
			Format(message, sizeof(message), "%T\n", "COMMANDER_CHECKLIST", LANG_SERVER, commander);

			new checkedItemCount=0;
			for (new idx = 0; idx < CHECKLIST_ITEM_COUNT; idx++){
				new String:state[2];
				if(teamChecklists[team][idx]){
					state="✔";
					checkedItemCount++;
				} else {
					state="✘";
				}
				decl String:task[25];
				task = checklistTasks[idx];
				if (!(teamChecklists[team][idx] && g_hidedone)) {
					Format(message, sizeof(message), "%s%s %T\n", message, state, task, LANG_SERVER, commander);
				}
			}

			if(checkedItemCount >= CHECKLIST_ITEM_COUNT){
				Format(message, sizeof(message), "%T", "COMM_THANKS", LANG_SERVER, commander);
				Format(message, sizeof(message), "%s\n%T", message, "COMM_SUPPORTTROOPS", LANG_SERVER, commander);
				SetHudTextParams(1.0, 0.2,    5.0,    0, 128, 0, 80);
				teamChecklists[team][CHECKLIST_ITEM_COUNT] = true;
			} else {
				SetHudTextParams(1.0, 0.1,    99999.0,    255, 255, 80, 80);
			}
			ShowSyncHudText(commander, hudSync, message);
		}
	} else if(commander != -1) {
		SetHudTextParams(1.0, 0.1,    99999.0,    255, 255, 80, 80);
		ShowSyncHudText(commander, hudSync, "");
	}
}

//returns the percentage of the distance pt falls at on the line from pt1 to pt2
public Float:percentageAlongLine(Float:pt1[3], Float:pt2[3], Float:pt[3]){
	//(new Vector2D(pt.X, pt.Y)-pt1).Length / (pt2 - pt1).Length

	/*new Float:v1[3];
	SubtractVectors(pt, pt1, v1);

	new Float:v2[3];
	SubtractVectors(pt2,pt1, v2);

	new Float:l2 = GetVectorLength(v2);
	if(l2 == 0.0){
		return 0.0;
	} else {
		return GetVectorLength(v1) / l2;
	}*/

	return distanceBetweenPts(pt1,pt)/distanceBetweenPts(pt1,pt2);
}

//gets the distance in game units between the specified points
public Float:distanceBetweenPts(Float:pt1[3], Float:pt2[3]){
	return SquareRoot(Pow(pt1[0]-pt2[0],2.0) + Pow(pt1[1]-pt2[1],2.0) + Pow(pt1[2]-pt2[2],2.0));
}

//Projects the point specified by toProject onto the line specified by line1 and line2.
//Returns the projected point in result. Accepts 3D points for convenience, but only
//uses the x and y dimensions.
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
