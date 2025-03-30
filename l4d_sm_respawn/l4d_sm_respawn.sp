#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <topmenus>
#include <clientprefs>
#include <left4dhooks>

#define PLUGIN_VERSION "2.3"

Handle hTopMenu;
Handle g_hCookie;

ConVar g_hGiveMedkit;
ConVar g_hGiveMedicine;

enum TeleportState {
    TS_None,
    TS_SelectTarget,
    TS_SelectDestination
}

enum PlayerMenuType {
    MenuType_None,
    MenuType_Respawn,
    MenuType_Teleport,
    MenuType_TeleportTo
}

TeleportState g_eTeleportState[MAXPLAYERS+1];
int g_iTeleportTarget[MAXPLAYERS+1];

public Plugin myinfo = {
    name = "L4D2 Respawn",
    author = "KevonLin",
    description = "复活/传送/传召玩家功能",
    version = PLUGIN_VERSION,
    url = "https://github.com/KevonLin"
};

public void OnPluginStart() {
    LoadTranslations("common.phrases");
    
    // 注册客户端Cookie
    g_hCookie = RegClientCookie("l4d_respawn_menu", "Menu Type Storage", CookieAccess_Private);
    SetCookieMenuItem(CookieMenuHandler, 0, "菜单设置");
    
    g_hGiveMedkit = CreateConVar("sm_respawn_medkit", "0", "复活后给予医疗包 (0=关闭, 1=启用)", _, true, 0.0, true, 1.0);
    g_hGiveMedicine = CreateConVar("sm_respawn_medicine", "0", "复活后给予药品 (0=关闭, 1=药丸, 2=肾上腺素)", _, true, 0.0, true, 2.0);

    RegAdminCmd("sm_respawn", Cmd_Respawn, ADMFLAG_SLAY, "复活玩家");
    RegAdminCmd("sm_tpmenu", Cmd_TeleportMenu, ADMFLAG_SLAY, "打开传送菜单");

    HookEvent("round_start", Event_RoundStart);
    
    AutoExecConfig(true, "l4d2_respawn_system");
    
    if (LibraryExists("adminmenu")) {
        TopMenu topmenu = GetAdminTopMenu();
        OnAdminMenuReady(topmenu);
    }
}

public void OnPluginEnd() {
    if (g_hCookie != null) {
        CloseHandle(g_hCookie);
    }
}

public void CookieMenuHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen) {
    if (action == CookieMenuAction_DisplayOption) {
        Format(buffer, maxlen, "复活系统菜单设置");
    }
}

public void OnAdminMenuReady(Handle topmenu) {
    if (topmenu == hTopMenu) return;
    
    hTopMenu = topmenu;
    TopMenuObject category = FindTopMenuCategory(hTopMenu, "PlayerCommands");
    
    if (category != INVALID_TOPMENUOBJECT) {
        AddToTopMenu(hTopMenu, "L4D2Respawn", TopMenuObject_Item, AdminMenu_Respawn, 
                    category, "sm_respawn", ADMFLAG_SLAY);
    }
}

public void AdminMenu_Respawn(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, 
                            int param, char[] buffer, int maxlength) {
    if (action == TopMenuAction_DisplayOption) {
        Format(buffer, maxlength, "复活/传送");
    } else if (action == TopMenuAction_SelectOption) {
        ShowMainMenu(param);
    }
}

void ShowMainMenu(int client) {
    Menu menu = new Menu(MainMenuHandler);
    menu.SetTitle("复活/传送玩家");
    menu.AddItem("respawn", "复活玩家");
    menu.AddItem("teleport", "传送玩家");
    menu.AddItem("teleportto", "传召玩家");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int param) {
    if (action == MenuAction_End) {
        delete menu;
    } else if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param, info, sizeof(info));
        
        if (StrEqual(info, "respawn")) {
            ShowPlayerMenu(client, MenuType_Respawn);
        } else if (StrEqual(info, "teleport")) {
            ShowPlayerMenu(client, MenuType_Teleport);
        } else if (StrEqual(info, "teleportto")) {
            g_eTeleportState[client] = TS_SelectTarget;
            ShowPlayerMenu(client, MenuType_TeleportTo);
        }
    } else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack) {
        RedisplayAdminMenu(hTopMenu, client);
    }
    return 0;
}

void ShowPlayerMenu(int client, PlayerMenuType menuType) {
    char sValue[8];
    IntToString(view_as<int>(menuType), sValue, sizeof(sValue));
    SetClientCookie(client, g_hCookie, sValue);
    
    Menu menu = new Menu(PlayerMenuHandler);
    menu.SetTitle("选择玩家:");
    menu.ExitBackButton = true;
    
    char userid[12], name[MAX_NAME_LENGTH], display[MAX_NAME_LENGTH+12];
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            IntToString(GetClientUserId(i), userid, sizeof(userid));
            GetClientName(i, name, sizeof(name));
            
            if (menuType == MenuType_TeleportTo && g_eTeleportState[client] == TS_SelectDestination) {
                Format(display, sizeof(display), "%s (目标位置)", name);
            } else {
                strcopy(display, sizeof(display), name);
            }
            
            menu.AddItem(userid, display);
        }
    }
    
    if (menu.ItemCount == 0) {
        menu.AddItem("", "没有可用玩家", ITEMDRAW_DISABLED);
    }
    
    menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
}

public int PlayerMenuHandler(Menu menu, MenuAction action, int client, int param) {
    if (action == MenuAction_End) {
        delete menu;
        return 0;
    }
    
    if (action == MenuAction_Cancel) {
        if (param == MenuCancel_ExitBack) {
            ShowMainMenu(client);
        }
        return 0;
    }
    
    if (action != MenuAction_Select) return 0;
    
    char userid[12], sValue[8];
    menu.GetItem(param, userid, sizeof(userid));
    int target = GetClientOfUserId(StringToInt(userid));
    
    if (!target || !IsClientInGame(target)) {
        ShowMainMenu(client);
        return 0;
    }
    
    GetClientCookie(client, g_hCookie, sValue, sizeof(sValue));
    PlayerMenuType menuType = view_as<PlayerMenuType>(StringToInt(sValue));
    
    switch (menuType) {
        case MenuType_Respawn: {
            RespawnPlayer(client, target);
            ShowPlayerMenu(client, menuType);
        }
        case MenuType_Teleport: {
            TeleportPlayerToAdmin(client, target);
            ShowPlayerMenu(client, menuType);
        }
        case MenuType_TeleportTo: {
            HandleTeleportTo(client, target);
        }
    }
    return 0;
}

void HandleTeleportTo(int client, int target) {
    switch (g_eTeleportState[client]) {
        case TS_SelectTarget: {
            g_iTeleportTarget[client] = target;
            g_eTeleportState[client] = TS_SelectDestination;
            ShowPlayerMenu(client, MenuType_TeleportTo);
        }
        case TS_SelectDestination: {
            float pos[3];
            GetClientAbsOrigin(target, pos);
            pos[2] += 5.0; // 防止卡地板
            
            TeleportEntity(g_iTeleportTarget[client], pos, NULL_VECTOR, NULL_VECTOR);
            LogAction(client, target, "\"%L\" 将 %N 传送到 %N 的位置", 
                     client, g_iTeleportTarget[client], target);
            
            g_eTeleportState[client] = TS_None;
            ShowMainMenu(client);
        }
    }
}

void RespawnPlayer(int client, int target) {
    if (GetClientTeam(target) == 2) {
        // 使用 left4dhooks 原生函数复活生还者
        L4D_RespawnPlayer(target);
        GiveItems(target);

        float pos[3];
        if (target != client && GetTeleportEndPoint(client, pos)) {
            TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
            LogAction(client, target, "\"%L\" 传送了 \"%L\"", client, target);
        }
        LogAction(client, target, "\"%L\" 复活了生还者 \"%L\"", client, target);
    } else if (GetClientTeam(target) == 3) {
        // 特感复活逻辑（仅限L4D2）
        if (IsL4D2()) {
            L4D_State_Transition(target, 8);    // 进入死亡状态
            L4D_BecomeGhost(target);       // 成为幽灵
            L4D_State_Transition(target, 6);     // 进入活跃状态
            L4D_BecomeGhost(target);      // 退出幽灵状态
            LogAction(client, target, "\"%L\" 复活了特感 \"%L\"", client, target);
        }
    }
}

void TeleportPlayerToAdmin(int client, int target) {
    float pos[3];
    if (GetTeleportEndPoint(client, pos)) {
        TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
        LogAction(client, target, "\"%L\" 传送了 \"%L\"", client, target);
    } else {
        PrintToChat(client, "[\x04SM\x01] 传送点获取失败");
    }
}

bool GetTeleportEndPoint(int client, float pos[3]) {
    float eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    Handle trace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter);
    if (!TR_DidHit(trace)) {
        delete trace;
        return false;
    }
    
    TR_GetEndPosition(pos, trace);
    delete trace;
    
    // 调整位置防止卡墙
    pos[2] += 10.0;
    return true;
}

public bool TraceFilter(int entity, int mask) {
    return entity == 0;
}

void GiveItems(int client) {
    if (g_hGiveMedkit.IntValue == 1) {
        CheatCommand(client, "give", "first_aid_kit");
    }
    switch (g_hGiveMedicine.IntValue) {
        case 1: CheatCommand(client, "give", "pain_pills");
        case 2: CheatCommand(client, "give", "adrenaline");
    }
}

bool IsL4D2() {
    char game[32];
    GetGameFolderName(game, sizeof(game));
    return StrEqual(game, "left4dead2");
}

void CheatCommand(int client, const char[] command, const char[] argument) {
    int flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, argument);
    SetCommandFlags(command, flags);
}

public Action Cmd_Respawn(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "用法: sm_respawn <玩家名>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_TARGET_LENGTH];
    GetCmdArg(1, targetName, sizeof(targetName));
    
    int target = FindTarget(client, targetName, true, false);
    if (target == -1) return Plugin_Handled;
    
    RespawnPlayer(client, target);
    return Plugin_Handled;
}

public Action Cmd_TeleportMenu(int client, int args) {
    ShowMainMenu(client);
    return Plugin_Handled;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_eTeleportState[i] = TS_None;
        g_iTeleportTarget[i] = 0;
    }
}