#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "1v1Commander",
	author = "ND Battle Coders",
	description = "To be used with 1 v 1 battles with only commanders and everyone else spec",
	version = "1.0",
	url = ""
}

new g_hEnabled = 0;

public OnPluginStart() 
{
	LoadTranslations("common.phrases");
	RegConsoleCmd("1v1Comm",CommPick);
	RegConsoleCmd("1v1CommEnable",Comm1v1Enable);
	AddCommandListener(Command_JoinTeam, "jointeam");
}

public Action:Comm1v1Enable(client,args) 
{
	new String:stat_str[10];
	GetCmdArg(1, stat_str, sizeof(stat_str));
	g_hEnabled= StringToInt(stat_str);
	if (g_hEnabled == 1) {
		ReplyToCommand(client, "Team Changing is now disabled");
	} else {
		ReplyToCommand(client, "Team Changing is now allowed");
	}
}

public Action:Command_JoinTeam(client, String:command[], argc) 
{
	if (g_hEnabled==0) 
	{
		return Plugin_Continue;
	} else {
		return Plugin_Handled;
	}
}

public Action:CommPick(client,args) 
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: 1v1Comm <Consortium Name|#Userid> <Empire Name|#Userid>");
		return Plugin_Handled;
	}
	
	decl String:con_name[64]
	decl String:emp_name[64]
	GetCmdArg(1, con_name, sizeof(con_name));
	GetCmdArg(2, emp_name, sizeof(emp_name));	
	
	new comm_con = FindTarget(client, con_name, true, false);
	new comm_emp = FindTarget(client, emp_name, true, false);
	new comm_con_id=GetClientUserId(comm_con);
	new comm_emp_id=GetClientUserId(comm_emp);
	GetClientName(comm_con,con_name,sizeof(con_name));
	GetClientName(comm_emp,emp_name,sizeof(emp_name));
	ReplyToCommand(client, "Consortium: %s -- Empire: %s",con_name,emp_name);
	
	BeforePicking(client,comm_con_id,comm_emp_id);
	
	return Plugin_Handled;	
}


BeforePicking(client,comm_con_id,comm_emp_id) 
{	
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
		
		if (StringToInt(userid) == comm_con_id ) 
		{
			ChangeClientTeam(cur_player,2);
			PerformPromote(client, cur_player);
			ReplyToCommand(client, "Player %s set to be Consortium Commander",name);
			//continue;
		} else if ( StringToInt(userid) == comm_emp_id) 
		{
			
			ChangeClientTeam(cur_player,3);
			PerformPromote(client, cur_player);
			ReplyToCommand(client, "Player %s set to be Empire Commander",name);
			//continue;
		} else 
		{
			ReplyToCommand(client, "Player %s set to Spectate",name);
			ChangeClientTeam(cur_player,1);
			//continue;
		}
	}
	
}

PerformPromote(client, target)
{
	ServerCommand("_promote_to_commander %d", target);
	LogAction(client, target, "\"%L\" promoted \"%L\" to commander.", client, target);
	//ShowActivity2(client, "[SM] ", "Promoted %N to commander.", target);
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