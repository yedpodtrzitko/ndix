#define ND_TEAM_CN 2
#define ND_TEAM_EMP 3

stock PrintToChatTeam(iTeam, const String:Message[])
{
	for (new client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client) && GetClientTeam(client) == iTeam)
			PrintToChat(client, Message);
}

stock GetTotalNumPlayers()
{
	new iCount = 0;
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && !IsFakeClient(i)) {
			iCount++;
        }
    }
	return iCount;
}

stock DemoteComm(int team) {
	bool success = false;
	int client = GameRules_GetPropEnt("m_hCommanders", (team-2));
	if (client > -1) {
		FakeClientCommand(client, "rtsview");
		FakeClientCommand(client, "startmutiny");
		ShowActivity2(client, "[NDix] ", "Demoted %N from commander.", client);
		success = true;
	}

	GameRules_SetProp("m_hCommanders", 0, 4, (team-2), true);
	return success;
}
