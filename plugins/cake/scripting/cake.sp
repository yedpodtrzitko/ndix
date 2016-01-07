/*
    Spawning a cake on a map
    The code is very ugly, but I wanted to have it done ASAP

    0.2     - cakes dissapear on plugin restart

    0.1     initial version

*/


#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <loghelper>


#define PLUGIN_VERSION "0.3.0"
#define DEBUG 0

enum Bools {
    Enabled,
};

enum Handles {
    Handle:Enabled,
};

new g_Handle[Handles] = {INVALID_HANDLE},
    bool:g_Bools[Bools];

Handle CAKES = INVALID_HANDLE;


public Plugin:myinfo = {
    name = "Cake",
    author = "yed_",
    description = "The cake is NOT a lie",
    version = PLUGIN_VERSION,
    url = "http://ndix.vanyli.net"
}

public OnPluginStart() {
    CreateConVar("sm_cake_version", PLUGIN_VERSION, "ND Offmap Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    g_Handle[Enabled] = CreateConVar("sm_cake_enabled", "1", "Flag to (de)activate the plugin");
    g_Bools[Enabled] = GetConVarBool(g_Handle[Enabled]);
    HookConVarChange(g_Handle[Enabled], OnCVarChange);

    CAKES = CreateArray(1);

    RegAdminCmd("sm_cake", CMD_Cake, ADMFLAG_BAN);

    HookEvent("round_start", GameStart);
}

public OnMapStart() {
    if (!g_Bools[Enabled]) {
        return;
    }

    AddFileToDownloadsTable("materials/models/cakehat/cakehat.vmt");
    AddFileToDownloadsTable("materials/models/cakehat/cakehat.vtf");
    AddFileToDownloadsTable("materials/models/cakehat/cakehat_exp.vtf");
    AddFileToDownloadsTable("materials/models/cakehat/cakehat_n.vtf");
    AddFileToDownloadsTable("models/cakehat/cakehat.phy");
    AddFileToDownloadsTable("models/cakehat/cakehat.vvd");
    AddFileToDownloadsTable("models/cakehat/cakehat.dx80.vtx");
    AddFileToDownloadsTable("models/cakehat/cakehat.dx90.vtx");
    AddFileToDownloadsTable("models/cakehat/cakehat.sw.vtx");
    AddFileToDownloadsTable("models/cakehat/cakehat.mdl");

    PrecacheModel("models/cakehat/cakehat.mdl", true);
}

public OnPluginEnd() {
    int cakes_count = GetArraySize(CAKES);
    int ck;
    for (int i=0; i<cakes_count; i++) {
        ck = GetArrayCell(CAKES, i);
        RemoveCake(ck);
    }
}

public Action:GameStart(Handle e, const char[] Name, bool Broadcast) {
    char map[32];
    GetCurrentMap(map, sizeof(map));

    if (StrEqual(map, "silo")) {
        HandleSilo();
    } else if (StrEqual(map, "downtown")) {
        HandleDowntown();
    }
    return Plugin_Continue;
}


HandleSilo() {
    //prime
    SpawnCake(-2219.927978, -1061.624267, 0.0013);
}


HandleDowntown() {
    //prime
    SpawnCake(269.344451, -23.040763, -3909.244140);
}



public Action:CMD_Cake(client, args) {
    if (!g_Bools[Enabled]) {
        return Plugin_Handled;
    }

    if(!client || !IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }

    float vOrigin[3];
    float vAngles[3];
    float vBackwards[3];
    float pos[3];

    GetClientEyePosition(client, vOrigin);
    GetClientEyeAngles(client, vAngles);
    GetAngleVectors(vAngles, vBackwards, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(vBackwards, vBackwards);
    ScaleVector(vBackwards, 10.0);

    Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

    if (TR_DidHit(trace)) {
        TR_GetEndPosition(pos, trace);
        SpawnCake(pos[0], pos[1], pos[2]);
    }

    return Plugin_Handled;
}

SpawnCake(float x, float y, float z) {
    int cake = CreateEntityByName("prop_dynamic_override");
    float pos[3];
    pos[0] = x;
    pos[1] = y;
    pos[2] = z;
    //SetEntityModel(cake, "models/cakehat/cakehat.mdl");
    DispatchKeyValue(cake, "model",  "models/cakehat/cakehat.mdl");
    DispatchKeyValue(cake, "solid", "6");
    //AcceptEntityInput(cake, "Enable");

    DispatchSpawn(cake);
    TeleportEntity(cake, pos, NULL_VECTOR, NULL_VECTOR);

    PrintToServer("cake spawned at %f %f %f", x,y,z);

    PushArrayCell(CAKES, cake);

    SDKHook(cake, SDKHook_Touch, CakeCollected);
}


public Action:CakeCollected(entity, client) {
    if (client && client <= MaxClients) {
        if(IsValidEntity(entity)) {
            PrintToChatAll("\x04%N found & ate a cake, yummy!", client);
            LogPlayerEvent(client, "triggered", "cake_collected");

            float position[3];
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);

            RemoveCake(entity);
        }
    }

    return Plugin_Continue;
}

RemoveCake(entity) {
    int cake_idx = FindValueInArray(CAKES, entity);
    RemoveFromArray(CAKES, cake_idx);
    RemoveEdict(entity);
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
    return entity <= 0 || entity > MaxClients;
}

public OnCVarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	GetCVars();
}

GetCVars()
{
	g_Bools[Enabled] = GetConVarBool(g_Handle[Enabled]);
}
