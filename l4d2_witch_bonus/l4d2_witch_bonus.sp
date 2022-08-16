#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util> //IsTank

//L4D2_OnEndVersusModeRound
#include <left4dhooks> //#include <left4downtown>

ConVar
	g_hCvarEnabled,
	g_hCvarRecoveryWhitchPermanentealth,
	g_hCvarRecoveryWhitchTempHealth,
	g_hCvarPunishEnable,
	g_hCvarPunishHealth;

public Plugin myinfo =
{
	name = "Witch Bonus",
	author = "Kevonlin",
	description = "Recovery health when kill the witch and punish health when tank kill the witch.",
	version = "1.1",
	url = "https://steamcommunity.com/id/harrylin134/"
};

public void OnPluginStart()
{
	// cvars
	g_hCvarEnabled = CreateConVar("sm_pbonus_enable", "1", "Whether the penalty-bonus system is enabled.", _, true, 0.0, true, 1.0);
	g_hCvarRecoveryWhitchPermanentealth = CreateConVar("sm_recovery_permanenthealth_witch", "10", "Give hard health when a witch is killed (0 to disable entirely).", _, true, 0.0);
	g_hCvarRecoveryWhitchTempHealth = CreateConVar("sm_recovery_temphealth_witch", "10", "Give temp healthwhen a witch is killed (0 to disable entirely).", _, true, 0.0);
	g_hCvarPunishEnable = CreateConVar("sm_punish_enable", "1", "Give temp healthwhen a witch is killed (0 to disable entirely).", _, true, 0.0, true, 1.0);
	g_hCvarPunishHealth = CreateConVar("sm_puunish_health", "1000", "Give temp healthwhen a witch is killed (0 to disable entirely).", _, true, 0.0);

	// hook events
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_PostNoCopy);
}

public void Event_WitchKilled(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_hCvarEnabled.BoolValue) return;

	// 获取杀死witch玩家
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!IsValidPlayerIndex(client)) return;

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client)) return;

	// 判定不为生还者return
	// if (GetClientTeam(client) != L4D2Team_Survivor) return;
	if (GetClientTeam(client) == L4D2Team_Infected)
	{
		if (!g_hCvarPunishEnable.BoolValue) return;

		int tankHealth = GetEntProp(client, Prop_Send, "m_iHealth");
		tankHealth = tankHealth - g_hCvarPunishHealth.IntValue;

		if (tankHealth <= 0)
			ForcePlayerSuicide(client);

		SetEntProp(client, Prop_Send, "m_iHealth", tankHealth);
	}
	else if (GetClientTeam(client) == L4D2Team_Survivor)
	{
		// 获取实血和虚血
		int permanentHealth = GetSurvivorHardHealth(client);
		int tempHealth = GetSurvivorTempHealth(client);

		// 获取加血量
		int addPermanentHealth = g_hCvarRecoveryWhitchPermanentealth.IntValue;
		int addTempHealth = g_hCvarRecoveryWhitchTempHealth.IntValue;

		// 最终血量
		int finalPermanentHealth = permanentHealth + addPermanentHealth;
		int finalTempHealth = tempHealth + addTempHealth;

		// 加血
		int MaxHP = GetEntProp(client, Prop_Send, "m_iMaxHealth");

		// 已经满血
		if (permanentHealth >= MaxHP) return;

		// 最终实血超过最大血量，将血量置为满血，将虚血置为0
		// 第一种分类：1.有实血，没虚血。2.有实血，有虚血。3.没实血，有虚血。[舍弃]
		
		// 第二种分类：1.实血+虚血>=最大血量。2.实血＋虚血<最大血量
		// 1）最终实血=最终实血。最终虚血=最大血量-最终实血-1
		//						最大血量-最终虚血<0时 最终虚血=0
		// 2）最终实血=最终实血 最终虚血=最终虚血
		if (finalPermanentHealth + finalTempHealth >= MaxHP)
		{
			finalPermanentHealth = (((finalPermanentHealth) < MaxHP) ? finalPermanentHealth : MaxHP);
			finalTempHealth = (((MaxHP - finalPermanentHealth) < 0) ? 0 : (MaxHP - finalPermanentHealth));
		}

		if (!IsClientInGame(client)) return;

		SetSurvivorPermanentHealth(client, finalPermanentHealth);
		SetSurvivorTempHealth(client, finalTempHealth);
	}

	return;
}

int GetSurvivorHardHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

int GetSurvivorTempHealth(int client)
{
	int temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

void SetSurvivorPermanentHealth(int client, int health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

void SetSurvivorTempHealth(int client, int health)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(health));
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

bool IsValidPlayerIndex(int client)
{
	return ( (client > 0) && (client <= MaxClients) );
}