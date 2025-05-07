#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

ConVar L4DSurvivorLimit, L4DInfectedLimit;

public Plugin myinfo = 
{
    name = "L4D2 Unlimited Players",
    author = "AI",
    description = "Remove 4 players limit for both teams",
    version = "1.2",
    url = ""
};

public void OnPluginStart()
{
    // 获取游戏原生ConVar
    L4DSurvivorLimit = FindConVar("survivor_limit");
    L4DInfectedLimit = FindConVar("z_max_player_zombies");
    
    // 解除上限限制
    SetConVarBounds(L4DSurvivorLimit, ConVarBound_Upper, true, 8.0);
    SetConVarBounds(L4DInfectedLimit, ConVarBound_Upper, true, 8.0);
}