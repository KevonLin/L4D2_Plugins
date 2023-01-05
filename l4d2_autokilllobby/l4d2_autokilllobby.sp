#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>

#define UNRESERVE_VERSION "1.0"

Handle
	cvarMvMaxPlayers,
	cvarSvLobby;
int
	SvLobby;

public Plugin:myinfo = 
{
	name = "自动移除大厅匹配",
	author = "Lin",
	description = "修改旁观后删除大厅信息",
	version = "UNRESERVE_VERSION",
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	CreateConVar("l4d_unreserve_version", UNRESERVE_VERSION);

	cvarSvLobby = FindConVar("sv_allow_lobby_connect_only");
	
	HookConVarChange(cvarMvMaxPlayers, ConVarChange);
}

public ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SvLobby = GetConVarInt(cvarSvLobby);
}

public void OnClientConnected(int client)
{
	if(SvLobby != 0)
	{
		SetConVarInt(FindConVar("sv_allow_lobby_connect_only"), 0);
		L4D_LobbyUnreserve();
	}
	// PrintToChatAll("[UL] Server was removed lobby matching.");
}