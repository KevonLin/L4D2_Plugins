#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#include <left4dhooks>

#define DEBUG 0

ConVar
	g_hCvarTankRockHealth,
	g_hCvarRockAttack;

float
	g_fRockHealth,
	g_fRockAttack,
	rockHealth;

int
	rockIndex;

public Plugin myinfo = 
{
    name = "坦克石头血量",
    author = "Kevonlin",
    description = "坦克石头血量调整",
    version = "1.0.1",
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
	g_hCvarTankRockHealth = CreateConVar("clvplus_rock_health", "100.0", "石头血量.", _, true, 0.0);
	g_hCvarRockAttack = CreateConVar("clvplus_rock_attack", "2.5", "生还者每次对石头造成多少伤害", _, true, 0.0);

	GetCvar();

	g_hCvarTankRockHealth.AddChangeHook(CvarChanged);
	g_hCvarRockAttack.AddChangeHook(CvarChanged);
}

void GetCvar()
{
	g_fRockHealth = g_hCvarTankRockHealth.FloatValue;
	g_fRockAttack = g_hCvarRockAttack.FloatValue;
}

public void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvar();
}

public void L4D_TankRock_OnRelease_Post(int tank, int rock, const float vecPos[3], const float vecAng[3], const float vecVel[3], const float vecRot[3])
{
	//1.设置石头血量
	rockIndex = rock;
	rockHealth = g_fRockHealth;

	#if DEBUG
	PrintToChatAll("tank: %N, rock: %d, rockHealth[tank]:%f", tank, rock, rockHealth);
	#endif

	SDKHook(rock, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype)
{
	if (!IsValidPlayerIndex(iAttacker)) return Plugin_Continue;

	//1.判断是否为机枪 
	if(!IsPlayerUseSmg(iAttacker)) return Plugin_Continue;

	//2.机枪修改伤害
	rockHealth -= g_fRockAttack;

	#if DEBUG
	PrintToChatAll("rockHealth:%f", rockHealth);
	#endif

	//4.判断石头是否碎裂
	if(rockHealth > g_fRockAttack * 3) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void L4D_TankRock_OnDetonate(int tank, int rock) {
	if(IsValidEdict(rockIndex)) {
		SDKUnhook(rockIndex, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
}

bool IsPlayerUseSmg(int iClient)
{
	int item = GetPlayerWeaponSlot(iClient, 0);
	if (IsValidEdict(item))
	{
		char buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		#if DEBUG
			PrintToChatAll("weapon:%s", buffer);
		#endif
		return StrEqual(buffer, "weapon_smg") || StrEqual(buffer, "weapon_smg_silenced");
	}
	return false;
}

bool IsValidPlayerIndex(int client)
{
	return ( (client > 0) && (client <= MaxClients) );
}