#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <colors>
#include <left4dhooks>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#include <basecomm>

#define MAX_MAPS 128

Handle
	g_hVote = null;

ConVar
	sm_votemenu_enable,
	sm_votemenu_timedelay,
	sm_votemenu_givehp,
	sm_votemenu_pills,
	sm_votemenu_changeslots,
	sm_votemenu_changecustommaps,
	sm_votemenu_ban,
	sm_votemenu_kick,
	sm_votemenu_mute,
	sm_votemenu_toggleaddons,
	g_cvMaxPlayers,
	cvarAddons;

char
	g_customMapList[MAX_MAPS][PLATFORM_MAX_PATH],
	g_sVoteCustomMap[MAX_NAME_LENGTH];

int
	g_customMapCount,
	g_selectClient,
	g_iNewMaxPlayers,
	g_cvarAddons;

bool
	g_bVoteEnable[MAXPLAYERS + 1];

enum voteType
{
	none,
	hp,
	pills,
	slots,
	custommap,
	ban,
	kick,
	mute,
	addons
}

voteType g_voteType = none;

public Plugin myinfo =
{
	name = "Advanced Vote Menu",
	author = "Kevonlin & Modified by AI",
	description = "Enhanced voting system for L4D2",
	version = "2.4.0",
	url = ""
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	EngineVersion iEngine = GetEngineVersion();
	if (iEngine != Engine_Left4Dead2) {
		strcopy(sError, iErrMax, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadThirdPartyMaps();
	
	// ConVar 注册
	g_cvMaxPlayers = FindConVar("sv_maxplayers");
	sm_votemenu_enable = CreateConVar("sm_votemenu_enable", "1", "启用投票菜单");
	sm_votemenu_timedelay = CreateConVar("sm_votemenu_timedelay", "30.0", "投票冷却时间");
	sm_votemenu_givehp = CreateConVar("sm_votemenu_givehp", "1", "启用恢复生命投票");
	sm_votemenu_pills = CreateConVar("sm_votemenu_pills", "1", "启用药丸发放投票");
	sm_votemenu_changeslots = CreateConVar("sm_votemenu_changeslots", "1", "启用人数修改");
	sm_votemenu_changecustommaps = CreateConVar("sm_votemenu_changecustommaps", "1", "启用第三方地图投票");
	sm_votemenu_ban = CreateConVar("sm_votemenu_ban", "1", "启用封禁投票");
	sm_votemenu_kick = CreateConVar("sm_votemenu_kick", "1", "启用踢出投票");
	sm_votemenu_mute = CreateConVar("sm_votemenu_mute", "1", "启用静音投票");
	sm_votemenu_toggleaddons = CreateConVar("sm_votemenu_toggleaddons", "1", "启用MOD切换");

	cvarAddons = FindConVar("l4d2_addons_eclipse");

	RegConsoleCmd("sm_votemenu", Command_Votes);
	RegConsoleCmd("sm_votes", Command_Votes);

	AutoExecConfig(true, "l4d2_votemenu");
}

void LoadThirdPartyMaps()
{
	char mapPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapPath, sizeof(mapPath), "../../addons"); // 修改为addons目录
	
	Handle dir = OpenDirectory(mapPath);
	if(dir == null) return;

	char mapName[128], fullPath[256];
	FileType fileType;
	
	while(ReadDirEntry(dir, mapName, sizeof(mapName), fileType))
	{
		if(fileType == FileType_File && StrContains(mapName, ".vpk", false) != -1) // 检测VPK文件
		{
			Format(fullPath, sizeof(fullPath), "%s/%s", mapPath, mapName);
			if(FileExists(fullPath))
			{
				strcopy(g_customMapList[g_customMapCount], PLATFORM_MAX_PATH, mapName);
				g_customMapCount++;
				if(g_customMapCount >= MAX_MAPS) break;
			}
		}
	}
	CloseHandle(dir);
}

public Action Command_Votes(int client, int args)
{
	if(!sm_votemenu_enable.BoolValue || !IsValidClient(client)) 
		return Plugin_Handled;

	ShowMainMenu(client);
	return Plugin_Handled;
}

void ShowMainMenu(int client)
{
	Menu menu = new Menu(MainMenuHandler);
	menu.SetTitle("高级投票系统");
	
	if(sm_votemenu_givehp.BoolValue) menu.AddItem("hp", "恢复全员生命值");
	if(sm_votemenu_pills.BoolValue) menu.AddItem("pills", "发放药丸");
	if(sm_votemenu_changeslots.BoolValue) menu.AddItem("slots", "修改服务器人数");
	if(sm_votemenu_changecustommaps.BoolValue) menu.AddItem("map", "更换第三方地图");
	if(sm_votemenu_kick.BoolValue) menu.AddItem("kick", "踢出玩家");
	if(sm_votemenu_ban.BoolValue) menu.AddItem("ban", "封禁玩家");
	if(sm_votemenu_mute.BoolValue) menu.AddItem("mute", "静音玩家");
	if(sm_votemenu_toggleaddons.BoolValue) menu.AddItem("mod", "切换服务器MOD");

	menu.Display(client, 20);
}

// ... 其他菜单处理函数保持相同结构 ...

void ShowSpectateMenu(int client)
{
	Menu menu = new Menu(SpectateMenuHandler);
	menu.SetTitle("设置服务器最大人数");
	menu.AddItem("8", "8人");
	menu.AddItem("12", "12人");
	menu.AddItem("14", "14人");
	menu.AddItem("16", "16人");
	menu.Display(client, 20);
}

public int SpectateMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(param, info, sizeof(info));
		g_iNewMaxPlayers = StringToInt(info);
		StartVoteProcess(client, slots);
	}
	else if (action == MenuAction_End) delete menu;
	return 0;
}

bool StartVote(int client)
{
	if (!IsValidClient(client)) return false;
	
	char title[128];
	switch(g_voteType)
	{
		case hp: Format(title, sizeof(title), "恢复所有玩家的生命值?");
		case pills: Format(title, sizeof(title), "给所有幸存者发放药丸?");
		case slots: Format(title, sizeof(title), "设置服务器人数为%d?", g_iNewMaxPlayers);
		case custommap: Format(title, sizeof(title), "更换地图到 %s?", g_sVoteCustomMap);
		case kick: Format(title, sizeof(title), "踢出玩家 %N?", g_selectClient);
		case ban: Format(title, sizeof(title), "封禁玩家 %N 30分钟?", g_selectClient);
		case mute: Format(title, sizeof(title), "静音玩家 %N 30分钟?", g_selectClient);
		case addons: Format(title, sizeof(title), "%s 服务器MOD?", GetConVarBool(cvarAddons) ? "禁用" : "启用");
	}
	
	g_hVote = CreateBuiltinVote(VoteHandler, BuiltinVoteType_Custom_YesNo);
	SetBuiltinVoteArgument(g_hVote, title);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
	
	int players[MAXPLAYERS], count;
	for(int i=1; i<=MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i)) players[count++] = i;
	
	DisplayBuiltinVote(g_hVote, players, count, 20);
	return true;
}

public void VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if(item_info[0][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes/2))
	{
		DisplayBuiltinVotePass(vote, "投票通过!");
		CreateTimer(3.0, Timer_ExecuteVoteAction); // 延迟3秒执行
	}
	else DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action Timer_ExecuteVoteAction(Handle timer)
{
	switch(g_voteType)
	{
		case hp: RecoveryHealth();
		case pills: GivePillsToSurvivors();
		case slots: ChangeMaxPlayers();
		case custommap: ChangeCustomMap();
		case kick: KickPlayer();
		case ban: BanPlayer();
		case mute: MutePlayer();
		case addons: ToggleAddons();
	}
	return Plugin_Stop;
}

void RecoveryHealth()
{
	int flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			FakeClientCommand(i, "give health");
			SetSurvivorPermanentHealth(i, MaxHP);
			SetSurvivorTempHealth(i, 0);
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
	CPrintToChatAll("{blue}[{default}Vote{blue}] {olive}All survivors {default}has restored.");
}

void GivePillsToSurvivors()
{
	int flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidPlayerIndex(i)) continue;
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if(HasPills(i))
			{
				continue;
			}
			FakeClientCommand(i, "give pain_pills");
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
	CPrintToChatAll("{blue}[{default}Vote{blue}] {olive}Pills {default}has distributed to {blue}All survivors");
}

void ChangeMaxPlayers()
{
	SetConVarInt(g_cvMaxPlayers, g_iNewMaxPlayers);
	L4D_LobbyUnreserve(); // 移除大厅匹配
	CPrintToChatAll("{green}[投票] {default}服务器最大人数已设置为 %d", g_iNewMaxPlayers);
}

void ChangeCustomMap()
{
	char mapName[128];
	strcopy(mapName, sizeof(mapName), g_sVoteCustomMap);
	ReplaceString(mapName, sizeof(mapName), ".vpk", "", false); // 移除.vpk扩展名
	ServerCommand("changelevel %s", mapName);
}

void BanPlayer()
{
	if (!IsClientInGame(g_selectClient) || IsFakeClient(g_selectClient)) return;
	// BanClient(g_selectClient, 30, BANFLAG_AUTO, "Vote", "You habe been banned for 30 min.", "sm_ban");
	ServerCommand("sm_ban %i 30 Vote", g_selectClient);
	CPrintToChatAll("{blue}[{default}Vote{olive}] Player {blue}%N {default}has been banned for 30 min.", g_selectClient);
	g_selectClient = 0;
}

void KickPlayer()
{
	if (!IsClientInGame(g_selectClient) || IsFakeClient(g_selectClient)) return;
	KickClient(g_selectClient, "You have been vote off.");
	CPrintToChatAll("{blue}[{default}Vote{olive}] Player {blue}%N {default}has been voted off.", g_selectClient);
	g_selectClient = 0;
}

void MutePlayer()
{
	if (!IsClientInGame(g_selectClient) || IsFakeClient(g_selectClient)) return;
	// SetClientListeningFlags(target, VOICE_MUTED);
	// FireOnClientMute(target, true);
	// BaseComm_SetClientMute(g_selectClient, true);
	ServerCommand("sm_mute %i 30 Vote", g_selectClient);
	CPrintToChatAll("{blue}[{default}Vote{olive}] Player {blue}%N {default}has been muted.", g_selectClient);
	g_selectClient = 0;
}

void ToggleAddons()
{
	if (g_cvarAddons == 1 || (g_cvarAddons == -1 && IsDefaultEnableMod()))
	{
		SetConVarBool(cvarAddons, false);
		CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Addons {default}has toggle to {blue}disalbe");
	}
	else if (g_cvarAddons == 0 || (g_cvarAddons == -1 && !IsDefaultEnableMod()))
	{
		SetConVarBool(cvarAddons, true);
		CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Addons {default}has toggle to {blue}enable");
	}

	CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Map will restart after {blue}3s");
	CreateTimer(3.0, RestartMap, _);
}

// ... 其他功能函数保持相同实现 ...

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool IsValidPlayerIndex(int client)
{
	return ( (client > 0) && (client <= MaxClients) );
}

bool IsDefaultEnableMod()
{
	static ConVar mp_gamemode;
	
	if (mp_gamemode == null)
	{
		mp_gamemode = FindConVar("mp_gamemode");
	}
	
	char sGamemode[16];
	mp_gamemode.GetString(sGamemode, sizeof(sGamemode));
	
	return strcmp(sGamemode, "coop") == 0;
}

public Action RestartMap(Handle timer, any client)
{
	char currentMap[256];
	GetCurrentMap(currentMap, 256);
	ServerCommand("changelevel %s", currentMap);

	return Plugin_Continue;
}