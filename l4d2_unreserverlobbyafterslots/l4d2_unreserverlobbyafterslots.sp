#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>

#define UNRESERVE_VERSION "1.0"

Handle
	cvarMvMaxPlayers,
	cvarSvLobby;
int
	MaxSlots,
	SvLobby;

public Plugin:myinfo = 
{
	name = "L4D1/2 修改旁观后后删除大厅",
	author = "Lin",
	description = "修改旁观后删除大厅信息",
	version = "1.0",
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	CreateConVar("l4d_unreserve_version", UNRESERVE_VERSION);

	cvarMvMaxPlayers = FindConVar("sv_maxplayers");
	cvarSvLobby = FindConVar("sv_allow_lobby_connect_only");
	
	HookConVarChange(cvarMvMaxPlayers, ConVarChange);
}

public ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MaxSlots = GetConVarInt(cvarMvMaxPlayers);
	SvLobby = GetConVarInt(cvarSvLobby);

	if(MaxSlots > 8 && SvLobby != 0)
    {
		SetConVarInt(FindConVar("sv_allow_lobby_connect_only"), 0);
		L4D_LobbyUnreserve();
		PrintToChatAll("[UL] Server was remove lobby match.");
    }
}