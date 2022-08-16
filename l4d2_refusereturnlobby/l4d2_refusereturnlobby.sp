#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#undef REQUIRE_PLUGIN

public Plugin myinfo =
{
	name = "Cannot vote return lobby plugin",
	author = "KevonLin",
	description = "Cannot vote return lobby.",
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
	
	char votename[16];
	GetCmdArg(1, votename, 16);
	if (!!strcmp(votename, "ReturnToLobby", false))
	{
		return Plugin_Continue;
	}
	
	CPrintToChat(client, "{blue}[{green}!{blue}] {default}Can not return to lobby.");

	return Plugin_Handled;
}