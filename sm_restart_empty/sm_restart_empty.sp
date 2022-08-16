#define PLUGIN_VERSION "1.4"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

// char g_sLogPath[PLATFORM_MAX_PATH] = "CRASH/restart.log"; // "addons/sourcemod/logs/restart.log";

public Plugin myinfo = 
{
	name = "Restart Empty", 
	author = "Alex Dragokas", 
	description = "Restart server when all players leave the game",
	version = PLUGIN_VERSION, 
	url = "https://dragokas.com"
};

/*
	ChangeLog
	1.0
	 - Initial release
	 
	1.1
	 - Added log file
	 
	1.2
	 - Removing crash logs caused by server restart for some reason
	 
	1.3
	 - Added sv_hibernate_when_empty to force server not hibernate allowing this plugin to make its work
	 - Added alternative method for restarting ("crash" command) (thanks to Luckylock)
	 - Added ConVars
	 - Crash logs remover: parser method is replaced by time based method.
	 - Create "CRASH" folder
	 
	1.4
	 - Fixed "Client index 0 is invalid" in IsFakeClient() check.
*/

ConVar g_ConVarEnable;
ConVar g_ConVarMethod;
ConVar g_ConVarDelay;
ConVar g_ConVarHibernate;

public void OnPluginStart()
{
	CreateConVar("sm_restart_empty_version", PLUGIN_VERSION, "Plugin Version", FCVAR_DONTRECORD);
	g_ConVarEnable = CreateConVar("sm_restart_empty_enable", "1", "插件开关 (1 - 开 / 0 - 关)", CVAR_FLAGS);
	g_ConVarMethod = CreateConVar("sm_restart_empty_method", "2", "1 - _执行命令, 2 - 强制重启 (1不起作用时选此项)", CVAR_FLAGS);
	g_ConVarDelay = CreateConVar("sm_restart_empty_delay", "10.0", "单位 (秒) 倒计时内无玩家加入则执行命令", CVAR_FLAGS);
	
	//AutoExecConfig(true, "sm_restart_empty");

	g_ConVarHibernate = FindConVar("sv_hibernate_when_empty");
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);	
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_ConVarEnable.BoolValue)
		return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if ((client == 0 || !IsFakeClient(client)) && !RealPlayerExist(client)) {
		g_ConVarHibernate.SetInt(0);
		CreateTimer(g_ConVarDelay.FloatValue, Timer_CheckPlayers);
	}
	return Plugin_Continue;
}

public Action Timer_CheckPlayers(Handle timer, int UserId)
{
	if (!RealPlayerExist()) {
		
		if (g_ConVarMethod.IntValue == 1) {
			ServerCommand("changelevel c2m1_highway");
			return Plugin_Stop;
		}
		else {
			SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
			ServerCommand("crash");
			return Plugin_Stop;
		}
		
	}
	return Plugin_Continue;
}

bool RealPlayerExist(int iExclude = 0)
{
	for (int client = 1; client < MaxClients; client++)
	{
		if (client != iExclude && IsClientConnected(client))
		{
			if (!IsFakeClient(client)) {
				return (true);
			}
		}
	}
	return (false);
}