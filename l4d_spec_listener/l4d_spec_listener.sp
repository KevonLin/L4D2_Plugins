#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <colors>
#pragma newdecls required
#pragma semicolon 1

#define VOICE_NORMAL		 0	/**< Allow the client to listen and speak normally. */
#define VOICE_MUTED			 1	/**< Mutes the client from speaking to everyone. */
#define VOICE_SPEAKALL		 2	/**< Allow the client to speak to everyone. */
#define VOICE_LISTENALL		 4	/**< Allow the client to listen to everyone. */
#define VOICE_TEAM			 8	/**< Allow the client to always speak to team, even when dead. */
#define VOICE_LISTENTEAM	 16 /**< Allow the client to always hear teammates, including dead ones. */

#define TEAM_SPEC			 1
#define TEAM_SURVIVOR		 2
#define TEAM_INFECTED		 3

#define IS_VALID_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1) (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1) (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1) (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1) (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1) (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1) (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1) (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

ConVar l4d2_spec_listener_enable;

bool g_bCvarPluginEnable;

public Plugin myinfo =
{
	name		= "Spectator Listener",
	author		= "KevonLin",
	description = "Enable spectatot listen voice of other teams",
	version		= "1.2",
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
	l4d2_spec_listener_enable = CreateConVar("l4d2_spec_listener_enable", "1", "Plugin enable", 0, true, 0.0, true, 1.0);
	HookEvent("player_team", Event_PlayerChangeTeam);
	RegConsoleCmd("sm_hear", Command_Hear);
	RegAdminCmd("sm_enablehear", Command_EnableHear, ADMFLAG_GENERIC);
	RegAdminCmd("sm_disablehear", Command_DisableHear, ADMFLAG_GENERIC);
	l4d2_spec_listener_enable.AddChangeHook(ConvarChanged);
}

public void ConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvar();
}

void GetCvar()
{
	g_bCvarPluginEnable = l4d2_spec_listener_enable.BoolValue;
}

public Action Command_Hear(int client, int args)
{
	if (!IS_VALID_CLIENT(client)) return Plugin_Handled;

	int client_team = GetClientTeam(client);
	if (client_team != TEAM_SPEC) return Plugin_Handled;

	int flag = GetClientListeningFlags(client);
	if (flag == VOICE_NORMAL)
	{
		SetClientListeningFlags(client, VOICE_LISTENALL);
		CPrintToChat(client, "{default}[{blue}Listener{default}] {blue}Enabled");
	}
	else if (flag == VOICE_LISTENALL)
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
		CPrintToChat(client, "{default}[{blue}Listener{default}] {blue}Disabled");
	}
	return Plugin_Handled;
}

public Action Command_EnableHear(int client, int args)
{
	if (g_bCvarPluginEnable)
	{
		CPrintToChat(client, "{default}[{blue}Notice{default}] Listener has been {blue}Enabled");
		return Plugin_Handled;
	}
	SetConVarBool(l4d2_spec_listener_enable, true);
	for (int i = 0; i <= MaxClients; i++)
	{
		if (!IS_VALID_INGAME(i)) continue;
		int client_team = GetClientTeam(i);
		if ( client_team != TEAM_SPEC) continue;
		SetClientListeningFlags(i, VOICE_LISTENALL);
	}
	CPrintToChat(client, "{default}[{blue}Notice{default}] {blue}Enabled");
	return Plugin_Handled;
}

public Action Command_DisableHear(int client, int args)
{
	if (!g_bCvarPluginEnable)
	{
		CPrintToChat(client, "{default}[{blue}Notice{default}] Listener has been {blue}Disabled");
		return Plugin_Handled;
	}
	SetConVarBool(l4d2_spec_listener_enable, false);
	for (int i = 0; i <= MaxClients; i++)
	{
		if (!IS_VALID_INGAME(i)) continue;
		int client_team = GetClientTeam(i);
		if ( client_team != TEAM_SPEC) continue;
		SetClientListeningFlags(i, VOICE_NORMAL);
	}
	CPrintToChat(client, "{default}[{blue}Notice{default}] {blue}Disabled");
	return Plugin_Handled;
}

public void Event_PlayerChangeTeam(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bCvarPluginEnable) return;
	int client		= GetClientOfUserId(GetEventInt(event, "userid"));
	int client_team = GetEventInt(event, "team");
	if (client == 0)
		return;

	// PrintToChat(userID,"\x02X02 \x03X03 \x04X04 \x05X05 ");\\ \x02:color:default \x03:lightgreen \x04:orange \x05:darkgreen

	if (client_team == TEAM_SPEC)
	{
		SetClientListeningFlags(client, VOICE_LISTENALL);
	}
	else
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
	}
}
