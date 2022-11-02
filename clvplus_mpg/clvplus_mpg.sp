#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <sourcemod>

int MaxSlots = 30;

public Plugin myinfo =
{
	name        = "Max Players Change by Admin",
	description = "Admins change max players",
	author      = "Lin",
	version     = "1.0",
	url         = "https://github.com/KevonLin/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_mpg", SlotsRequest, ADMFLAG_CONVARS);
	RegServerCmd("sm_mpg", ServerSlotsRequest);
}

public Action SlotsRequest(int client, int args)
{
	if (client == 0)
	{
		return Plugin_Handled;
	}

	if (args == 1)
	{
		char sSlots[64];
		GetCmdArg(1, sSlots, sizeof(sSlots));
		int Int = StringToInt(sSlots);
		if (Int > MaxSlots)
		{
			ReplyToCommand(client, "超过最大允许数量");
		}
		else
		{
			CPrintToChatAll("{default}[{blue}Slots{default}] {default}服务器最大人数修改为 {blue}%d{default}.", Int);
			SetConVarInt(FindConVar("sv_maxplayers"), Int);
		}
	}
	else
	{
		ReplyToCommand(client, "使用方法:sm_mpg <slots>");
	}
	return Plugin_Handled;
}

public Action ServerSlotsRequest(int args)
{
	if (args == 1)
	{
		char sSlots[64];
		GetCmdArg(1, sSlots, sizeof(sSlots));
		int Int = StringToInt(sSlots);
		if (Int > MaxSlots)
		{
			PrintToServer("超过最大允许数量");
		}
		else
		{
			CPrintToChatAll("{default}[{blue}Slots{default}] {default}服务器最大人数修改为 {blue}%d{default}.", Int);
			PrintToServer("[Slots] 服务器最大人数修改为 %d.", Int);
			SetConVarInt(FindConVar("sv_maxplayers"), Int);
		}
	}
	else
	{
		PrintToServer("使用方法:sm_mpg <slots>");
	}
	return Plugin_Handled;
}