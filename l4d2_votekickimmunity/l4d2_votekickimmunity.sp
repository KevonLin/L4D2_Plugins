#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#undef REQUIRE_PLUGIN

public Plugin myinfo =
{
	name = "Vote Kick Immunity plugin",
	author = "KevonLin",
	description = "Admin Cannot be kicked by vote.",
	version = "1.0",
	url = "N/A"
};

public void OnMapStart(){
	AddCommandListener(Callvote_Callback, "callvote");
}

public void OnMapEnd()
{
	RemoveCommandListener(Callvote_Callback, "callvote");
}

public Action Callvote_Callback(int client, char[] command, int argc)
{
	if (GetClientTeam(client) == L4D2Team_Spectator)
	{
		CPrintToChat(client, "{blue}[{green}!{blue}] {default}You're unable to call votes as a spectator.");
		return Plugin_Handled;
	}
	
	// kick vote from client, "callvote %s \"%d %s\"\n;"
	if (argc < 2)
	{
		return Plugin_Continue;
	}
	
	char votereason[16];
	GetCmdArg(1, votereason, 16);
	if (!!strcmp(votereason, "kick", false))
	{
		return Plugin_Continue;
	}
	
	char therest[256];
	GetCmdArg(2, therest, sizeof(therest));
	
	int userid;
	int spacepos = FindCharInString(therest, ' ', false);
	if (spacepos > -1)
	{
		char temp[12];
		strcopy(temp, L4D2Util_GetMin(spacepos + 1, sizeof(temp)), therest);
		userid = StringToInt(temp);
	}
	else
	{
		userid = StringToInt(therest);
	}
	
	int target = GetClientOfUserId(userid);
	if (target < 1)
	{
		return Plugin_Continue;
	}
	
	AdminId clientAdmin = GetUserAdmin(client);
	AdminId targetAdmin = GetUserAdmin(target);
	if (clientAdmin == INVALID_ADMIN_ID && targetAdmin == INVALID_ADMIN_ID)
	{
		return Plugin_Continue;
	}
	
	if (CanAdminTarget(clientAdmin, targetAdmin))
	{
		return Plugin_Continue;
	}
	
	CPrintToChat(client, "{blue}[{green}!{blue}] {default}You may not kick Admins.", target);
	CPrintToChat(target, "{blue}[{green}!{blue}] {default}You were voted out by {blue}%N", client);
	return Plugin_Handled;
}