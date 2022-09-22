#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "Change Slots",
	author = "KevonLin",
	description = "Change slots and kick lobby when lobby is full.",
	version = "1.0",
	url = "N/A"
};

ConVar
    sm_change_slots_enable,
    sm_slots_limits_change,
    sm_admin_auto_change_slots,
	cvarMvMaxPlayers;

int
    g_iCvarMvMaxPlayers,
    g_iSlotsLimitsChange;

bool
    g_bCvarPluginEnable,
    g_bCvarAdminChangEnable;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() == Engine_Contagion)
	{
		// sv_visiblemaxplayers doesn't exist
		strcopy(error, err_max, "Change Slots is incompatible with this game");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");

    sm_change_slots_enable = CreateConVar("sm_change_slots_enable", "1", "Plugin enable", 0, true, 0.0, true, 1.0);
    sm_slots_limits_change = CreateConVar("sm_slots_limits_change", "2", "Set lots limit more than MaxSlots", 0, true, 0.0);
    sm_admin_auto_change_slots = CreateConVar("sm_admin_auto_change_slots", "0", "Enable auto change slots when an admin in game.", 0, true, 0.0, true, 1.0);

    cvarMvMaxPlayers = FindConVar("sv_maxplayers");

    GetCvar();
   
    cvarMvMaxPlayers.AddChangeHook(ConvarChanged);
    sm_change_slots_enable.AddChangeHook(ConvarChanged);
    sm_slots_limits_change.AddChangeHook(ConvarChanged);
    sm_admin_auto_change_slots.AddChangeHook(ConvarChanged);
    
    AutoExecConfig(true, "l4d2_auto_change_slots");
}

public void ConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvar();
}

void GetCvar() {
    g_iCvarMvMaxPlayers = cvarMvMaxPlayers.IntValue;
    g_bCvarPluginEnable = sm_change_slots_enable.BoolValue;
    g_iSlotsLimitsChange = sm_slots_limits_change.IntValue;
    g_bCvarAdminChangEnable = sm_admin_auto_change_slots.BoolValue;
}

public void OnClientPostAdminCheck(int client)
{
    if (!g_bCvarPluginEnable) { return; }

    if (!g_bCvarAdminChangEnable) {
        if(HasAdminInServer()){
            return;
        }
    }

    if (IsFakeClient(client)) { return; }

    int clients = GetClientCount(false);
    int MaxSlots = g_iCvarMvMaxPlayers;
    
    if (clients <= MaxSlots) { return; }

    int Slots = g_iSlotsLimitsChange;
    SetConVarInt(cvarMvMaxPlayers, MaxSlots + Slots);
}

bool HasAdminInServer(){
    for(int i = 1; i < MaxClients; i++) {
        if(IsFakeClient(i) || CheckCommandAccess(i, "", ADMFLAG_ROOT) == true) {
            return true;
        }
    }
    return false;
}