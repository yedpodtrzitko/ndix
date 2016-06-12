#define ND_TEAM_SPEC 1
#define ND_TEAM_CN 2
#define ND_TEAM_EMP 3
#define SERVER_NAME "phoenix"
#define SERVER_NAME_TAG "[phoenix] "

stock void PrintToChatTeam(iTeam, char[] message)
{
	for (new client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client) && GetClientTeam(client) == iTeam)
			PrintToChat(client, message);
}

stock int GetTotalNumPlayers()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && !IsFakeClient(i)) {
			iCount++;
        }
    }
	return iCount;
}

stock bool DemoteComm(int team) {
	bool success = false;
	int client = GameRules_GetPropEnt("m_hCommanders", (team-2));
	if (client > -1) {
		FakeClientCommand(client, "rtsview");
		FakeClientCommand(client, "startmutiny");
		ShowActivity2(client, SERVER_NAME_TAG, "Demoted %N from commander.", client);
		success = true;
	}

	GameRules_SetProp("m_hCommanders", 0, 4, (team-2), true);
	return success;
}
