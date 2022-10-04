#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

ConVar
	cVarLFEnable,
	cVarLerpFilter = null,
	cVarMinUpdateRate = null,
	cVarMaxUpdateRate = null,
	cVarMinInterpRatio = null,
	cVarMaxInterpRatio = null;

float
	g_fCvarLerpFilter;

bool
	g_bCvarLFEnable;

public Plugin myinfo = 
{
	name = "Lerp Filter",
	author = "KevonLin",
	description = "过滤掉高于指定lerp的玩家",
	version = "1.0",
	url = "https://github.com/KevonLin"
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
	cVarLFEnable = CreateConVar("sm_filter_kick_enable", "0", "Plugin enable", _, true, 0.0, true, 1.0);
	cVarLerpFilter = CreateConVar("sm_allowed_max_lerp", "0.067", "Maximum allowed lerp value when a player connect", _, true, 0.000, true, 0.500);
	
	cVarMinUpdateRate = FindConVar("sv_minupdaterate");
	cVarMaxUpdateRate = FindConVar("sv_maxupdaterate");
	cVarMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	cVarMaxInterpRatio = FindConVar("sv_client_max_interp_ratio");
	
	GetCvar();

	RegAdminCmd("sm_lerpfilter", LerpFilter_Cmd, ADMFLAG_GENERIC);
	
	HookConVarChange(cVarLerpFilter, CVarChanged);
}

void GetCvar()
{
	g_fCvarLerpFilter = cVarLerpFilter.FloatValue;
	g_bCvarLFEnable = cVarLFEnable.BoolValue;
}

public void CVarChanged(Handle cvar, char[] oldValue, char[] newValue)
{
	GetCvar();
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsValidPlayer(client)) return;

	if(CheckCommandAccess(client, "", ADMFLAG_ROOT) == true)
	{
		return;
	}

	if(GetUserFlagBits(client) & ADMFLAG_GENERIC)
	{
		return;
	}

	if(GetLerpTime(client) <= g_fCvarLerpFilter)
	{
		return;
	}

	// CPrintToChatAll("{blue}[{default}LF{blue}] {default}%N {defalut}被认定为新手玩家", client);
	if(!g_bCvarLFEnable) return;

	PrintToChatAll("[LF] %N 被认定为新手玩家", client);
	// CPrintToChat(client, "{blue}[{defalut}LF{blue}] {defalut}根据你的Lerp你被认定为新手玩家");
	// CPrintToChat(client, "{blue}[{defalut}LF{blue}] {defalut}为了保护你的安全,{blue}30s{defalut}后你将被踢出服务器");
	PrintToChat(client, "[LF] 根据你的Lerp你被认定为新手玩家");
	PrintToChat(client, "[LF] 为了保护你的安全,30s后你将被踢出服务器");
	
	CreateTimer(30.0, Timer_KickDelay, client);
}

public Action Timer_KickDelay(Handle timer, int client)
{
	if(!IsValidPlayer(client)) return Plugin_Handled;
	if(GetLerpTime(client) <= g_fCvarLerpFilter)
	{
		return Plugin_Handled;
	}
	KickClient(client, "你被认定为新手玩家");
	return Plugin_Handled;
}

public Action LerpFilter_Cmd(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "[LF] Usage: sm_lerpfilter <on|off>");
		return Plugin_Handled;
	}

	char Arguments[256];
	
	GetCmdArgString(Arguments, sizeof(Arguments));

	if(strcmp("on", Arguments) == 0)
	{
		SetConVarBool(cVarLFEnable, true);
		ReplyToCommand(client, "[LF] Lerp过滤已启用");
	}
	else if(strcmp("off", Arguments) == 0)
	{
		SetConVarBool(cVarLFEnable, false);
		ReplyToCommand(client, "[LF] Lerp过滤已禁用");
	}

	return Plugin_Handled;
}

float GetLerpTime(int client)
{
	char buffer[64];
	
	if (!GetClientInfo(client, "cl_updaterate", buffer, sizeof(buffer))) {
		buffer = "";
	}
	
	int updateRate = StringToInt(buffer);
	updateRate = RoundFloat(clamp(float(updateRate), cVarMinUpdateRate.FloatValue, cVarMaxUpdateRate.FloatValue));
	
	if (!GetClientInfo(client, "cl_interp_ratio", buffer, sizeof(buffer))) {
		buffer = "";
	}
	
	float flLerpRatio = StringToFloat(buffer);
	
	if (!GetClientInfo(client, "cl_interp", buffer, sizeof(buffer))) {
		buffer = "";
	}
	
	float flLerpAmount = StringToFloat(buffer);
	
	if (cVarMinInterpRatio != null && cVarMaxInterpRatio != null && cVarMinInterpRatio.FloatValue != -1.0) {
		flLerpRatio = clamp(flLerpRatio, cVarMinInterpRatio.FloatValue, cVarMaxInterpRatio.FloatValue);
	}
	
	return maximum(flLerpAmount, flLerpRatio / updateRate);
}

float maximum(float a, float b)
{
	return (a > b) ? a : b;
}

float clamp(float inc, float low, float high)
{
	return (inc > high) ? high : ((inc < low) ? low : inc);
}

bool IsValidPlayer(int client) {
	if ((client < 1) || (client > MaxClients)) return false;
	if (!IsClientConnected(client)) return false;
	if (IsFakeClient(client)) return false;
	return true;
}