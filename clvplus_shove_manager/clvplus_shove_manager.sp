#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util> 
#include <left4dhooks>
#include <sdkhooks>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

ConVar
	g_hCvarEnabled,
	g_hCvarBommerCount,
	g_hCvarSpitterCount,
	g_hCvarDebug;

bool
	g_bCvarEnabled,
	g_bCvarDebug;


int
	g_iCvarBommerCount,
	g_iCvarSpitterCount,
	shoveCount[MAXPLAYERS + 1];


public Plugin myinfo = {
	name = "特感被推调整",
	author = "Kevonlin",
	description = "特感被推调整",
	version = "1.0",
	url = "https://steamcommunity.com/id/harrylin134/"
};

public void OnAllPluginsLoaded()
{
	ConVar version = FindConVar("left4dhooks_version");
	if( version != null )
	{
		char sVer[8];
		version.GetString(sVer, sizeof(sVer));

		float ver = StringToFloat(sVer);
		if( ver >= 1.102 )
		{
			return;
		}
	}

	SetFailState("\n==========\nThis plugin requires \"Left 4 DHooks Direct\" version 1.02 or newer. Please update:\nhttps://forums.alliedmods.net/showthread.php?t=321696\n==========");
}

public void OnPluginStart() {
	// cvars
	g_hCvarEnabled = CreateConVar("clvplus_shove_enable", "1", "Whether the penalty-bonus system is enabled.", _, true, 0.0, true, 1.0);
	g_hCvarBommerCount = CreateConVar("clvplus_bommer_count", "2", "Bommer被推几次炸", _, true, 0.0);
	g_hCvarSpitterCount = CreateConVar("clvplus_spitter_count", "4", "Spitter被推几次死", _, true, 0.0);
	g_hCvarDebug = CreateConVar("clvplus_shove_debug", "0", "Debug", _, true, 0.0, true, 1.0);

	GetCvar();

	// hook events
	g_hCvarEnabled.AddChangeHook(ConvarChanged);
	g_hCvarBommerCount.AddChangeHook(ConvarChanged);
	g_hCvarSpitterCount.AddChangeHook(ConvarChanged);
	g_hCvarDebug.AddChangeHook(ConvarChanged);

	HookEvent("player_shoved", Event_PlayerShoved, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public void OnClientPostAdminCheck(int client) {
	if(!g_bCvarDebug || IsFakeClient(client) || CheckCommandAccess(client, "", ADMFLAG_ROOT) == true) {
		return;
	}

	if(!(GetUserFlagBits(client) & ADMFLAG_GENERIC)) {
		KickClient(client, "服务器调试中...");
	}
}

void GetCvar() {
	g_bCvarEnabled = g_hCvarEnabled.BoolValue;
	g_iCvarBommerCount = g_hCvarBommerCount.IntValue;
	g_iCvarSpitterCount = g_hCvarSpitterCount.IntValue;
	g_bCvarDebug = g_hCvarDebug.BoolValue;
}

public void ConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvar();
}

public void Event_PlayerShoved(Event hEvent, const char[] sEventName, bool bDontBroadcast) {
	if (!g_bCvarEnabled) return;

	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));

	if (attacker == 0 || !IsClientInGame(attacker)) {
		return;
	}

	int victim = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!victim || !IsClientInGame(victim)) {
		return;
	}

	if (GetClientTeam(attacker) == L4D2Team_Survivor && GetClientTeam(victim) == L4D2Team_Infected) {
		int zombieclass = GetInfectedClass(victim);
		if (zombieclass == L4D2Infected_Tank) {
			return; // We don't care about tank damage
		}
		
		if (zombieclass == L4D2Infected_Boomer) {
			shoveCount[victim]++;
			if (shoveCount[victim] >= g_iCvarBommerCount) {
				SDKHooks_TakeDamage(victim, attacker, attacker, GetEntProp(victim, Prop_Data, "m_iHealth") + 1.0, DMG_CLUB);
			}
		} else if (zombieclass == L4D2Infected_Spitter) {
			shoveCount[victim]++;
			if (shoveCount[victim] >= g_iCvarSpitterCount) {
				SDKHooks_TakeDamage(victim, attacker, attacker, GetEntProp(victim, Prop_Data, "m_iHealth") + 1.0, DMG_CLUB);
			}
		}
	}
}

public void Event_PlayerDeath(Event hEvent, const char[] sEventName, bool bDontBroadcast) {
	int user = GetClientOfUserId(hEvent.GetInt("userid"));
	if (user == 0 || !IsClientInGame(user)) {
		return;
	}

	if (GetClientTeam(user) == L4D2Team_Infected) {
		shoveCount[user] = 0;
	}
}