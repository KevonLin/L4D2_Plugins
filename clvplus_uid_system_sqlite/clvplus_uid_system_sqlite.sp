#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

#define MAXUIDSIZE 64
#define RETRYTIME 3.0

// #define DEBUG
#define LOGUID

ConVar
	g_cvarEnable,
	g_cvarNowMaxUID,
	cvarReadyUpCfgName;

bool
	// isStartInGame[MAXPLAYERS + 1],
	g_bCvarEnable,
	IsConfoglAvailable;

int
	g_icvarNowMaxUID,
	PlayerUID[MAXPLAYERS + 1],
	PlayerGameCount[MAXPLAYERS + 1],
	RoundCount[MAXPLAYERS + 1];

float
	startTime,
	endTime,
	timeDistance,
	PlayerGameTime[MAXPLAYERS + 1];

char
	logFile[256],
	g_sCvarCfgName[64];

public Plugin myinfo = {
	name = "UID系统",
	author = "Kevonlin",
	description = "",
	version = "1.2",
	url = "https://steamcommunity.com/profiles/76561199044101393/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead2 ) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success; 
}

public void OnPluginStart() {
	g_cvarEnable = CreateConVar("clvplus_uid_enable", "1", "Plugin enable", 0, true, 0.0, true, 1.0);
	g_cvarNowMaxUID = CreateConVar("clvplus_uid_count", "100", "Max UID of server now", 0, true, 0.0);

	AutoExecConfig(true, "clvplus_uid_system");

	GetCvar();

	if (!g_bCvarEnable) return;

	RegConsoleCmd("sm_uid", UidCommand);
	RegAdminCmd("sm_setuid", SetUidCommand, ADMFLAG_ROOT);
	RegAdminCmd("sm_swapuid", SwapUidCommand, ADMFLAG_ROOT);
	RegAdminCmd("sm_refreshuid", RefreshUidCommand, ADMFLAG_ROOT);

	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/clvplus_uid_system.log");

	g_cvarEnable.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	// SetMaxUID();
	IsConfoglAvailable = LibraryExists("confogl");
}

public void OnConfigsExecuted()
{
	IsConfoglAvailable = LibraryExists("confogl");
	if (IsConfoglAvailable)
	{
		cvarReadyUpCfgName = FindConVar("l4d_ready_cfg_name");
		if(cvarReadyUpCfgName != INVALID_HANDLE)
			GetConVarString(cvarReadyUpCfgName, g_sCvarCfgName, sizeof(g_sCvarCfgName));
		else
			g_sCvarCfgName = "未加载插件";
	}
}

void GetCvar() {
	g_bCvarEnable = GetConVarBool(g_cvarEnable);
	g_icvarNowMaxUID = GetConVarInt(g_cvarNowMaxUID);
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvar();
}

public void OnMapStart() {
	RefreshUID();
}

public Action Event_RoundStart(Event hEvent, const char[] eName, bool dontBroadcast) {
	#if defined DEBUG
	LogToFile(logFile, "Event_RoundStart 被调用");
	#endif
	// 获取正在游戏玩家对局数量并且+1 获取当前时间戳
	startTime = GetGameTime();
	for (int client = 1; client <= MaxClients; client++) {
		if (IsValidPlayer(client)) {
			LoadUid(client);
			LoadTime(client);
			LoadGameCount(client);
		}
	}

	return Plugin_Continue;
}

public Action Event_RoundEnd(Event hEvent, const char[] eName, bool dontBroadcast) {
	#if defined DEBUG
	LogToFile(logFile, "Event_RoundEnd 被调用");
	#endif
	// 获取玩家对局数量和当前时间戳 保存正在游戏的玩家游戏时间和游戏对局
	endTime = GetGameTime();
	timeDistance = endTime - startTime;
	char dist[32];
	Format(dist, sizeof(dist), "%.2f", timeDistance / 3600);
	float fDistance;
	StringToFloatEx(dist, fDistance);
	#if defined DEBUG
	char sLog[256];
	Format(sLog, sizeof(sLog), "Dist = %f", fDistance);
	LogToFile(logFile, sLog);
	#endif
	
	for (int client = 1; client <= MaxClients; client++) {
		if(!(IsValidPlayer(client))) continue;
		if(!(IsPlayerGaming(client))) continue;
		// if(isStartInGame[client]) {
		PlayerGameTime[client] += fDistance;
		SaveTime(client);
		LoadTime(client);
		if (++RoundCount[client] == 2) {
			PlayerGameCount[client]++;
			RoundCount[client] = 0;
			SaveGameCount(client);
			LoadGameCount(client);
		}
		// 	isStartInGame[client] = false;
		// }
	}

	startTime = 0.0;
	endTime = 0.0;
	timeDistance = 0.0;

	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client) {
	if (!IsValidPlayer(client)) return;

	#if defined DEBUG
	LogToFile(logFile, "OnClientPostAdminCheck 被调用");
	if(IsFakeClient(client) || CheckCommandAccess(client, "", ADMFLAG_ROOT) == true) {
		return;
	}
	if(!(GetUserFlagBits(client) & ADMFLAG_GENERIC)) {
		KickClient(client, "服务器调试中...");
	}
	#endif

	// 读取UID 如果不存在则创建 创建后保存UID并重新读取UID 为玩家显示欢迎界面
	if (!(LoadUid(client))) {
		CreateNewUid(client);
	}

	RefreshUID();
	LoadTime(client);
	LoadGameCount(client);
	
	ShowWelcomePanel(client);

	CPrintToChatAll("玩家 {olive}%N{default}({olive}UID{default}:%d{default}) 加入游戏", client, PlayerUID[client]);
}

public void OnClientAuthorized(int client) {
	if (IsFakeClient(client)) return;
	CPrintToChatAll("玩家 {olive}%N{default} 正在连接...", client, PlayerUID[client]);
}

// public void OnClientPutInServer(int client) {
// 	if (IsFakeClient(client)) return;
// 	CPrintToChatAll("{blue}[{default}UID{blue}] {default}玩家 {olive}%N{default}({blue}%d{default}) 加入游戏", client, PlayerUID[client]);
// }

public Action Event_PlayerDisconnect(Event hEvent, const char[] eName, bool dontBroadcast) {
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!(IsValidPlayer(client))) return Plugin_Continue;
	CPrintToChatAll("玩家 {olive}%N{default} 离开游戏", client);
	return Plugin_Handled;
}

public Action UidCommand(int client, int args) {
	if (!IsValidPlayer(client)) return Plugin_Continue;
	// 打开UID列表
	UIDMenu(client);

	return Plugin_Continue;
}

void UIDMenu(int client){
	char sBuffer[64];
	Menu vMenu = new Menu(UIDMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "玩家 UID 列表");
	vMenu.SetTitle(sBuffer);
	
	for (int i = MaxClients; i > 0; i--) {
		if(!(IsValidPlayer(i))) continue;
		char cIndex[32];
		IntToString(i, cIndex, sizeof(cIndex));
		FormatEx(sBuffer, sizeof(sBuffer), "(%d)%N", PlayerUID[i], i);
		vMenu.AddItem(cIndex, sBuffer);
	}

	vMenu.Display(client, 30);
}

public int UIDMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Select) {
		// param2的client index
		char item[32];
		menu.GetItem(param2, item, sizeof(item));
		int target = StringToInt(item);
		ShowDetailPanel(param1, target);
	}
	return 0;
}

void ShowDetailPanel(int client, int target) {
	char sBuffer[64];
	Panel sPanel = new Panel();
	FormatEx(sBuffer, sizeof(sBuffer), "玩家 %N 的统计", target);
	sPanel.SetTitle(sBuffer);
	
	sPanel.DrawText(" ");
	FormatEx(sBuffer, sizeof(sBuffer), "游戏时长:%.2f小时", PlayerGameTime[target]);
	sPanel.DrawText(sBuffer);
	sPanel.DrawText(" ");
	FormatEx(sBuffer, sizeof(sBuffer), "游戏局数:%d场", PlayerGameCount[target]);
	sPanel.DrawText(sBuffer);

	sPanel.Send(client, DetailPanelHundler, 30);
}

void ShowWelcomePanel(int client) {
	#if defined DEBUG
	LogToFile(logFile, "ShowWelcomePanel 被调用");
	#endif
	// 欢迎界面
	char sBuffer[64];
	Panel sPanel = new Panel();
	FormatEx(sBuffer, sizeof(sBuffer), "欢迎来到求生之路托儿所");
	sPanel.SetTitle(sBuffer);
	
	sPanel.DrawText(" ");
	FormatEx(sBuffer, sizeof(sBuffer), "QQ群:643157074");
	sPanel.DrawText(sBuffer);
	sPanel.DrawText(" ");
	FormatEx(sBuffer, sizeof(sBuffer), "当前模式:%s", g_sCvarCfgName);
	sPanel.DrawText(sBuffer);
	sPanel.DrawText(" ");
	FormatEx(sBuffer, sizeof(sBuffer), "药抗模式建议游戏时长:400小时");
	sPanel.DrawText(sBuffer);
	if (!LGO_IsMatchModeLoaded()) {
		sPanel.DrawText(" ");
		FormatEx(sBuffer, sizeof(sBuffer), "使用!match加载插件");
		sPanel.DrawText(sBuffer);
	}

	sPanel.Send(client, WelcomPanelHundler, 30);
}

public Action SetUidCommand(int client, int args) {
	if (!IsValidPlayer(client)) return Plugin_Continue;
	// 设置uid

	if (args != 2) {
		ReplyToCommand(client, "[UID] Usage: sm_setuid <SteamID> <UID>");
		return Plugin_Continue;
	}

	int uid;
	GetCmdArgIntEx(2, uid);

	char SteamID[64];
	GetCmdArg(1, SteamID, sizeof(SteamID));

	//判断UID是否被使用
	if((IsUIDUsed(uid))) {
		ReplyToCommand(client, "[UID] 该UID已被使用,使用指令sm_swap");
		return Plugin_Continue;
	}

	if(!(IsSteamIDExist(SteamID))) {
		ReplyToCommand(client, "[UID] 玩家档案不存在");
		return Plugin_Continue;
	}

	if(!(UtilSetUid(SteamID, uid))) {
		return Plugin_Continue;
	}

	char sLog[256], adminID[64];
	GetClientAuthId(client, AuthId_Steam2, adminID, sizeof(adminID));
	FormatEx(sLog, sizeof(sLog), "[UID] 玩家[%s]的UID被管理员[%N]<%s>设置为:[%d]", SteamID, client, adminID, uid);
	LogToFile(logFile, sLog);
	ReplyToCommand(client, "[UID] 玩家[%s]的UID设置为:[%d]", SteamID, uid);
	return Plugin_Continue;
}

bool IsSteamIDExist(char[] SteamID) {
	Database db = GetDBInstance();
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT steamid FROM clvplus_uid WHERE steamid = '%s'", SteamID);
	DBResultSet rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to rs (error: %s)", error);
	} else {
		if (SQL_FetchRow(rs)) {
			return true;
		} else {
			return false;
		}
	}
	delete rs;
	delete db;
	return true;
}

bool UtilSetUid(const char[] SteamId, const int uid) {
	#if defined DEBUG
	LogToFile(logFile, "UtilSetUid 被调用");
	#endif

	Database db = GetDBInstance();
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE clvplus_uid SET uid = %d WHERE steamid = '%s'", uid, SteamId);
	if (!SQL_FastQuery(db, sQuery)) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return false;
	}
	RefreshUID();
	return true;
}

public Action SwapUidCommand(int client, int args) {
	if (!IsValidPlayer(client)) return Plugin_Continue;
	// 交换玩家UID
	if (args != 2) {
		ReplyToCommand(client, "[UID] Usage: sm_swapuid <uid1> <uid2>");
		return Plugin_Continue;
	}

	int uid1, uid2;
	GetCmdArgIntEx(1, uid1);
	GetCmdArgIntEx(2, uid2);

	char steamId1[64], steamId2[64];

	Database db = GetDBInstance();
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT steamid FROM clvplus_uid WHERE uid = %d", uid1);
	DBResultSet rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to rs (error: %s)", error);
		ReplyToCommand(client, "[UID] 玩家档案不存在");
	} else {
		if (SQL_FetchRow(rs)) {
			SQL_FetchString(rs, 0, steamId1, sizeof(steamId1));
		}
	}
	delete rs;
	delete db;

	db = GetDBInstance();
	FormatEx(sQuery, sizeof(sQuery), "SELECT steamid FROM clvplus_uid WHERE uid = %d", uid2);
	rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to rs (error: %s)", error);
		ReplyToCommand(client, "[UID] 玩家档案不存在");
	} else {
		if (SQL_FetchRow(rs)) {
			SQL_FetchString(rs, 0, steamId2, sizeof(steamId2));
		}
	}
	delete rs;
	delete db;

	if (!UtilsSwapUID(client, steamId1, steamId2)) {
		return Plugin_Continue;
	}

	char sLog[256], adminID[64];
	GetClientAuthId(client, AuthId_Steam2, adminID, sizeof(adminID));
	FormatEx(sLog, sizeof(sLog), "[UID] 玩家[%s]和[%s]的UID被管理员[%N]<%s>交换", steamId1, steamId2, client, adminID);
	LogToFile(logFile, sLog);
	return Plugin_Continue;
}

bool UtilsSwapUID(int client, const char[] steamId1, const char[] steamId2) {
	// 交换两个UID
	#if defined DEBUG
	LogToFile(logFile, "UtilsSwapUID 被调用");
	#endif

	int uid1, uid2;
	Database db = GetDBInstance();
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT uid FROM clvplus_uid WHERE steamid = '%s'", steamId1);
	DBResultSet rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to rs (error: %s)", error);
		ReplyToCommand(client, "[UID] 玩家1档案不存在");
		delete rs;
		delete db;
		return false;
	} else {
		if (SQL_FetchRow(rs)) {
			uid1 = SQL_FetchInt(rs, 0);
		}
		delete rs;
		delete db;
	}

	db = GetDBInstance();
	FormatEx(sQuery, sizeof(sQuery), "SELECT uid FROM clvplus_uid WHERE steamid = '%s'", steamId2);
	rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to rs (error: %s)", error);
		ReplyToCommand(client, "[UID] 玩家2档案不存在");
		delete rs;
		delete db;
		return false;
	} else {
		if (SQL_FetchRow(rs)) {
			uid2 = SQL_FetchInt(rs, 0);
		}
		delete rs;
		delete db;
	}

	db = GetDBInstance();
	FormatEx(sQuery, sizeof(sQuery), "UPDATE clvplus_uid SET uid = %d WHERE steamid = '%s'", 0, steamId1);
	if (!SQL_FastQuery(db, sQuery)) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return false;
	}

	db = GetDBInstance();
	FormatEx(sQuery, sizeof(sQuery), "UPDATE clvplus_uid SET uid = %d WHERE steamid = '%s'", uid1, steamId2);
	if (!SQL_FastQuery(db, sQuery)) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return false;
	}

	db = GetDBInstance();
	FormatEx(sQuery, sizeof(sQuery), "UPDATE clvplus_uid SET uid = %d WHERE steamid = '%s'", uid2, steamId1);
	if (!SQL_FastQuery(db, sQuery)) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return false;
	}

	RefreshUID();

	ReplyToCommand(client, "[UID] 玩家UID已交换");
	return true;
}
public Action RefreshUidCommand(int client, int args) {
	RefreshUID();
	return Plugin_Continue;
}

void RefreshUID() {
	for (int i = 1; i <= MaxClients; i++) {
		if (!(IsValidPlayer(i))) continue;
		LoadUid(i);
	}
}

public int DetailPanelHundler(Handle menu, MenuAction action, int param1, int param2) { return 1; }
public int WelcomPanelHundler(Handle menu, MenuAction action, int param1, int param2) { return 1; }

// =======================================
// ||			SQL	Utils				||
// =======================================
Database GetDBInstance() {
	#if defined DEBUG
	LogToFile(logFile, "GetDBInstance 被调用");
	#endif

	char error[255];

	Database db = SQLite_UseDatabase("clvplus_uid_system", error, sizeof(error));
	if (db == INVALID_HANDLE)
		SetFailState(error);

	SQL_LockDatabase(db);
	SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS clvplus_uid (uid INTTGER PRIMARY KEY ON CONFLICT REPLACE, steamid TEXT, gametime REAL, gamecount INTEGER, used INTEGER);");
	SQL_UnlockDatabase(db);

	return db;
}

void SaveTime(int client) {
	// 保存游戏时间到数据库
	#if defined DEBUG
	LogToFile(logFile, "SaveTime 被调用");
	#endif

	Database db = GetDBInstance();
	char sQuery[256], SteamId[64];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	FormatEx(sQuery, sizeof(sQuery), "UPDATE clvplus_uid SET gametime = %f WHERE steamid = '%s'", PlayerGameTime[client], SteamId);
	if (!SQL_FastQuery(db, sQuery)) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
	}
}

void LoadTime(int client) {
	// 从数据库读取玩家游戏时间
	#if defined DEBUG
	LogToFile(logFile, "LoadTime 被调用");
	#endif
	Database db = GetDBInstance();
	DBResultSet rs;
	char sQuery[256], SteamId[64];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	FormatEx(sQuery, sizeof(sQuery), "SELECT gametime FROM clvplus_uid WHERE steamid = '%s'", SteamId);
	rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to rs (error: %s)", error);
		delete rs;
		delete db;
	} else {
		if (SQL_FetchRow(rs)) {
			PlayerGameTime[client] = SQL_FetchFloat(rs, 0);
			delete rs;
			delete db;
		}
	}
	delete rs;
	delete db;
}

void SaveGameCount(int client) {
	// 保存游戏对局数量到数据库
	#if defined DEBUG
	LogToFile(logFile, "SaveGameCount 被调用");
	#endif

	Database db = GetDBInstance();
	char sQuery[256], SteamId[64];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	FormatEx(sQuery, sizeof(sQuery), "UPDATE clvplus_uid SET gamecount = %d WHERE steamid = '%s'", PlayerGameCount[client], SteamId);
	if (!SQL_FastQuery(db, sQuery)) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
	}
}

void LoadGameCount(int client) {
	// 从数据库读取玩家游戏对局数量
	#if defined DEBUG
	LogToFile(logFile, "LoadGameCount 被调用");
	#endif
	Database db = GetDBInstance();
	DBResultSet rs;
	char sQuery[256], SteamId[64];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	FormatEx(sQuery, sizeof(sQuery), "SELECT gamecount FROM clvplus_uid WHERE steamid = '%s'", SteamId);
	rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to rs (error: %s)", error);
		delete rs;
		delete db;
	} else {
		if (SQL_FetchRow(rs)) {
			PlayerGameCount[client] = SQL_FetchInt(rs, 0);
			delete rs;
			delete db;
		}
	}
	delete rs;
	delete db;
}

bool LoadUid(int client) {
	#if defined DEBUG
	LogToFile(logFile, "LoadUid 被调用");
	#endif
	if(!IsValidPlayer(client)) return false;
	// 从数据库读取玩家UID
	Database db = GetDBInstance();
	DBResultSet rs;
	char sQuery[256], SteamId[64];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	FormatEx(sQuery, sizeof(sQuery), "SELECT uid FROM clvplus_uid WHERE steamid = '%s'", SteamId);
	rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to rs (error: %s)", error);
		delete rs;
		delete db;
		return false;
	} else {
		if (SQL_FetchRow(rs)) {
			PlayerUID[client] = SQL_FetchInt(rs, 0);
			delete rs;
			delete db;
			return true;
		}
	}
	delete rs;
	delete db;
	return false;
}

void CreateNewUid(int client) {
	#if defined DEBUG
	LogToFile(logFile, "CreateNewUid 被调用");
	#endif

	Database db = GetDBInstance();
	int newID = GetCreateUID();
	char sQuery[256], SteamId[64];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	#if defined LOGUID
	LogToFile(logFile, "%N<%s>获取UID:%d", client, SteamId, newID);
	#endif
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO clvplus_uid (uid, steamid, gametime, gamecount, used) VALUES (%d, '%s', 0, 0, '1')", newID, SteamId);
	if (!SQL_FastQuery(db, sQuery)) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
	}
}

int GetCreateUID() {
	while (IsUIDUsed(g_icvarNowMaxUID)) {
		g_icvarNowMaxUID++;
	}
	SetConVarInt(g_cvarNowMaxUID, g_icvarNowMaxUID, true, true);
	return g_icvarNowMaxUID;
}

bool IsUIDUsed(int uid) {
	#if defined DEBUG
	LogToFile(logFile, "IsUIDUsed 被调用");
	#endif

	Database db = GetDBInstance();
	DBResultSet rs;
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT used FROM clvplus_uid WHERE uid = '%d'", uid);
	rs = SQL_Query(db, sQuery);
	if (rs == null) {
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return false;
	} else {
		if (SQL_FetchRow(rs)) {
			if (SQL_FetchInt(rs, 0) == 1) {
				return true;
			}
		}
	}
	delete rs;
	delete db;
	return false;
}

// ===========================================
// ||			       Utils	   			||
// ===========================================
bool IsValidPlayer(int client) {
	if ((client < 1) || (client > MaxClients)) return false;
	if (!(IsClientInGame(client))) return false;
	if (IsFakeClient(client)) return false;
	return true;
}

bool IsPlayerSurvivor(int client) {
	return L4D2Team_Survivor == GetClientTeam(client);
}

bool IsPlayerInfected(int client) {
	return L4D2Team_Infected == GetClientTeam(client);
}

bool IsPlayerGaming(int client) {
	if (!(IsValidPlayer(client))) return false;
	return (IsPlayerSurvivor(client)) || (IsPlayerInfected(client));
}