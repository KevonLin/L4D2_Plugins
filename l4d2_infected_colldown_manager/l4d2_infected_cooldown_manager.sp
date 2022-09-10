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
	version = "1.1",
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
			
			if (duration[attacker] + g_fChangerAttackDelay >= timestamp[attacker]) {
				SetInfectedAbilityTimer(attacker, duration[attacker], finaltime[attacker]);
			} else {
				SetInfectedAbilityTimer(attacker, zduration, zerotime);
			}

			if (fIntervalCount[attacker] > g_fChangerAttackDelay) {
				fIntervalCount[attacker] -= g_fChangerAttackDelay;
			} else {
				fIntervalCount[attacker] = g_fChargerInterval;
			}
		} else if (zombieclass == L4D2Infected_Smoker) {
			//Smoker攻击后立即刷新技能
			SetInfectedAbilityTimer(attacker, zduration, zerotime);
		}
	} /*else if (GetClientTeam(victim) == L4D2Team_Infected && GetClientTeam(attacker) == L4D2Team_Survivor) {
		// 特感被推
		PrintToChatAll("攻击者是%N", attacker);
		PrintToChatAll("受害者是%N", victim);
		int zombieclass = GetInfectedClass(victim);
		if (zombieclass == L4D2Infected_Tank) {
			return; // We don't care about tank damage
		}
		if (zombieclass == L4D2Infected_Spitter) {
			// 当Spitter被推后技能马上冷却
			SetInfectedAbilityTimer(attacker, zduration, zerotime);
		} else if (zombieclass == L4D2Infected_Jockey) {
			// 当Jocker被幸存者推中后会重设主技能冷却时间为1.5秒
			SetInfectedAbilityTimer(attacker, jduration, jockeytime);
		}
	}*/
}

public void Event_ChargerChargeStart(Event hEvent, const char[] sEventName, bool bDontBroadcast) {
	int attacker = GetClientOfUserId(hEvent.GetInt("userid"));
	if (attacker == 0 || !IsClientInGame(attacker)) {
		return;
	}
	fIntervalCount[attacker] = g_fChargerInterval;
}
/*
public Action L4D_OnShovedBySurvivor(int client, int victim, const float vecDir[3]) {
	if (!g_bCvarEnable) return Plugin_Continue;

	// int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	PrintToChatAll("%N被推", victim);
	// if (!GetInfectedAbilityTimer(victim, timestamp[victim], duration[victim])) return;

	int zombieclass = GetInfectedClass(victim);
	if (zombieclass == L4D2Infected_Tank) {
		return Plugin_Continue; // We don't care about tank damage
	}

	// float time = GetGameTime();
	// float zerotime = 0.5;
	// // float jockeyTime = 1.5;
	// float zduration;
	// 当Spitter被推后技能马上冷却
	if (zombieclass == L4D2Infected_Spitter) {
		SDKHooks_TakeDamage(victim, client, client, 1.0);
		// zduration = time + zerotime;
		// SetInfectedAbilityTimer(victim, zerotime, zerotime);
		// SetEntPropFloat(victim, Prop_Send, "m_nextActivationTimer", 0.5, 0);
		// SetEntPropFloat(victim, Prop_Send, "m_nextActivationTimer", GetGameTime() + 0.5, 1);
		// PrintToChatAll("%N的cd已重置");
	} else if (zombieclass == L4D2Infected_Jockey) {
		SDKHooks_TakeDamage(victim, client, client, 1.0);
		// 当Jocker被幸存者推中后会重设主技能冷却时间为1.5秒
		// zduration = time + jockeyTime;
		// SetInfectedAbilityTimer(victim, zduration, jockeyTime);
		// PrintToChatAll("%N的猴子cd已重置");
	}

	return Plugin_Continue;
}*/