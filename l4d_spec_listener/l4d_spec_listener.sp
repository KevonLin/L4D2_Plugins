#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#pragma newdecls required
#pragma semicolon 1

#define IS_VALID_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)

#define VOICE_NORMAL	0	/**< Allow the client to listen and speak normally. */
#define VOICE_MUTED		1	/**< Mutes the client from speaking to everyone. */
#define VOICE_SPEAKALL	2	/**< Allow the client to speak to everyone. */
#define VOICE_LISTENALL	4	/**< Allow the client to listen to everyone. */
#define VOICE_TEAM		8	/**< Allow the client to always speak to team, even when dead. */
#define VOICE_LISTENTEAM	16	/**< Allow the client to always hear teammates, including dead ones. */

#define TEAM_SPEC 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

public Plugin myinfo =
{
	name		= "Spectator Listener",
	author		= "KevonLin",
	description = "Enable spectatot listen voice of other teams",
	version		= "1.0.3",
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
	HookEvent("player_team",Event_PlayerChangeTeam);
	RegConsoleCmd("sm_hear", Panel_hear);

}

public Action Panel_hear(int client, int args)
{
	if (!IS_VALID_CLIENT(client)) return Plugin_Handled;

	int client_team = GetClientTeam(client);
	if (client_team != TEAM_SPEC) return Plugin_Handled;

	int flag = GetClientListeningFlags(client);
	if (flag == VOICE_NORMAL)
	{
		SetClientListeningFlags(client, VOICE_LISTENALL);
		PrintToChat(client, "\x04[Listener] \x03Enable");
	}
	else if (flag == VOICE_LISTENALL)
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
		PrintToChat(client, "\x04[Listener] \x03Disable");
	}
	return Plugin_Handled;

}

public void Event_PlayerChangeTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int userID = GetClientOfUserId(GetEventInt(event, "userid"));
	int userTeam = GetEventInt(event, "team");
	if(userID == 0)
		return;

	//PrintToChat(userID,"\x02X02 \x03X03 \x04X04 \x05X05 ");\\ \x02:color:default \x03:lightgreen \x04:orange \x05:darkgreen
	
	if(userTeam==TEAM_SPEC)
	{
		SetClientListeningFlags(userID, VOICE_LISTENALL);
	}
	else
	{
		SetClientListeningFlags(userID, VOICE_NORMAL);
	}
}
	
