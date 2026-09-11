#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ArrayList g_hJoinQueue;

enum struct QueueInfo
{
    int userid;
    int queuetype;
    int jointime;
}

public Plugin myinfo = 
{
    name = "L4D2 Join Queue System",
    author = "KevonLin",
    description = "Advanced team queue management system",
    version = "1.0",
    url = "https://github.com/KevonLin"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_join", Command_JoinMenu);
    
    g_hJoinQueue = new ArrayList(sizeof(QueueInfo));
}

public Action Timer_ShowMenu(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if(client && IsClientInGame(client))
    {
        ShowJoinMenu(client);
    }
    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    RemoveFromQueue(client);
    TryFillSlots();
}

public Action Command_JoinMenu(int client, int args)
{
    if(GetClientTeam(client) != TEAM_SPECTATOR)
    {
        CPrintToChat(client, "{green}[SM] {default}你已在游戏中! ");
        return Plugin_Handled;
    }
    if(!client || !IsClientInGame(client)) return Plugin_Handled;
    
    ShowJoinMenu(client);
    return Plugin_Handled;
}

void ShowJoinMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Join);
    menu.SetTitle("选择加入队列：");
    
    menu.AddItem("1", "通用队列");
    menu.AddItem("2", "生还队列");
    menu.AddItem("3", "特感队列");
    menu.AddItem("4", "继续旁观");
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Join(Menu menu, MenuAction action, int client, int param)
{
    if(action == MenuAction_Select && IsClientInGame(client))
    {
        char info[8];
        menu.GetItem(param, info, sizeof(info));
        
        switch(info[0])
        {
            case '1': AddToQueue(client, 1);
            case '2': AddToQueue(client, 2);
            case '3': AddToQueue(client, 3);
            case '4': return 0;
        }
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void AddToQueue(int client, int queuetype)
{
    RemoveFromQueue(client);
    
    QueueInfo info;
    info.userid = GetClientUserId(client);
    info.queuetype = queuetype;
    info.jointime = GetTime();
    
    g_hJoinQueue.PushArray(info);
    
    TryFillSlots();
}

void RemoveFromQueue(int client)
{
    int userid = GetClientUserId(client);
    
    for(int i = g_hJoinQueue.Length-1; i >= 0; i--)
    {
        QueueInfo info;
        g_hJoinQueue.GetArray(i, info);
        if(info.userid == userid)
        {
            g_hJoinQueue.Erase(i);
        }
    }
}

void TryFillSlots()
{
    // 检查生还者空位
    int survivorSlots = FindEmptySurvivorSlots();
    if(survivorSlots > 0)
    {
        AttemptFillTeam(TEAM_SURVIVOR);
    }
    
    // 检查特感空位
    int infectedSlots = FindEmptyInfectedSlots();
    if(infectedSlots > 0)
    {
        AttemptFillTeam(TEAM_INFECTED);
    }
}

void AttemptFillTeam(int team)
{
    ArrayList candidates = new ArrayList(sizeof(QueueInfo));
    
    // 收集符合条件的候选人
    for(int i = 0; i < g_hJoinQueue.Length; i++)
    {
        QueueInfo info;
        g_hJoinQueue.GetArray(i, info);
        
        if((team == TEAM_SURVIVOR && (info.queuetype == 1 || info.queuetype == 2)) ||
           (team == TEAM_INFECTED && (info.queuetype == 1 || info.queuetype == 3)))
        {
            candidates.PushArray(info);
        }
    }
    
    // 按加入时间排序
    candidates.SortCustom(SortByJoinTime);
    
    // 尝试添加玩家
    for(int i = 0; i < candidates.Length; i++)
    {
        QueueInfo info;
        candidates.GetArray(i, info);
        
        int client = GetClientOfUserId(info.userid);
        if(client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR)
        {
            if(team == TEAM_SURVIVOR && FindEmptySurvivorSlots() > 0)
            {
                AddToSurvivors(client);
                RemoveFromQueue(client);
                break;
            }
            else if(team == TEAM_INFECTED && FindEmptyInfectedSlots() > 0)
            {
                AddToInfected(client);
                RemoveFromQueue(client);
                break;
            }
        }
    }
    
    delete candidates;
}

int SortByJoinTime(int index1, int index2, Handle array, Handle hndl)
{
    QueueInfo info1, info2;
    GetArrayArray(array, index1, info1);
    GetArrayArray(array, index2, info2);
    
    return info1.jointime - info2.jointime;
}

int FindSurvivorBot()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
        {
            return i;
        }
    }
    return -1;
}

int FindEmptySurvivorSlots()
{
    return GetConVarInt(FindConVar("survivor_limit")) - GetTeamHumanCount(TEAM_SURVIVOR);
}

int FindEmptyInfectedSlots()
{
    return GetConVarInt(FindConVar("z_max_player_zombies")) - GetTeamHumanCount(TEAM_INFECTED);
}

void AddToSurvivors(int client)
{
    int bot = FindSurvivorBot();
    if(bot != -1)
    {
        ChangeClientTeam(client, 0);
        L4D_SetHumanSpec(bot, client);
        L4D_TakeOverBot(client);
    }
}

void AddToInfected(int client)
{
    ChangeClientTeam(client, TEAM_INFECTED);
}

stock int GetTeamHumanCount(int team)
{
    int count = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
        {
            count++;
        }
    }
    return count;
}