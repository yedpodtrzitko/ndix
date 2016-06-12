#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <ndix>

#define PLUGIN_NAME "ND Commander Actions"
#define PLUGIN_VERSION "1.4"

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Xander (Player 1)",
	description = "A rewrite of 1Swat's 'Commander Management' using keyvalues instead of SQL to save bans.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=192858"
}

new Handle:hAdminMenu = INVALID_HANDLE;

public OnPluginStart()
{
	CreateConVar("sm_nd_commander_actions_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_REPLICATED);
	
	RegAdminCmd("sm_setcommander", Cmd_SetCommander, ADMFLAG_SLAY, "<Name|#UserID> - Promote a player to commander.");
	RegAdminCmd("sm_demotecommander", Cmd_Demote, ADMFLAG_SLAY, "<ct | emp> - Remove a team's commander.");

	LoadTranslations("common.phrases"); //required for FindTarget
	
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
		OnAdminMenuReady(topmenu);
}
public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
		hAdminMenu = INVALID_HANDLE;
}

public OnAdminMenuReady(Handle:topmenu)
{
	if (topmenu == hAdminMenu)
		return;
	
	hAdminMenu = topmenu;
	
	new TopMenuObject:CMCategory = AddToTopMenu(topmenu, "Commander Actions", TopMenuObject_Category, CategoryHandler, INVALID_TOPMENUOBJECT);
	AddToTopMenu(topmenu, "Set Commander", TopMenuObject_Item, CMHandleSETCommander, CMCategory, "sm_setcommander", ADMFLAG_SLAY);
	AddToTopMenu(topmenu, "Demote Commander", TopMenuObject_Item, CMHandleDEMOTECommander, CMCategory, "sm_demotecommander", ADMFLAG_SLAY);
}

public Action:Cmd_SetCommander(client, args)
{
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setcommander <Name|#Userid>");
		return Plugin_Handled;
	}
	
	decl String:arg1[64]
	GetCmdArg(1, arg1, sizeof(arg1));
	
	new target = FindTarget(client, arg1, true, true);
	
	if (target > -1) {
		PerformPromote(client, target);
	}

	return Plugin_Handled;
}

public Action:Cmd_Demote(client, args)
{
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_demotecommander <ct | emp>");
		return Plugin_Handled;
	}
	
	new team;
	decl String:arg1[64];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	if (StrEqual(arg1, "ct", false))
	{
		team = 2;
	}
	else if (StrEqual(arg1, "emp", false))
	{
		team = 3;
	}
	else
	{
		ReplyToCommand(client, "%s Unknown argument: %s. Usage: sm_demotecommander <ct | emp>", SERVER_NAME_TAG, arg1);
		return Plugin_Handled;
	}
	
	if (!DemoteComm(team)) {
		ReplyToCommand(client, "%s No commander on team %s", SERVER_NAME_TAG, arg1);
	}
	
	return Plugin_Handled;
}

PerformPromote(client, target)
{
	ServerCommand("_promote_to_commander %d", target);
	LogAction(client, target, "\"%L\" promoted \"%L\" to commander.", client, target);
	ShowActivity2(client, "[SM] ", "Promoted %N to commander.", target);
}

//=========MENU HANDLERS====================================================

public CategoryHandler(Handle:topmenu, 
				TopMenuAction:action,
				TopMenuObject:object_id,
				param,
				String:buffer[],
				maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "Commander Actions:");
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Commander Actions");
	}
}

// Set Commander Menu Handlers
public CMHandleSETCommander(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Set");
	
	else if (action == TopMenuAction_SelectOption)
	{
		new Handle:menu = CreateMenu(Handle_SetCommander_SelectTeam);
		SetMenuTitle(menu, "Select a Team:");
		AddMenuItem(menu, "2", "Consortium");
		AddMenuItem(menu, "3", "Empire");
		DisplayMenu(menu, param, MENU_TIME_FOREVER);
	}
}
public Handle_SetCommander_SelectTeam(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:item[8]
		GetMenuItem(menu, param2, item, sizeof(item));
		Display_SetCommander_TeamList(param1, StringToInt(item));
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}
Display_SetCommander_TeamList(client, SelectedTeam)
{
	decl String:UserID[8], String:Name[64]
	new Handle:menu = CreateMenu(Handle_SetCommander_ClientSelection);
	SetMenuTitle(menu, "Select A Player:");
	
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			if (!IsFakeClient(i) && GetClientTeam(i) == SelectedTeam && CanUserTarget(client, i))
			{
				IntToString(GetClientUserId(i), UserID, sizeof(UserID));
				GetClientName(i, Name, sizeof(Name));
				AddMenuItem(menu, UserID, Name);
			}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public Handle_SetCommander_ClientSelection(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:item[8];
		GetMenuItem(menu, param2, item, sizeof(item));
		new target = StringToInt(item);
		target = GetClientOfUserId(target);
	
		if (target)
			PerformPromote(param1, target)
		
		else
			PrintToChat(param1, "[SM] That player is no longer available.");
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

// Demote Commander Menu Handlers
public CMHandleDEMOTECommander(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Demote");
	
	else if (action == TopMenuAction_SelectOption)
	{
		new Handle:menu = CreateMenu(Handle_DemoteCommander_SelectTeam);
		SetMenuTitle(menu, "Demote Which Commander?");
		
		if (GameRules_GetPropEnt("m_hCommanders", 0) == -1)
			AddMenuItem(menu, "", "Consortium", ITEMDRAW_DISABLED);
		
		else
			AddMenuItem(menu, "0", "Consortium");
				
		if (GameRules_GetPropEnt("m_hCommanders", 1) == -1)
			AddMenuItem(menu, "1", "Empire", ITEMDRAW_DISABLED);
		
		else
			AddMenuItem(menu, "1", "Empire");
		
		DisplayMenu(menu, param, MENU_TIME_FOREVER);
	}
}
public Handle_DemoteCommander_SelectTeam(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select)
	{
		decl String:item[8];
		GetMenuItem(menu, param2, item, sizeof(item));
		new target = GameRules_GetPropEnt("m_hCommanders", StringToInt(item));
		
		if (target == -1)
			return;
		
		if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] You cannon target this client.");
			return;
		}
		
		DemoteComm(StringToInt(item)+2);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}
