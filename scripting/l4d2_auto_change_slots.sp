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
    sm_slots_admin_in_game,
	cvarMvMaxPlayers;

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
    sm_slots_admin_in_game = CreateConVar("sm_slots_limits_change", "0", "Enable auto change slots when an admin in game.", 0, true, 0.0, true, 1.0);
    
    cvarMvMaxPlayers = FindConVar("sv_maxplayers");
    
    AutoExecConfig(true, "l4d2_auto_change_slots");
}

public void OnClientPostAdminCheck(int client)
{
    if (!sm_change_slots_enable.BoolValue) { return; }

    if (!sm_slots_admin_in_game.BoolValue) { return; }

    if (IsFakeClient(client)) { return; }

    int clients = GetClientCount(false);
    int MaxSlots = GetConVarInt(cvarMvMaxPlayers);
    
    if (clients <= MaxSlots) { return; }

    int Slots = GetConVarInt(sm_slots_limits_change);
    SetConVarInt(cvarMvMaxPlayers, MaxSlots + Slots);
}