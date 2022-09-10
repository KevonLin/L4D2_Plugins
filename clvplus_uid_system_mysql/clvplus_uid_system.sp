#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

#define MAXUIDSIZE 64
#define RETRYTIME 3.0

// 	g_hUIDCookie,
// 	g_hTimeCookie,
// 	g_hGameCountCookie;

ConVar
	g_cvarEnable,
	g_cvarNowMaxUID,
	g_cvarUidDebug;
bool
	g_bCvarEnable,
	g_bDebug,
	isQueryUIDSucces = false,
	isNotGetMaxUID = true;

int
	g_icvarNowMaxUID,
	PlayerUID[MAXPLAYERS + 1],
	queryUid;

char
	logFile[256];

Database
	DB;


public Plugin myinfo = {
	name = "UID系统",
	author = "Kevonlin",
	description = "",
	version = "1.0",
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
	g_cvarNowMaxUID = CreateConVar("clvplus_uid_enable", "101", "Get max UID of server now", 0, true, 0.0);
	g_cvarUidDebug = CreateConVar("l4d2_inf_cooldown_mgr_debug", "1", "Enable debug and kick do not have Admin flag", 0, true, 0.0, true, 1.0);

	// g_hUIDCookie = RegClientCookie("clvplus_uid_cookie", "UID for clvplus_uid_system.smx", CookieAccess_Protected);
	// g_hTimeCookie = RegClientCookie("clvplus_time_cookie", "Game time for clvplus_uid_system.smx", CookieAccess_Protected);
	// g_hGameCountCookie = RegClientCookie("clvplus_game_count_cookie", "Game count for clvplus_uid_system.smx", CookieAccess_Protected);

	RegConsoleCmd("sm_uid", UidCommand);
	RegAdminCmd("sm_setuid", SetUidCommand, ADMFLAG_ROOT);

	if (!SQL_CheckConfig("uidsystem"))
	{
		LogToFile(logFile, "Database failure: Could not find Database conf \"sourcebans\".");
		SetFailState("Database failure: Could not find Database conf \"sourcebans\"");
		return;
	}
	Database.Connect(GotDatabase, "uidsystem");

	GetCvar();
	if (!g_bCvarEnable) return;

	queryUid = g_icvarNowMaxUID;

	GetMaxUID();

	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/clvplus_uid_system.log");

	g_cvarEnable.AddChangeHook(ConVarChanged_Cvars);
}

public void OnClientPostAdminCheck(int client) {
	if(!g_bDebug || IsFakeClient(client) || CheckCommandAccess(client, "", ADMFLAG_ROOT) == true) {
		return;
	}

	if(!(GetUserFlagBits(client) & ADMFLAG_GENERIC)) {
		KickClient(client, "服务器调试中...");
	}
}

void GetCvar() {
	g_bCvarEnable = GetConVarBool(g_cvarEnable);
	g_icvarNowMaxUID = GetConVarInt(g_cvarNowMaxUID);
	g_bDebug = GetConVarBool(g_cvarUidDebug);
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvar();
}

public void GotDatabase(Database db, const char[] error, any data) {
	if (db == INVALID_HANDLE) {
		LogToFile(logFile, "Database failure: %s.", error);
		return;
	}
	DB = db;
	LogMessage("已连接数据库");//Test
}

public void OnClientAuthorized(int client, const char[] auth) {
	if (!IsValidPlayer(client)) return;

	// TODO 读取UID 如果不存在则创建 创建后保存UID并重新读取UID 为玩家显示欢迎界面
	if (!(LoadUid(client))) {
		CreateNewUid(client);
	}

	PrintToChat(client, "UID = %d", PlayerUID[client]);

	ShowWelcomePanel(client);
}

public void OnMapStart() {
	for (int client = 1; client < MaxClients; client++) {
		if (!IsValidPlayer(client)) return;
		// TODO 获取正在游戏玩家对局数量并且+1 获取当前时间戳

	}
}

public void OnMapEnd() {
	for (int client = 1; client < MaxClients; client++) {
		if (!IsValidPlayer(client)) return;
		// TODO 获取玩家对局数量和当前时间戳 保存正在游戏的玩家游戏时间和游戏对局

	}
}

public Action UidCommand(int client, int args) {
	if (!IsValidPlayer(client)) return Plugin_Continue;
	// TODO 打开UID菜单
	return Plugin_Handled;
}

public Action SetUidCommand(int client, int args) {
	if (!IsValidPlayer(client)) return Plugin_Continue;
	// TODO 设置玩家UID 如果已经被使用则交换UID或者设置为新的UID
	return Plugin_Handled;
}

// =======================================
// ||			SQL	Utils				||
// =======================================

void SaveTime(int client, float time) {
	// TODO 保存游戏时间到数据库
}

void LoadTime(int client, float time) {
	// TODO 从数据库读取玩家游戏时间
}

void SaveGameCount(int client, int count) {
	// TODO 保存游戏对局数量到数据库
}

void LoadGameCount(int client, int count) {
	// TODO 从数据库读取玩家游戏对局数量
}

void SaveUid(int client) {
	// TODO 保存玩家UID到数据库
	// SetClientCookie(client, g_hMoneyCookie, sMoney);
}

bool LoadUid(int client) {
	// TODO 从数据库读取玩家UID
	char Query[256], SteamId[64];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	FormatEx(Query, sizeof(Query), "SELECT uid FROM clpvlus_uid WHERE steamid = '%s'", SteamId);
	DB.Query(QueryUid, Query);
	return isQueryUIDSucces;
}

public void QueryUid(Database db, DBResultSet results, const char[] error, int client) {
	if (!(results.HasResults)) {
		LogToFile(logFile, "Query UID Failed: %s", error);
		CreateTimer(RETRYTIME, RetryLoadUid, client);
		isQueryUIDSucces = false;
		return;
	}

	PlayerUID[client] = results.FetchInt(0);
	isQueryUIDSucces = true;
}

public Action RetryLoadUid(Handle timer, any client)
{
	LoadUid(client);
	return Plugin_Continue;
}

void CreateNewUid(int client) {
	int newID = GetCreateUID();
	char Query[256], SteamId[64];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	FormatEx(Query, sizeof(Query), "INSERT INTO clpvlus_uid (uid, steamid, gametime, gamecount, used VALUES (%d, '%s', 0, 0, '1')", newID, SteamId);
	PrintToChatAll("创建新UID成功,UID=%d", newID);//Test
}

int GetCreateUID() {
	int newUID = g_icvarNowMaxUID;
	SetConVarInt(g_cvarNowMaxUID, ++g_icvarNowMaxUID, true, true);
	return newUID;
}

void GetMaxUID() {
	//获取从小到大断掉或者最大的id+1
	while (isNotGetMaxUID) {
		queryUid++;
		char Query[256];
		FormatEx(Query, sizeof(Query), "SELECT used FROM clpvlus_uid WHERE uid = %d", queryUid);
		DB.Query(QueryMaxUid, Query);
	}

	SetConVarInt(g_cvarNowMaxUID, queryUid, true, true);
}

public void QueryMaxUid(Database db, DBResultSet results, const char[] error, int client) {
	if (!(results.HasResults)) {
		return;
	}

	int uidUsed = results.FetchInt(4);
	if (uidUsed == 1) {
		return;
	} else {
		isNotGetMaxUID = false;
	}
}

void ShowWelcomePanel(int client) {
	// TODO 欢迎界面
}

// ===========================================
// ||			Client Utils				||
// ===========================================

bool IsValidPlayer(int client) {
	return ((client > 0) && (client <= MaxClients) && (!IsFakeClient(client)));
}

bool IsPlayerSurvivor(int client) {
	return L4D2Team_Survivor == GetClientTeam(client);
}

bool IsPlayerInfected(int client) {
	return L4D2Team_Infected == GetClientTeam(client);
}

bool IsSpectator(int client) {
	return L4D2Team_Spectator == GetClientTeam(client);
}

bool IsPlayerGaming(int client) {
	return ((IsPlayerSurvivor(client)) && (IsPlayerInfected(client)));
}