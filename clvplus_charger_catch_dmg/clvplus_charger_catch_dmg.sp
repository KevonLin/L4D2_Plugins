#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define PLUGIN_VERSION "3.1"
#define VALID_DAMAGE_TYPES DMG_CLUB // 使用近战伤害类型

ConVar g_hChargeDamage;

public Plugin myinfo = 
{
    name = "L4D2 Safe Charger Damage",
    author = "AI Assistant",
    description = "Applies safe instant damage on grab with color notifications",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_hChargeDamage = CreateConVar("l4d2_charge_damage", 
        "5.0",
        "Damage applied when charger grabs survivor", 
        FCVAR_NOTIFY|FCVAR_SPONLY);
    
    HookEvent("charger_carry_start", EventChargerCarryStart, EventHookMode_Post);
    AutoExecConfig(true, "l4d2_charge_damage");
}

public Action EventChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    
    // 二次有效性验证（防止事件延迟导致的问题）
    if (!IsValidCharger(attacker) || !IsValidSurvivor(victim)) 
    {
        return Plugin_Continue;
    }
    
    // 获取当前生命值并计算有效伤害
    int currentHealth = GetClientHealth(victim);
    float configDamage = g_hChargeDamage.FloatValue;
    float actualDamage = float(currentHealth < RoundToFloor(configDamage) ? currentHealth : RoundToFloor(configDamage));
    
    // 应用安全伤害
    if (actualDamage > 0.0)
    {
        SDKHooks_TakeDamage(victim, 
            attacker,    // 伤害来源
            attacker,    // 伤害发起者
            actualDamage, 
            VALID_DAMAGE_TYPES);
        
        // 获取安全名称（防止断开连接导致的格式错误）
        char attackerName[32], victimName[32];
        GetClientSafeName(attacker, attackerName, sizeof(attackerName));
        GetClientSafeName(victim, victimName, sizeof(victimName));
        
        // 发送彩色通知
        CPrintToChatAll("{green}★★ {olive}%s {default}charged {olive}%s {default}for {red}%.0f {default}damage!", 
            attackerName, 
            victimName, 
            actualDamage);
    }
    return Plugin_Continue;
}

// 安全获取客户端名称
void GetClientSafeName(int client, char[] buffer, int size)
{
    if (IsValidClient(client))
    {
        GetClientName(client, buffer, size);
    }
    else
    {
        Format(buffer, size, "Disconnected Player");
    }
}

// 增强型客户端验证
bool IsValidClient(int client)
{
    return (client > 0 && 
           client <= MaxClients && 
           IsClientInGame(client) && 
           !IsFakeClient(client));
}

bool IsValidCharger(int client)
{
    return (IsValidClient(client) && 
           GetClientTeam(client) == 3 && 
           GetEntProp(client, Prop_Send, "m_zombieClass") == 6);
}

bool IsValidSurvivor(int client)
{
    return (IsValidClient(client) && 
           GetClientTeam(client) == 2 && 
           IsPlayerAlive(client));
}