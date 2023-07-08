#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>
#pragma newdecls required
#pragma semicolon 1

Handle
	cvarMvMaxPlayers,
	cvarSvLobby;
int
	MaxSlots,
	SvLobby;

public Plugin myinfo =
{
	name		= "Auto Remove Lobby",
	author		= "KevonLin",
	description = "Auto remove lobby when slots != 8 | 4",
	version		= "1.0.1",
	url			= "https://github.com//KevonLin"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	EngineVersion iEngine = GetEngineVersion();
	if (iEngine != Engine_Left4Dead2)
	{
		strcopy(sError, iErrMax, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	cvarMvMaxPlayers = FindConVar("sv_maxplayers");
	cvarSvLobby		 = FindConVar("sv_allow_lobby_connect_only");
}

public void OnMapStart() {
	MaxSlots = GetConVarInt(cvarMvMaxPlayers);
	SvLobby	 = GetConVarInt(cvarSvLobby);

	if ((MaxSlots != 4 || MaxSlots != 8) && SvLobby != 0)
	{
		SetConVarInt(FindConVar("sv_allow_lobby_connect_only"), 0);
		L4D_LobbyUnreserve();
	}
}