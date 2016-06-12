/*
    A rough fix for building outside of the map (Hydro, Gate, Coast...)

    0.2     more glitches fix (thx Phi)
            using dynamic array
            reversed coordinates

    0.1     initial version

*/


#include <sourcemod>
#include <sdkhooks>
#include <ndix>

#define PLUGIN_VERSION "0.2.1"
#define DEBUG 0

bool validMap = false;

Handle HAX = INVALID_HANDLE;

new tmpAxisCount;
new tmpAxisViolated;

public Plugin:myinfo = {
    name = "Off the map buildings",
    author = "yed_",
    description = "Prevents exploting the invalid map borders",
    version = PLUGIN_VERSION,
    url = "https://github.com/yedpodtrzitko/ndix"
}

public OnPluginStart() {
    //h_Enabled =CreateConVar("sm_nd_preventsell_enabled", "1", "Flag to (de)activate the plugin");
    CreateConVar("sm_nd_offmap_version", PLUGIN_VERSION, "ND Offmap Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
    HAX = CreateArray(4);

}

public OnMapStart() {
    char map[32];
    GetCurrentMap(map, sizeof(map));

    ClearArray(HAX);
    if (StrEqual(map, "hydro")) {
        HandleHydro();
    } else if (StrEqual(map, "coast")) {
        HandleCoast();
    } else if (StrEqual(map, "gate")) {
        HandleGate();
    } else if (StrEqual(map, "metro")) {
        HandleMetro();
    }

    if (GetArraySize(HAX)) {
        validMap = true;
        PrintToChatAll("\x04%s handling %d location(s) glitches", SERVER_NAME_TAG, GetArraySize(HAX));
    } else {
        validMap = false;
    }
}

public OnMapEnd() {
    validMap = false;
}

HandleMetro() {
    /*
    this one disable structures inside the buildings clos to Emp base

    1. 2539.226562 679.451477
    2. 2424.608154 685.783752
    3. 2416.049072 855.316040

    3
    |
    2--1

    x 2420+
    y 680+
    */
    float hax[4] = {0.0, ...};
    hax[0] = 2420.0; //minX
    hax[2] = 680.0; //minY
    PushArrayArray(HAX, hax);

}

HandleGate() {
    /*
    +
    y
    - x +

    this one handles the spot close to prime

    a - 3668.344726 1132.599365 0.000000
    b - 4004.024658 1103.116699 154.177978
    c - 4627.127929 1161.775512 -63.968750
    d - 4634.593750 944.216247 -63.968750

       |
      d|
      cba
       |
       |
    */
    float hax[4] = {0.0, ...};
    hax[0] = 4000.0; //minX
    PushArrayArray(HAX, hax);
}

HandleHydro() {
    /*
    -
    y
    + x -

    this one disable building from east secondary to Cons base

    */

    float hax[4] = {
        0.0,
        -7000.0,    //maxX
        0.0,
        -1000.0     //maxY
    };
    PushArrayArray(HAX, hax);
}

HandleCoast() {
    /*
    - y +
    x
    +

    roof
    x - 5246.656250 52.499198 1615.631225
    w - 5247.633300 -726.002502 1615.631225
    v - 4465.646484 49.810642 1615.631225

    -----v
         |
    w----x
    */

    float hax[4] = {0.0, ...};
    hax[0] = 4466.0;    // minX
    hax[1] = 5246.0;    // maxX
    hax[2] = 0.0;       // minY
    hax[3] = 52.0;      // maxY
    PushArrayArray(HAX, hax);

    /*
    east secondary
    b - 5217.833984 6646.136230 95.915893
    c - 3518.860351 6597.848144 49.899757

     c ------
     |
     |
     b ------

    - y +
    x
    +
    */

    hax[0] = 3518.0;    // minX
    hax[1] = 5217.0;    // maxX
    hax[2] = 6597.0;    // minY
    hax[3] = 0.0;       // maxY
    PushArrayArray(HAX, hax);


    /*
    emp base
    a - -1387.745727 2051.673828 170.077255
    b - -1392.122802 2760.031250 170.304748
    e - -2549.040283 2597.857910 175.847381


    c----d
    |
    |    e
    a----b



    emp west

    a - -1463.773193 -970.887390 46.073951
    b - -3507.321044 1041.086181 38.291664
    c - -3531.877929 2639.884765 182.022720
    d - -3965.543945 2648.903564 170.077255


                  d
                  |
         b--------c
        /
       /
      /
    a

    new Float:hax[4] = {0.0, ...};
    hax[1] = 0.0;       // maxX
    hax[0] = -7000.0;   // minX
    hax[3] = 0.0;       // maxY
    hax[2] = -1000.0;   // minY

    */

}

public OnEntityCreated(entity, const String:classname[]){
    if (!validMap) {
        return;
    }

    if (strncmp(classname, "struct_", 7) == 0) {
        CreateTimer(0.1, CheckBorders, entity);
        //SDKHook(entity, SDKHook_SpawnPost, CheckBorders);
    }
}

public Action CheckBorders(Handle timer, any entity) {
    float position[3];
    GetEntPropVector(entity, Prop_Data, "m_vecOrigin", position);
    //PrintToChatAll("placed location %f - %f - %f", position[0], position[1], position[2]);
    float hax[4];
    for (new i=0; i<GetArraySize(HAX); i++) {
        tmpAxisCount = 0;
        tmpAxisViolated = 0;

        // minX
        GetArrayArray(HAX, i, hax);
        if (hax[0] != 0.0) {
            tmpAxisCount++;
            if (hax[0] < position[0]) {
                tmpAxisViolated++;
            }
        }

        // maxX
        if (hax[1] != 0.0) {
            tmpAxisCount++;
            #if DEBUG == 1
                PrintToChatAll("checking max X hax %f > pos %f?", hax[1], position[0]);
            #endif

            if (hax[1] > position[0]) {
                tmpAxisViolated++;
            }
        }

        if (hax[2] != 0.0) {
            tmpAxisCount++;
            if (hax[2] < position[1]) {
                tmpAxisViolated++;
            }
        }

        if (hax[3] != 0.0) {
            tmpAxisCount++;
            if (hax[3] > position[1]) {
                tmpAxisViolated++;
            }
        }

        if (tmpAxisViolated && (tmpAxisCount == tmpAxisViolated)) {
            SDKHooks_TakeDamage(entity, entity, entity, 5001.0, DMG_SLASH, -1, position, position);
        }
    }
}
