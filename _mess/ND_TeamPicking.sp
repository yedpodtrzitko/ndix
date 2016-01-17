#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "ND_TeamPicking",
	author = "ND Battle Coders",
	description = "Lets the two selected commanders pick their team",
	version = "1.0",
	url = "<- URL ->"
}

//new consorList[MAXPLAYERS];
//new empireList[MAXPLAYERS];
new last_emp_choice = 0;
new last_con_choice = 0;
new g_hEnabled = 0;
new cur_team_choosing;
new comm_con;
new comm_emp;

public OnPluginStart() {
	LoadTranslations("common.phrases");
	RegConsoleCmd("PlayerPicking",StartPicking);
	RegConsoleCmd("pnum",PNum);
	RegConsoleCmd("EnableTeamChg",EnableTeamChg);
	AddCommandListener(Command_JoinTeam, "jointeam");
}

public Action:PNum(client,args) {
	Menu_PlayerPick(client,2);
}

public Action:EnableTeamChg(client,args) {
	new String:stat_str[10];
	GetCmdArg(1, stat_str, sizeof(stat_str));
	g_hEnabled= StringToInt(stat_str);
	if (g_hEnabled == 1) {
		PrintToChatAll("Team Changing is now disabled");
	} else {
		PrintToChatAll("Team Changing is now allowed");
	}
}


public Action:Command_JoinTeam(client, String:command[], argc) {
	if (g_hEnabled==0) {
		return Plugin_Continue;
	} else {
		return Plugin_Handled;
	}
}

public Action:StartPicking(client,args) {
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: PlayerPicking <Consortium Name|#Userid|SteamID> <Empire Name|#Userid|SteamID>");
		return Plugin_Handled;
	}
	g_hEnabled=1
	decl String:con_name[64]
	decl String:emp_name[64]
	GetCmdArg(1, con_name, sizeof(con_name));
	GetCmdArg(2, emp_name, sizeof(emp_name));
	new target;	
	if (StrContains(con_name, "STEAM_1:0:") != -1) {
		StripQuotes(con_name);
		TrimString(con_name);
		target = -1;
	} else {
		target = FindTarget(client, con_name, false, false);
		comm_con=target;
		if (target == -1) return Plugin_Handled;
		GetClientAuthString(target, con_name, sizeof(con_name));
	}
	if (StrContains(emp_name, "STEAM_1:0:") != -1) {
		StripQuotes(emp_name);
		TrimString(emp_name);
		target = -1;
	} else {
		target = FindTarget(client, emp_name, false, false);
		comm_emp=target;
		if (target == -1) return Plugin_Handled;
		GetClientAuthString(target, emp_name, sizeof(emp_name));
	}
	new comm_con_id=GetClientUserId(comm_con);
	new comm_emp_id=GetClientUserId(comm_emp);
	
	BeforePicking(client,comm_con_id,comm_emp_id);
	
	last_emp_choice = 0;
	last_con_choice = 0;
	if (!IsVoteInProgress()) Menu_PlayerPick(comm_con,2);
	return Plugin_Handled;	
}


public BeforePicking(client,comm_con_id,comm_emp_id) {	
	new players[MAXPLAYERS];
	new num = GetConnectedPlayers(players,true);
	new cur_player;
	new String:name[32];
	new String:userid[32];
	
	for(new i=0;i<num;i++)
	{
		cur_player = players[i];
		GetClientName(cur_player,name,sizeof(name));
		IntToString(GetClientUserId(cur_player),userid,sizeof(userid));
		
		if (StringToInt(userid) == comm_con_id ) {
			ChangeClientTeam(cur_player,2);
			PerformPromote(client, cur_player);
			ReplyToCommand(client, "Player %s set to be Consortium Commander",name);
			continue;
		} else if ( StringToInt(userid) == comm_emp_id) {
			
			ChangeClientTeam(cur_player,3);
			PerformPromote(client, cur_player);
			ReplyToCommand(client, "Player %s set to be Empire Commander",name);
			continue;
		} else {
			//ReplyToCommand(client, "Player %s set to Spectate",name);
			ChangeClientTeam(cur_player,1);
			continue;
		}
	}
	
}

// AddPlayerToList(players[MAXPLAYERS],userid) {
	// for(new i=0;i<sizeof(players);i++) {
		// if (players[i] == 0) {
			// players[i] = userid;
			// return players;
		// }
	// }
	// return players;
// }

PerformPromote(client, target)
{
	ServerCommand("_promote_to_commander %d", target);
	LogAction(client, target, "\"%L\" promoted \"%L\" to commander.", client, target);
}

GetConnectedPlayers(players[MAXPLAYERS],bool:bots=true)
{
new PlayersNum=0;
for(new i=1;i<=GetMaxClients();i++)
{
	if(IsClientInGame(i))
	{
		if(IsFakeClient(i))
		{
			if(bots==true)
			{
				players[PlayersNum] = i;
				PlayersNum++;
			}
		}
		else
		{
			players[PlayersNum] = i;
			PlayersNum++;
		}
	}
}
return PlayersNum;
}

// DisplayArray(arr[MAXPLAYERS]) {
// new String:resStr[500]="";
// for(new i=0;i<sizeof(arr);i++) {
	// Format(resStr,sizeof(resStr),"%s - %d=%d",resStr,i,arr[i]);
// }
// PrintToChatAll("Result: %s",resStr);
// }

public Handle_PickPlayerMenu(Handle:menu, MenuAction:action, param1, param2) {
	new next_team, next_comm;
	if (action == MenuAction_Select) {
		new String:selectedItem[32] ,cur_userid, selectedItemValue;
		GetMenuItem(menu, param2, selectedItem, sizeof(selectedItem));		
		new String:cur_team[32], String:name[64];
		selectedItemValue=StringToInt(selectedItem)
		cur_userid=GetClientOfUserId(selectedItemValue);
		GetClientName(cur_userid,name,sizeof(name));
		if (cur_team_choosing == 2) {
			cur_team="Consortium";
			next_comm=comm_emp;
			next_team=3;
			last_con_choice = selectedItemValue;
		} else {
			cur_team="Empire";
			next_comm=comm_con;
			next_team=2;
			last_emp_choice= selectedItemValue;
		}
		if (selectedItemValue > 0) {
			PrintToChatAll("%s was choosen to join %s",name,cur_team);
			ChangeClientTeam(cur_userid,cur_team_choosing);
		}
		if (last_emp_choice == -1 && last_con_choice == -1) {
			g_hEnabled=0;
			PrintToChatAll("Player Picking has been completed.");
		} else {
			Menu_PlayerPick(next_comm,next_team);
		}
	} else if (action == MenuAction_Cancel) {
		if (cur_team_choosing == 2) {
			next_comm=comm_emp;
			next_team=3;
			last_con_choice = -1;
		} else {
			next_comm=comm_con;
			next_team=2;
			last_emp_choice=-1;
		}
		if (last_emp_choice == -1 && last_con_choice == -1) {
			g_hEnabled=0;
			PrintToChatAll("Player Picking has been completed.");
		} else {
			Menu_PlayerPick(next_comm,next_team);
		}
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}
 
public Action:Menu_PlayerPick(client, args)
{
	new String:TeamStr[30];
	new TeamNum=GetClientTeam(client);
	if (TeamNum == 2) TeamStr="Consortium";
	else if (TeamNum == 3) TeamStr="Empire";
	else TeamStr="Spectate";
	cur_team_choosing=TeamNum;
	new Handle:menu = CreateMenu(Handle_PickPlayerMenu);
	SetMenuTitle(menu, "Choose next person to add to %s",TeamStr);
	SetMenuExitButton(menu, false);
	new players[MAXPLAYERS];
	new num = GetConnectedPlayers(players);
	new cur_player, String:cur_name[60], String:cur_user[30];
	for(new i=0;i<num;i++)
	{
		if (GetClientTeam(players[i]) == 1) {
			cur_player=players[i];
			GetClientName(cur_player,cur_name,sizeof(cur_name));
			IntToString(GetClientUserId(cur_player),cur_user,sizeof(cur_user));			
			AddMenuItem(menu,cur_user,cur_name);
		}
	}
	AddMenuItem(menu,"-1","End/Skip");
	DisplayMenu(menu, client, 10);
 
	return Plugin_Handled;
}

