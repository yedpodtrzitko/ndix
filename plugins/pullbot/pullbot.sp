#include <sourcemod>
#include <sdktools>
#include <smlib>

float fMaxDistance = 300.0;
float coords[MAXPLAYERS+1][2];
float fMaxBunkerDistance = 1500.0;

float bunkers[4][3];

public Plugin myinfo =
{
    name = "Pull Bot",
    author = "yed",
    description = "pull bot where you need it",
    version = "0.1",
    url = "https://github.com/yedpodtrzitko/ndix"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_pull", Command_pull);

    //CreateTimer(1.0, RoundStart);
    //RoundStart();
}

//public Action RoundStart(Handle e, const char[] name, bool broadcast) {
//public Action RoundStart(Handle timer) {
public void OnMapStart() {
    int  ent;
    int teamNum;
    float p[3];

    for (int i=0; i<4; i++) {
        bunkers[i][0] = 0.0;//= {0.0, 0.0};
        bunkers[i][1] = 0.0;// {0.0, 0.0};
        bunkers[i][2] = 0.0;// {0.0, 0.0};
    }

    while ((ent = FindEntityByClassname(ent, "struct_command_bunker")) != -1)
    {
        teamNum = GetEntProp(ent, Prop_Send, "m_iTeamNum");
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", p);
        bunkers[teamNum][0] = p[0];
        bunkers[teamNum][1] = p[1];
    }

    LOOP_CLIENTS(client, CLIENTFILTER_BOTS) {
        GetClientEyePosition(client, p);
        coords[client][0] = p[0];
        coords[client][1] = p[1];
    }

    CreateTimer(8.0, Timer_CheckBots, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

}


public Action Timer_CheckBots(Handle timer, any data) {
    // unstuck bots spawned midground
    float p[3];
    int team;
    LOOP_CLIENTS(client, CLIENTFILTER_BOTS|CLIENTFILTER_ALIVE) {
        GetClientEyePosition(client, p);
        if (coords[client][0] == p[0] && coords[client][1] == p[1]) {
            p[2] += 20.0;

            team = GetClientTeam(client);
            if (GetVectorDistance(p, bunkers[team]) < fMaxBunkerDistance) {
                TeleportEntity(client, p, NULL_VECTOR, NULL_VECTOR);
            }
        }
        coords[client][0] = p[0];
        coords[client][1] = p[1];
    }

    return Plugin_Continue;
}


public Action Command_pull(client, args)
{
    if(!IsValidClient(client)) {
        return Plugin_Handled;
    }

    float vecAngles[3];
    float vecOrigin[3];
    float vecPos[3];
    GetClientEyePosition(client, vecOrigin);
    GetClientEyeAngles(client, vecAngles);

    Handle hTrace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    if(TR_DidHit(hTrace)) {
        //This is the first function i ever saw that anything comes before the handle
        TR_GetEndPosition(vecPos, hTrace);
        int target = TR_GetEntityIndex(hTrace);
        if (target > 0) {
            if (IsFakeClient(target)) {
                if(GetVectorDistance(vecOrigin, vecPos) < fMaxDistance) {
                    TeleportEntity(target, vecOrigin, NULL_VECTOR, NULL_VECTOR);
                    PrintToChat(client, "bot moved");
                } else {
                    PrintToChat(client, "bot too far");
                }
            }
        }
    }
    CloseHandle(hTrace);
    return Plugin_Handled;
}


bool IsValidClient(client) {
	if(client <= 0)
		return false;
	if(client > MaxClients)
		return false;

	return IsClientInGame(client);
}


public bool TraceEntityFilterPlayer(entity, contentsMask) {
 	return entity < MaxClients && IsFakeClient(entity);
}