#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "2.0"
#define MAXENTITIES 2048
#define PREFIX "[TankSwap]"

// 控制权转移记录
int g_iTransferCount[MAXENTITIES];
int g_iFirstTank = INVALID_ENT_REFERENCE;
bool g_bRoundEnd;

// 管理员豁免等级
int g_iAdminImmunity[MAXPLAYERS+1];

public Plugin myinfo = 
{
    name = "L4D2 Tank Control Simplified",
    author = "AtomicStryker, KevonLin",
    description = "Tank控制权转移核心功能",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    
    RegAdminCmd("sm_taketank", Command_TakeTank, ADMFLAG_GENERIC);
    RegConsoleCmd("sm_tankmenu", Command_TankMenu);
    
    LoadTranslations("common.phrases");
}

public void OnMapStart()
{
    g_iFirstTank = INVALID_ENT_REFERENCE;
    g_bRoundEnd = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bRoundEnd = true;
}

public void OnClientPostAdminCheck(int client)
{
    g_iAdminImmunity[client] = GetUserFlagBits(client);
}

// 核心功能：Tank生成处理
public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if(g_bRoundEnd) return;
    
    int tank = GetClientOfUserId(event.GetInt("userid"));
    if(IsValidTank(tank))
    {
        // 记录第一个Tank
        if(g_iFirstTank == INVALID_ENT_REFERENCE)
        {
            g_iFirstTank = EntIndexToEntRef(tank);
        }
        
        // 初始化转移次数
        g_iTransferCount[tank] = 0;
        CreateTimer(1.0, Timer_ShowMenu, GetClientUserId(tank));
    }
}

public Action Timer_ShowMenu(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && IsValidTank(client))
    {
        ShowControlMenu(client); // 假设ShowControlMenu给这个玩家显示菜单，允许转移控制权给他人。
    }
    return Plugin_Handled;
}

// 显示控制菜单
public Action Command_TankMenu(int client, int args)
{
    if(client && IsClientInGame(client) && !g_bRoundEnd)
    {
        ShowControlMenu(client);
    }
    return Plugin_Handled;
}

void ShowControlMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Transfer);
    menu.SetTitle("转移Tank控制权");
    
    char sInfo[8], sDisplay[32];
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidTarget(i, client))
        {
            Format(sInfo, sizeof(sInfo), "%d", GetClientUserId(i));
            GetClientName(i, sDisplay, sizeof(sDisplay));
            menu.AddItem(sInfo, sDisplay);
        }
    }
    
    menu.ExitButton = true;
    menu.Display(client, 20);
}

public int MenuHandler_Transfer(Menu menu, MenuAction action, int client, int param)
{
    if(action == MenuAction_Select)
    {
        char sInfo[32];
        menu.GetItem(param, sInfo, sizeof(sInfo));
        int target = GetClientOfUserId(StringToInt(sInfo));
        
        if(IsValidTarget(target, client))
            TransferControl(client, target);
    }
    delete menu;
    return 0;
}

// 转移控制权核心逻辑
void TransferControl(int oldOwner, int newOwner)
{
    int tank = EntRefToEntIndex(g_iFirstTank);
    if(!IsValidTank(tank)) return;
    
    // 转移次数检查
    if(g_iTransferCount[tank] >= 1)
    {
        PrintToChat(oldOwner, "%s 该Tank本回合无法再转移", PREFIX);
        return;
    }
    
    // 执行转移
    L4D_ReplaceTank(oldOwner, newOwner);
    g_iTransferCount[tank]++;
    PrintToChatAll("%s %N 将控制权转移给 %N", PREFIX, oldOwner, newOwner);
}

// 管理员接管指令
public Action Command_TakeTank(int client, int args)
{
    if(!client) return Plugin_Handled;
    
    int tank = EntRefToEntIndex(g_iFirstTank);
    if(!IsValidTank(tank))
    {
        ReplyToCommand(client, "%s 当前没有可接管的Tank", PREFIX);
        return Plugin_Handled;
    }
    
    int currentOwner = GetEntPropEnt(tank, Prop_Send, "m_hOwnerEntity");
    if(!IsValidClient(currentOwner))
    {
        L4D_ReplaceTank(0, client);
        PrintToChatAll("%s 管理员 %N 接管了控制权", PREFIX, client);
        return Plugin_Handled;
    }
    
    // 豁免等级检查
    if(g_iAdminImmunity[client] <= g_iAdminImmunity[currentOwner])
    {
        ReplyToCommand(client, "%s 权限不足", PREFIX);
        return Plugin_Handled;
    }
    
    L4D_ReplaceTank(currentOwner, client);
    PrintToChatAll("%s 管理员 %N 强制接管", PREFIX, client);
    return Plugin_Handled;
}

// 验证函数
bool IsValidTank(int entity)
{
    return (IsValidEntity(entity) && 
           GetEntProp(entity, Prop_Send, "m_zombieClass") == 8);
}

bool IsValidTarget(int client, int requester)
{
    return (client != requester &&
           IsClientInGame(client) &&
           GetClientTeam(client) == 3 &&
           IsPlayerAlive(client) &&
           !IsFakeClient(client));
}

bool IsValidClient(int client)
{
    return (1 <= client <= MaxClients) && IsClientInGame(client);
}