#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#undef REQUIRE_PLUGIN
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#include <left4dhooks>
#include <basecomm>
#include <l4d2util_infected>

ConVar
	// cvarEnable,
	z_charge_interval, 
	cvarChargerDelay,
	cvarInfMgrDebug;
bool
	// g_bCvarEnable,
	isChargerUseAbility[MAXPLAYERS + 1],
	g_bDebug;

float
	timestamp[MAXPLAYERS + 1],
	duration[MAXPLAYERS + 1],
	finaltime[MAXPLAYERS + 1],
	fIntervalCount[MAXPLAYERS + 1],
	g_fChargerInterval,
	g_fChangerAttackDelay;

public Plugin myinfo = {
	name = "特感冷却控制器",
	author = "Kevonlin",
	description = "调整特感冷却时间",
	version = "1.2.1",
	url = "https://steamcommunity.com/profiles/76561199044101393/"
};

public void OnPluginStart() {
	// cvarEnable = CreateConVar("l4d2_cool_down_enable", "1", "Plugin enable", 0, true, 0.0, true, 1.0);
	cvarChargerDelay = CreateConVar("l4d2_charger_after_attack_delay", "4.0", "How long of a cooldown does the charger attacks Survivors? ");
	cvarInfMgrDebug = CreateConVar("l4d2_inf_cooldown_mgr_debug", "0", "Enable debug and kick do not have Admin flag", 0, true, 0.0, true, 1.0);
	g_bDebug = GetConVarBool(cvarInfMgrDebug);

	z_charge_interval = FindConVar("z_charge_interval");

	GetCvar();

	InitDelay();

	z_charge_interval.AddChangeHook(ConvarChanged);
	cvarChargerDelay.AddChangeHook(ConvarChanged);
	// cvarEnable.AddChangeHook(ConvarChanged);

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_PostNoCopy);
	HookEvent("charger_charge_start", Event_ChargerChargeStart, EventHookMode_PostNoCopy);
	HookEvent("respawning", Event_PlayerRespawning, EventHookMode_PostNoCopy);
	// HookEvent("player_shoved", Event_PlayerShoved, EventHookMode_PostNoCopy);
}

public void OnClientPostAdminCheck(int client) {
	if(!g_bDebug || IsFakeClient(client) || CheckCommandAccess(client, "", ADMFLAG_ROOT) == true) {
		return;
	}

	if(!(GetUserFlagBits(client) & ADMFLAG_GENERIC)) {
		KickClient(client, "服务器调试中...");
	}
}

void GetCvar() {
	// g_bCvarEnable = cvarEnable.BoolValue;
	g_fChangerAttackDelay = cvarChargerDelay.FloatValue;
	g_fChargerInterval = z_charge_interval.FloatValue;
}

void InitDelay() {
	for (int i = 1; i <= MaxClients; i++) {
		fIntervalCount[i] = g_fChargerInterval;
	}
}

public void ConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvar();
}

public void Event_PlayerRespawning(Event hEvent, const char[] sEventName, bool bDontBroadcast) {
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if (client == 0 || !IsClientInGame(client)) {
		return;
	}

	int zombieclass = GetInfectedClass(client);
	if (zombieclass == L4D2Infected_Charger) {
		isChargerUseAbility[client] = false;
		fIntervalCount[client] = g_fChargerInterval;
	}
}


public void Event_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast) {
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	if (victim == 0 || !IsClientInGame(victim)) {
		return;
	}
	
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker)) {
		return;
	}

	float time = GetGameTime();
	float zerotime = 0.5;
	// float jockeytime = 1.5;
	float zduration = time + zerotime;
	// float jduration = time + jockeytime;

	if (GetClientTeam(attacker) == L4D2Team_Infected && GetClientTeam(victim) == L4D2Team_Survivor) {
		int zombieclass = GetInfectedClass(attacker);
		if (zombieclass == L4D2Infected_Tank) {
			return; // We don't care about tank damage
		}

		// 当Charger主技能处于冷却时，右键成功击中幸存者每次减少4秒的冷却时间.
		if (zombieclass == L4D2Infected_Charger) {
			
			if (!GetInfectedAbilityTimer(attacker, timestamp[attacker], duration[attacker])) return;

			finaltime[attacker] = fIntervalCount[attacker] - g_fChangerAttackDelay; 
			duration[attacker] = time + finaltime[attacker];
			
			if (isChargerUseAbility[attacker] && (duration[attacker] + fIntervalCount[attacker] >= timestamp[attacker])) {
				SetInfectedAbilityTimer(attacker, duration[attacker], finaltime[attacker]);
			} else {
				if(isChargerUseAbility[attacker]){
					isChargerUseAbility[attacker] = false;
				}
				SetInfectedAbilityTimer(attacker, zduration, zerotime);
			}

			if (fIntervalCount[attacker] > g_fChangerAttackDelay) {
				fIntervalCount[attacker] -= g_fChangerAttackDelay;
			} else {
				if(isChargerUseAbility[attacker]){
					isChargerUseAbility[attacker] = false;
				}
				fIntervalCount[attacker] = g_fChargerInterval;
			}
		} else if (zombieclass == L4D2Infected_Smoker) {
			//Smoker攻击后立即刷新技能
			SetInfectedAbilityTimer(attacker, zduration, zerotime);
		}
	} 
}

public void Event_ChargerChargeStart(Event hEvent, const char[] sEventName, bool bDontBroadcast) {
	int attacker = GetClientOfUserId(hEvent.GetInt("userid"));
	if (attacker == 0 || !IsClientInGame(attacker)) {
		return;
	}

	if(!isChargerUseAbility[attacker]){
		isChargerUseAbility[attacker] = true;
	}

	fIntervalCount[attacker] = g_fChargerInterval;
}

public Action L4D_OnShovedBySurvivor(int client, int victim, const float vecDir[3]) {
	if (!GetInfectedAbilityTimer(victim, timestamp[victim], duration[victim])) return Plugin_Continue;

	int zombieclass = GetInfectedClass(victim);
	if (zombieclass == L4D2Infected_Tank) {
		return Plugin_Continue; // We don't care about tank damage
	}

	if (zombieclass == L4D2Infected_Spitter) {
		CreateTimer(0.1, Timer_SpitterShoved, victim);
	} else if (zombieclass == L4D2Infected_Jockey) {
		CreateTimer(0.1, Timer_JockeyShoved, victim);
	}

	return Plugin_Continue;
}

public Action Timer_SpitterShoved(Handle timer, any client)
{
	float time = GetGameTime();
	float zerotime = 0.4;
	float zduration = time + zerotime;
	SetInfectedAbilityTimer(client, zduration, zerotime);
	// PrintToChatAll("%N的cd已重置", client);
	return Plugin_Continue;
}

public Action Timer_JockeyShoved(Handle timer, any client)
{
	float time = GetGameTime();
	float jockeyTime = 1.4;
	float jduration = time + jockeyTime;
	SetInfectedAbilityTimer(client, jduration, jockeyTime);
	// PrintToChatAll("%N的猴子cd已重置", client);
	return Plugin_Continue;
}