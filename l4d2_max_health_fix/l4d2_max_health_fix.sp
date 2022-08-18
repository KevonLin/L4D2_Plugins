#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define MAXHP 100
#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D/L4D2]Max Health Fix",
	author = "KevonLin",
	description = "Fix survivor max health more than 100",
	version = PLUGIN_VERSION,
	url = "-"
};

public void OnPluginStart()
{
	CreateConVar("max_health_fix", PLUGIN_VERSION, "", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateTimer(0.5, UpdateHealth, _, TIMER_REPEAT);
}

public Action UpdateHealth(Handle timer)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || IsFakeClient(i) || IsIncapacitated(i) || IsHandingFromLedge(i))
			continue;
		
		// 获取实血和虚血
		int permanentHealth = GetSurvivorHardHealth(i);
		int tempHealth = GetSurvivorTempHealth(i);

		int finalPermanentHealth = permanentHealth;
		int finalTempHealth = tempHealth;

		if (finalPermanentHealth + finalTempHealth > MAXHP)
		{
			finalPermanentHealth = (((finalPermanentHealth) < MAXHP) ? finalPermanentHealth : MAXHP);
			finalTempHealth = (((MAXHP - finalPermanentHealth) > 0) ? (MAXHP - finalPermanentHealth) : 0);
		
			SetSurvivorPermanentHealth(i, finalPermanentHealth);
			SetSurvivorTempHealth(i, finalTempHealth);
		}

	}

	return Plugin_Continue;
}

stock bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

stock bool IsHandingFromLedge(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
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