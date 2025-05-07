#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ConVar g_cvSurvivorLimit, g_cvZMaxPlayerZombies;
int g_iSurvivorLimit, g_iZMaxPlayerZombies;
float g_fLastActiveTime[MAXPLAYERS + 1];
int g_iLastButtons[MAXPLAYERS + 1];
float g_fLastAngles[MAXPLAYERS + 1][3];

public Plugin myinfo = 
{
    name = "AFK Auto Spectate",
    author = "AI",
    description = "Move AFK players to spectators when teams are full",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
    // 获取并监听人数限制Cvar
    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_cvZMaxPlayerZombies = FindConVar("z_max_player_zombies");
    UpdateConVars();
    
    g_cvSurvivorLimit.AddChangeHook(OnConVarChanged);
    g_cvZMaxPlayerZombies.AddChangeHook(OnConVarChanged);
    
    // 设置定时器
    CreateTimer(1.0, Timer_CheckAFKPlayers, _, TIMER_REPEAT);
    
    // 初始化玩家数据
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsValidClient(i)) 
        {
            OnClientPutInServer(i);
        }
    }
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UpdateConVars();
}

void UpdateConVars()
{
    g_iSurvivorLimit = g_cvSurvivorLimit.IntValue;
    g_iZMaxPlayerZombies = g_cvZMaxPlayerZombies.IntValue;
}

public void OnClientPutInServer(int client)
{
    if (IsValidClient(client))
    {
        g_fLastActiveTime[client] = GetGameTime();
        g_iLastButtons[client] = 0;
        g_fLastAngles[client] = {0.0, 0.0, 0.0};
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, 
                            float vel[3], float angles[3], int &weapon)
{
    if (!IsValidClient(client)) return Plugin_Continue;
    
    // 检测输入变化
    if (buttons != g_iLastButtons[client] || !CompareAngles(angles, g_fLastAngles[client]))
    {
        g_fLastActiveTime[client] = GetGameTime();
        g_iLastButtons[client] = buttons;
        g_fLastAngles[client] = angles;
    }
    
    return Plugin_Continue;
}

// 修改Timer_CheckAFKPlayers循环部分
public Action Timer_CheckAFKPlayers(Handle timer)
{
    // 统计队伍人数
    int iSurvivors = 0, iInfected = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i)) continue;
        
        switch (GetClientTeam(i))
        {
            case TEAM_SURVIVOR: iSurvivors++;
            case TEAM_INFECTED: iInfected++;
        }
    }
    
    // 检查是否满员
    bool bTeamsFull = (iSurvivors >= g_iSurvivorLimit && iInfected >= g_iZMaxPlayerZombies);
    if (!bTeamsFull) return Plugin_Continue;
    
    // 检查AFK玩家
    float fCurrentTime = GetGameTime();
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client)) continue;
        
        int iTeam = GetClientTeam(client);
        if (iTeam != TEAM_SURVIVOR && iTeam != TEAM_INFECTED) continue;
        
        // 新增死亡状态豁免检测（同时适用生还和特感）
        if (!IsPlayerAlive(client)) continue;
        
        // 计算AFK时间
        float fAFKTime = fCurrentTime - g_fLastActiveTime[client];
        if (fAFKTime >= 15.0)
        {
            ChangeClientTeam(client, TEAM_SPECTATOR);
            PrintToChat(client, "\x04[AFK检测] \x01你因闲置超过15秒被移至旁观者");
        }
    }
    
    return Plugin_Continue;
}

bool IsValidClient(int client)
{
    return (client > 0 && 
            client <= MaxClients && 
            IsClientInGame(client) && 
            !IsFakeClient(client));
}

bool CompareAngles(const float angles1[3], const float angles2[3])
{
    return (FloatAbs(angles1[0] - angles2[0]) < 1.0 &&
            FloatAbs(angles1[1] - angles2[1]) < 1.0 &&
            FloatAbs(angles1[2] - angles2[2]) < 1.0);
}