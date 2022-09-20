#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#include <left4dhooks>
#include <basecomm>

ConVar
	clvplus_charger_catch_dmg;

int
	iDmgChargerCatch;

public Plugin myinfo =
{
	name = "Charger冲撞伤害调整",
	author = "Kevonlin",
	description = "",
	version = "2.0",
	url = "https://steamcommunity.com/profiles/76561199044101393/"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	EngineVersion iEngine = GetEngineVersion();
	if (iEngine != Engine_Left4Dead2) {
		strcopy(sError, iErrMax, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	clvplus_charger_catch_dmg = CreateConVar("clvplus_charger_catch_dmg", "5.0", "Charger冲锋抓到生还者立即造成多少伤害", 0, true, 0.0);

	GetCvar();

	clvplus_charger_catch_dmg.AddChangeHook(ConvarChanged);

	HookEvent("charger_carry_start", EventChargerCarryStart, EventHookMode_Post);
}

void GetCvar() {
	iDmgChargerCatch = clvplus_charger_catch_dmg.IntValue;
}

public void ConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvar();
}

public Action EventChargerCarryStart(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "victim"));

	int health = GetEntProp(victim, Prop_Send, "m_iHealth");

	if(health > iDmgChargerCatch)
	{
		health -= iDmgChargerCatch;
		SetEntProp(victim, Prop_Send, "m_iHealth", health);
	}
	else
	{
		vIncapCheck(victim);
	}
	return Plugin_Continue;
}

void vIncapCheck(int client)
{
	if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		int iSurvivoMaxInc = FindConVar("survivor_max_incapacitated_count").IntValue;
		if(GetEntProp(client, Prop_Send, "m_currentReviveCount") >= iSurvivoMaxInc)
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", iSurvivoMaxInc - 1);
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
			StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
		}
		vIncapPlayer(client);
	}
}

void vIncapPlayer(int client) 
{
	SetEntityHealth(client, 1);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SDKHooks_TakeDamage(client, 0, 0, 100.0);
}