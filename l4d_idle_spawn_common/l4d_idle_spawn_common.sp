#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#pragma newdecls required
#pragma semicolon 1

#define IS_VALID_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1) (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1) (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1) (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1) (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1) (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1) (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1) (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

// #define MAXENTITY			   2048

// float  pos_common_died[MAXENTITY + 1][3];
float pos_client[MAXPLAYERS + 1][3];

bool g_bAllow[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name		= "Spawn Commons",
	author		= "KevonLin",
	description = "Spawn commons when a common dead",
	version		= "1.0.0",
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
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	RegAdminCmd("sm_setpos", Command_SetPos, ADMFLAG_ROOT, "Set position for common spawned");
	RegAdminCmd("sm_delpos", Command_DelPos, ADMFLAG_ROOT, "Stop common spawned");
}

public void Event_PlayerDeath(Event hEvent, const char[] eName, bool dontBroadcast)
{
	// common infected died (check for witch)
	// int common	 = hEvent.GetInt("entityid");
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));

	// common died
	if (IS_VALID_SURVIVOR(attacker))
	{
		// get common position(should provid a client id but found a entity id)
		// GetClientAbsOrigin(common, pos_common_died[common]);
		if(!g_bAllow) return;
		// spawn a common
		Do_SpawnInfected_Old(attacker);
	}
}

public Action Command_SetPos(int client, int args)
{
	GetClientEyePosition(client, pos_client[client]);
	PrintToChat(client,"Set position access.");
	g_bAllow[client] = true;
	return Plugin_Handled;
}

public Action Command_DelPos (int client, int args)
{
	PrintToChat(client,"Stop spawn access.");
	g_bAllow[client] = false;
	return Plugin_Handled;
}

void Do_SpawnInfected_Old(int client)
{
	int zombie = CreateEntityByName("infected");
	SetEntityModel(zombie, "models/infected/common_male_ceda.mdl");
	int ticktime = RoundToNearest(GetGameTime() / GetTickInterval()) + 5;
	SetEntProp(zombie, Prop_Data, "m_nNextThinkTick", ticktime);
	DispatchSpawn(zombie);
	ActivateEntity(zombie);
	// TeleportEntity(zombie, pos_common_died[common], NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(zombie, pos_client[client], NULL_VECTOR, NULL_VECTOR);
	return;
}