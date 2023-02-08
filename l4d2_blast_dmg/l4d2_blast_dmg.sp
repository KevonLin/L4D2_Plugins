#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#include <left4dhooks>

#define DEBUG 0

ConVar
	g_hCvarDmgBlast;

int
	g_iDmgBlast;

public Plugin myinfo = 
{
    name = "爆炸伤害调整",
    author = "Kevonlin",
    description = "爆炸伤害调整",
    version = "1.0",
    url = "https://github.com/KevonLin"
}

/* -------------------------------
 *      Init
 * ------------------------------- */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead2 ) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success; 
}

public void OnPluginStart()
{
	// cvars
	g_hCvarDmgBlast = CreateConVar("l4d2_dmg_blast", "500.0", "爆炸对tank造成的伤害.", _, true, 0.0);

	GetCvar();

	g_hCvarDmgBlast.AddChangeHook(CvarChanged);
}

void GetCvar()
{
	g_iDmgBlast = g_hCvarDmgBlast.IntValue;
}

public void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvar();
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageFromBlast);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamageFromBlast);
}

public Action OnTakeDamageFromBlast(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype)
{
	#if DEBUG
	PrintToChatAll("iDamagetype:%i", iDamagetype);
	#endif
	//1.判断伤害类型是否是爆炸
	if(iDamagetype != 134217792) return Plugin_Continue;

	#if DEBUG
	PrintToChatAll("确认爆炸伤害");
	#endif

	//2.判断受害者是否是Tank
	if(!IsTank(iVictim)) return Plugin_Continue;

	#if DEBUG
	PrintToChatAll("确认受害者是tank");
	#endif

	int tankHealth = GetTankHealth(iVictim)
	int finalHealth = tankHealth - g_iDmgBlast;
	
	#if DEBUG
	PrintToChatAll("Tank扣血前:%i", tankHealth);
	#endif

	//3.扣血
	if (finalHealth <= 0)
	{
		ForcePlayerSuicide(iVictim);
		return Plugin_Continue;
	}
	SetTankHealth(iVictim, finalHealth);

	#if DEBUG
	PrintToChatAll("Tank扣血后:%i", tankHealth);
	#endif

	return Plugin_Continue;
}

int GetTankHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

void SetTankHealth(int client, int health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}