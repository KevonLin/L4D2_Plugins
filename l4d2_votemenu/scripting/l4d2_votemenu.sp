#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#include <left4dhooks>
#include <basecomm>

#define MATCHMODES_PATH		"configs/matchmodes.txt"
#define TRANSLATION_FILE 	"l4d2_votemenu.phrases"
#define CUSTOMMAP_PATH		"data/l4d2_votemenu_custommap.txt"
#define NEXTMAP_PATH		"data/l4d2_votemenu_nextmap.txt"

#define MaxHP 100
#define MAX_CAMPAIGN_LIMIT 64

Handle
	g_hVote = null;

KeyValues
	g_hModesKV = null;

ConVar
	sm_votemenu_enable,
	sm_votemenu_timedelay,
	sm_votemenu_givehp,
	sm_votemenu_pills,
	sm_votemenu_changeslots,
	sm_votemenu_nextmap,
	sm_votemenu_changethirdmaps,
	sm_votemenu_ban,
	sm_votemenu_kick,
	sm_votemenu_mute,
	sm_votemenu_toggleaddons,
	sm_votemenu_toggleready,
	sm_votemenu_changeconfigs,
	sm_match_player_limit,
	l4d_votemenu_debug,
	cvarMvMaxPlayers,
	cvarAddons,
	cvarReady;

char
	g_sCfg[32],
	g_sSlots[64],
	g_customMapIndex[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH],
	g_customMapName[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH],
	g_nextMapIndex[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH],
	g_nextMapName[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH],
	g_sVoteCustomMapIndex[MAX_NAME_LENGTH],
	g_sVoteCustomMapName[MAX_NAME_LENGTH],
	g_sVoteNextMapIndex[MAX_NAME_LENGTH],
	g_sVoteNextMapName[MAX_NAME_LENGTH],
	g_sVoteNextMapCmdIndex[MAX_NAME_LENGTH];

int
	g_cvarAddons,
	g_iSlots,
	g_customMapCount,
	g_nextMapCount,
	g_selectClient;

bool
	g_cvarReady,
	g_bDebug,
	g_bVoteEnable[MAXPLAYERS + 1],
	g_cvarGiveHP,
	g_cvarGivePills,
	g_cvarChangeSlots,
	g_cvarNextMap,
	g_cvarThirdMap,
	g_cvarBan,
	g_cvarKick,
	g_cvarMute,
	g_cvarToggleAddons, 
	g_cvarToggleReady,
	g_cvarChangeConfigs;

enum voteType
{
	None,
	hp,
	pills,
	slots,
	nextmap,
	thirdmap,
	ban,
	kick,
	mute,
	addons,
	ready,
	config,
}

voteType g_voteType = None;

public Plugin myinfo =
{
	name = "Vote Menu",
	author = "Kevonlin",
	description = "Vote Menu.",
	version = "2.0",
	url = "https://steamcommunity.com/profiles/76561199044101393/"
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
	ParseCustomCampaigns();
	ParseNextCampaigns();
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/"...TRANSLATION_FILE...".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation \""...TRANSLATION_FILE..."\"");
	}
	LoadTranslations(TRANSLATION_FILE);

	char sBuffer[PLATFORM_MAX_PATH];
	g_hModesKV = new KeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MATCHMODES_PATH);

	if (!g_hModesKV.ImportFromFile(sBuffer)) {
		SetFailState("Couldn't load matchmodes.txt!");
	}

	sm_votemenu_enable = CreateConVar("sm_votemenu_enable", "1", "Plugin Enable");
	sm_votemenu_timedelay = CreateConVar("sm_votemenu_timedelay", "30.0", "Vote time interval", 0, true, 0.0);
	sm_votemenu_givehp = CreateConVar("sm_votemenu_givehp", "1", "Give hp Enable");
	sm_votemenu_pills = CreateConVar("sm_votemenu_pills", "1", "Give hp Enable");
	sm_votemenu_changeslots = CreateConVar("sm_votemenu_changeslots", "1", "Change slots Enable");
	sm_votemenu_nextmap = CreateConVar("sm_votemenu_nextmap", "1", "Change next map Enable");
	sm_votemenu_changethirdmaps = CreateConVar("sm_votemenu_changethirdmaps", "1", "Change custom maps Enable");
	sm_votemenu_ban = CreateConVar("sm_votemenu_ban", "1", "Ban Enable");
	sm_votemenu_kick = CreateConVar("sm_votemenu_kick", "1", "Kick Enable");
	sm_votemenu_mute = CreateConVar("sm_votemenu_mute", "1", "Mute Enable");
	sm_votemenu_toggleaddons = CreateConVar("sm_votemenu_toggleaddons", "1", "Toggle addons Enable");
	sm_votemenu_toggleready = CreateConVar("sm_votemenu_toggleready", "1", "Toggle ready Enable");
	sm_votemenu_changeconfigs = CreateConVar("sm_votemenu_changeconfigs", "1", "Change configs Enable");
	sm_match_player_limit = CreateConVar("sm_match_player_limit", "1", "Minimum # of players in game to start the vote", _, true, 1.0, true, 32.0);
	l4d_votemenu_debug = CreateConVar("l4d_votemenu_debug", "0", "Enable debug and kick do not have Admin flag", 0, true, 0.0, true, 1.0);

	cvarMvMaxPlayers = FindConVar("sv_maxplayers");
	cvarAddons = FindConVar("l4d2_addons_eclipse");
	cvarReady = FindConVar("l4d_ready_enabled");

	g_cvarGiveHP = GetConVarBool(sm_votemenu_givehp);
	g_cvarGivePills = GetConVarBool(sm_votemenu_pills);
	g_cvarChangeSlots = GetConVarBool(sm_votemenu_changeslots);
	g_cvarNextMap = GetConVarBool(sm_votemenu_nextmap);
	g_cvarThirdMap = GetConVarBool(sm_votemenu_changethirdmaps);
	g_cvarBan = GetConVarBool(sm_votemenu_ban);
	g_cvarKick = GetConVarBool(sm_votemenu_kick);
	g_cvarMute = GetConVarBool(sm_votemenu_mute);
	g_cvarToggleAddons = GetConVarBool(sm_votemenu_toggleaddons);
	g_cvarToggleReady = GetConVarBool(sm_votemenu_toggleready);
	g_cvarChangeConfigs = GetConVarBool(sm_votemenu_changeconfigs);
	g_bDebug = GetConVarBool(l4d_votemenu_debug);
	g_cvarAddons = GetConVarInt(cvarAddons);

	if (cvarReady != INVALID_HANDLE)
		g_cvarReady = GetConVarBool(cvarReady);

	HookConVarChange(sm_votemenu_givehp, CVarChanged);
	HookConVarChange(sm_votemenu_pills, CVarChanged);	
	HookConVarChange(sm_votemenu_changeslots, CVarChanged);
	HookConVarChange(sm_votemenu_nextmap, CVarChanged);	
	HookConVarChange(sm_votemenu_changethirdmaps, CVarChanged);
	HookConVarChange(sm_votemenu_ban, CVarChanged);	
	HookConVarChange(sm_votemenu_kick, CVarChanged);
	HookConVarChange(sm_votemenu_mute, CVarChanged);	
	HookConVarChange(sm_votemenu_toggleaddons, CVarChanged);
	HookConVarChange(sm_votemenu_toggleready, CVarChanged);	
	HookConVarChange(sm_votemenu_changeconfigs, CVarChanged);	
	HookConVarChange(cvarAddons, CVarChanged);
	
	if (cvarReady != INVALID_HANDLE)
		HookConVarChange(cvarReady, CVarChanged);

	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_votemenu", Command_Votes, "Open vote menu.");
	RegConsoleCmd("sm_votes", Command_Votes, "Open vote menu.");

	AutoExecConfig(true, "l4d2_votemenu");
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client)) return;
	g_bVoteEnable[client] = true;

	if(!g_bDebug || IsFakeClient(client) || CheckCommandAccess(client, "", ADMFLAG_ROOT) == true)
	{
		return;
	}

	if(!(GetUserFlagBits(client) & ADMFLAG_GENERIC))
	{
		KickClient(client, "服务器调试中...");
	}
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client)) return;
	g_bVoteEnable[client] = false;
}

public void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
	g_sVoteNextMapCmdIndex = "None";
}

public void RoundEnd_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
	CreateTimer(10.0, Timer_ChangeVoteNextMap, _);
	return;
}

public Action Timer_ChangeVoteNextMap(Handle timer, any data){
	if(strcmp(g_sVoteNextMapIndex, "") != 0)
	{
		g_sVoteNextMapIndex = "";
		ServerCommand("changelevel %s", g_sVoteNextMapCmdIndex);
	}
	return Plugin_Handled;
}

// public void OnMapStart()
// {
	// for(int i = 1; i < MaxClients; i ++)
	// {
	// 	if(IsFakeClient(i)) continue;
	// 	g_bVoteEnable[i] = true;
	// }
// }

// public void OnMapEnd()
// {
// 	for(int i = 1; i < MaxClients; i ++)
// 	{
// 		if(IsFakeClient(i)) continue;
// 		g_bVoteEnable[i] = false;
// 	}
// }

public void CVarChanged(Handle cvar, char[] oldValue, char[] newValue)
{
	g_cvarAddons = GetConVarInt(cvarAddons);
	if (cvarReady != INVALID_HANDLE)
		g_cvarReady = GetConVarBool(cvarReady);

	g_cvarGiveHP = GetConVarBool(sm_votemenu_givehp);
	g_cvarGivePills = GetConVarBool(sm_votemenu_pills);
	g_cvarChangeSlots = GetConVarBool(sm_votemenu_changeslots);
	g_cvarNextMap = GetConVarBool(sm_votemenu_nextmap);
	g_cvarThirdMap = GetConVarBool(sm_votemenu_changethirdmaps);
	g_cvarBan = GetConVarBool(sm_votemenu_ban);
	g_cvarKick = GetConVarBool(sm_votemenu_kick);
	g_cvarMute = GetConVarBool(sm_votemenu_mute);
	g_cvarToggleAddons = GetConVarBool(sm_votemenu_toggleaddons);
	g_cvarToggleReady = GetConVarBool(sm_votemenu_toggleready);
	g_cvarChangeConfigs = GetConVarBool(sm_votemenu_changeconfigs);
}

public Action Command_Votes(int iClient, int iArgs)
{
	//Test
	// CPrintToChat(iClient,"l4d2_addons_eclipse = %i", GetConVarInt(cvarAddons));
	// CPrintToChat(iClient,"l4d_ready_enabled = %b", g_cvarReady);

	if(iClient == 0 || !sm_votemenu_enable.BoolValue)
	{
		return Plugin_Handled;
	}

	if (GetClientTeam(iClient) <= L4D2Team_Spectator) {
		CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Match voting isn't allowed for spectators.");
		return Plugin_Handled;
	}

	if (!g_bVoteEnable[iClient])
	{
		CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}You can not start after a vote at once.");
		return Plugin_Handled;
	}
	
	BuildVoteMenu(iClient);
	return Plugin_Handled;
}

void BuildVoteMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(VoteMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Menu name" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	if (g_cvarGiveHP)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Give hp" ,iClient);
		vMenu.AddItem("givehp", sBuffer);
	}
	if (g_cvarGivePills)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Give pills" ,iClient);
		vMenu.AddItem("givepills", sBuffer);
	}
	if (g_cvarChangeSlots)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Change slots" ,iClient);
		vMenu.AddItem("changeslots", sBuffer);
	}
	if (g_cvarNextMap)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Next map" ,iClient);
		vMenu.AddItem("nextmap", sBuffer);
	}
	if (g_cvarThirdMap)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Change third maps" ,iClient);
		vMenu.AddItem("changethirdmaps", sBuffer);
	}
	if (g_cvarBan)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Ban players" ,iClient);
		vMenu.AddItem("banplayers", sBuffer);
	}
	if (g_cvarKick)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Kick players" ,iClient);
		vMenu.AddItem("kickplayers", sBuffer);
	}
	if (g_cvarMute)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Mute players" ,iClient);
		vMenu.AddItem("muteplayers", sBuffer);
	}
	if (g_cvarToggleAddons)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Toggle addons" ,iClient);
		vMenu.AddItem("toggleaddons", sBuffer);
	}
	if (g_cvarToggleReady)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Toggle ready" ,iClient);
		vMenu.AddItem("toggleready", sBuffer);
	}
	if (g_cvarChangeConfigs)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "Change config" ,iClient);
		vMenu.AddItem("changeconfig", sBuffer);
	}

	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int VoteMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Select:
		{
			char item[64];
			menu.GetItem(param2, item, sizeof(item));

			if(strcmp(item, "givehp") == 0)
			{
				if (!g_cvarGiveHP)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				g_voteType = view_as<voteType>(hp);
				if (StartVote(param1))
				{
					LogMessage("Player %N start a give hp vote.", param1);
					//caller is voting for
					FakeClientCommand(param1, "Vote Yes");
				} 
				else
				{
					g_voteType = view_as<voteType>(None);
					BuildVoteMenu(param1);
				}
			}
			else if(strcmp(item, "givepills") == 0)
			{
				if (!g_cvarGivePills)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				g_voteType = view_as<voteType>(pills);
				if (StartVote(param1))
				{
					LogMessage("Player %N start a give pills vote.", param1);
					//caller is voting for
					FakeClientCommand(param1, "Vote Yes");
				} 
				else
				{
					g_voteType = view_as<voteType>(None);
					BuildVoteMenu(param1);
				}
			}
			else if(strcmp(item, "changeslots") == 0)
			{
				if (!g_cvarChangeSlots)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				SlotsMenu(param1);
			}
			else if (strcmp(item, "nextmap") == 0)
			{
				if (sm_votemenu_nextmap.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				NextMapMenu(param1);
			}
			else if (strcmp(item, "changethirdmaps") == 0)
			{
				if (!g_cvarNextMap)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				ThirdMapMenu(param1);
			}
			else if (strcmp(item, "banplayers") == 0)
			{
				if (!g_cvarBan)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				
				g_voteType = view_as<voteType>(ban);
				SelectPlayerMenu(param1);
			}
			else if (strcmp(item, "kickplayers") == 0)
			{
				if (!g_cvarKick)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				
				g_voteType = view_as<voteType>(kick);
				SelectPlayerMenu(param1);
			}
			else if (strcmp(item, "muteplayers") == 0)
			{
				if (!g_cvarMute)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				
				g_voteType = view_as<voteType>(mute);
				SelectPlayerMenu(param1);
			}
			else if (strcmp(item, "toggleaddons") == 0)
			{
				if (!g_cvarToggleAddons)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				
				AddonsMenu(param1);
			}
			else if (strcmp(item, "toggleready") == 0)
			{
				if (!g_cvarToggleReady)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				if (cvarReady == INVALID_HANDLE)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}Convar was not found.");
					BuildVoteMenu(param1);
					return 0;
				}
				
				ReadyMenu(param1);
			}
			else if (strcmp(item, "changeconfig") == 0)
			{
				if (!g_cvarChangeConfigs)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				MatchModeMenu(param1);
			}
		}	
	}
	return 0;
}

void SlotsMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(SlotsMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots Menu" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 8" ,iClient);
	vMenu.AddItem("slots8", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 10" ,iClient);
	vMenu.AddItem("slots10", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 12" ,iClient);
	vMenu.AddItem("slots12", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 14" ,iClient);
	vMenu.AddItem("slots14", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 16" ,iClient);
	vMenu.AddItem("slots16", sBuffer);

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int SlotsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		g_voteType = view_as<voteType>(slots);

		char item[64];
		menu.GetItem(param2, item, sizeof(item));

		if(strcmp(item, "slots8") == 0)
		{
			g_sSlots = "8";
		}
		else if(strcmp(item, "slots10") == 0)
		{
			g_sSlots = "10";
		}
		else if(strcmp(item, "slots12") == 0)
		{
			g_sSlots = "12";
		}
		else if(strcmp(item, "slots14") == 0)
		{
			g_sSlots = "14";
		}
		else if(strcmp(item, "slots16") == 0)
		{
			g_sSlots = "16";
		}

		g_iSlots = StringToInt(g_sSlots);
		
		if (cvarMvMaxPlayers.IntValue == g_iSlots)
		{
			CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}Slots already has a value of %i", g_iSlots);
			return 0;
		}

		if(strcmp(item, "slots8") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Player %N start a Slots 8 vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "slots10") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Player %N start a Slots 10 vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "slots12") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Player %N start a Slots 12 vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "slots14") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Player %N start a Slots 14 vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "slots16") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Player %N start a Slots 16 vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
	} 

	return 0;
}

void NextMapMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(NextMapMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Select map menu" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	for (int i = 0; i < g_nextMapCount; i++)
	{
		vMenu.AddItem(g_nextMapIndex[i], g_nextMapName[i]);
	}

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int NextMapMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		g_voteType = view_as<voteType>(nextmap);

		menu.GetItem(param2, g_sVoteNextMapIndex, sizeof(g_sVoteNextMapIndex), _, g_sVoteNextMapName, sizeof(g_sVoteNextMapName));

		if(StartVote(param1))
		{
			LogMessage("Player %N starts a vote: change map %s", param1, g_sVoteNextMapName);
			//caller is voting for
			FakeClientCommand(param1, "Vote Yes");
		}
		else
		{
			g_voteType = view_as<voteType>(None);
			BuildVoteMenu(param1);
		}
	}
	return 0;
}

void ParseNextCampaigns()
{
	Handle g_kvCampaigns = CreateKeyValues("VoteNextCampaigns");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), NEXTMAP_PATH);

	if ( !FileToKeyValues(g_kvCampaigns, sPath) ) 
	{
		SetFailState("[Vote] File not found: %s", sPath);
		CloseHandle(g_kvCampaigns);
		return;
	}
	
	if (!KvGotoFirstSubKey(g_kvCampaigns))
	{
		SetFailState("[Vote] File can't read: you dumb noob!");
		CloseHandle(g_kvCampaigns);
		return;
	}
	
	for (int i = 0; i < MAX_CAMPAIGN_LIMIT; i++)
	{
		KvGetString(g_kvCampaigns,"mapinfo", g_nextMapIndex[i], sizeof(g_nextMapIndex));
		KvGetString(g_kvCampaigns,"mapname", g_nextMapName[i], sizeof(g_nextMapName));
		
		if ( !KvGotoNextKey(g_kvCampaigns) )
		{
			g_nextMapCount = ++i;
			break;
		}
	}
}

void ThirdMapMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(ThirdMapMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Select map menu" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	for (int i = 0; i < g_customMapCount; i++)
	{
		vMenu.AddItem(g_customMapIndex[i], g_customMapName[i]);
	}

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int ThirdMapMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		g_voteType = view_as<voteType>(thirdmap);

		menu.GetItem(param2, g_sVoteCustomMapIndex, sizeof(g_sVoteCustomMapIndex), _, g_sVoteCustomMapName, sizeof(g_sVoteCustomMapName));

		if(StartVote(param1))
		{
			LogMessage("Player %N starts a vote: change map %s", param1, g_sVoteCustomMapName);
			//caller is voting for
			FakeClientCommand(param1, "Vote Yes");
		}
		else
		{
			g_voteType = view_as<voteType>(None);
			BuildVoteMenu(param1);
		}
	}
	return 0;
}

void ParseCustomCampaigns()
{
	Handle g_kvCampaigns = CreateKeyValues("VoteCustomCampaigns");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CUSTOMMAP_PATH);

	if ( !FileToKeyValues(g_kvCampaigns, sPath) ) 
	{
		SetFailState("[Vote] File not found: %s", sPath);
		CloseHandle(g_kvCampaigns);
		return;
	}
	
	if (!KvGotoFirstSubKey(g_kvCampaigns))
	{
		SetFailState("[Vote] File can't read: you dumb noob!");
		CloseHandle(g_kvCampaigns);
		return;
	}
	
	for (int i = 0; i < MAX_CAMPAIGN_LIMIT; i++)
	{
		KvGetString(g_kvCampaigns,"mapinfo", g_customMapIndex[i], sizeof(g_customMapIndex));
		KvGetString(g_kvCampaigns,"mapname", g_customMapName[i], sizeof(g_customMapName));
		
		if ( !KvGotoNextKey(g_kvCampaigns) )
		{
			g_customMapCount = ++i;
			break;
		}
	}
}

void SelectPlayerMenu(int iClient)
{
	char sBuffer[64],sClientID[64];
	Menu vMenu = new Menu(SelectPlayerMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Select pleyer menu" ,iClient);
	vMenu.SetTitle(sBuffer);

	if(g_voteType == view_as<voteType>(kick))
	{
		vMenu.AddItem("kickspecs", "踢出所有旁观");
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && iClient != i)
		{
			FormatEx(sClientID, sizeof(sClientID), "%i" , GetClientUserId(i));
			FormatEx(sBuffer, sizeof(sBuffer), "%N" ,i);
			vMenu.AddItem(sClientID, sBuffer);
		}
	}

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}


public int SelectPlayerMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		char item[32];
		menu.GetItem(param2, item, sizeof(item));

		if(strcmp(item, "kickspecs") == 0)
		{
			FakeClientCommand(param1, "sm_kickspecs");
			return 0;
		}
		
		int target = GetClientOfUserId(StringToInt(item));
		
		AdminId clientAdmin = GetUserAdmin(param1);
		AdminId targetAdmin = GetUserAdmin(target);
		
		if (!CanAdminTarget(clientAdmin, targetAdmin))
		{
			switch (g_voteType)
			{
				case (view_as<voteType>(ban)):
				{
					CPrintToChat(param1, "{blue}[{default}!{blue}] {default}You may not ban Admins.", target);
					CPrintToChat(target, "{blue}[{default}!{blue}] {default}You were banned by {blue}%N", param1);
				}

				case (view_as<voteType>(kick)):
				{
					CPrintToChat(param1, "{blue}[{default}!{blue}] {default}You may not kick Admins.", target);
					CPrintToChat(target, "{blue}[{default}!{blue}] {default}You were voted out by {blue}%N", param1);
				}

				case (view_as<voteType>(mute)):
				{
					CPrintToChat(param1, "{blue}[{default}!{blue}] {default}You may not mute Admins.", target);
					CPrintToChat(target, "{blue}[{default}!{blue}] {default}You were muted by {blue}%N", param1);
				}
			}
			// SelectPlayerMenu(param1);
			return 0;
		}
		
		g_selectClient = target;

		if (g_voteType == view_as<voteType>(ban))
		{
			if (!g_cvarBan)
			{
				g_voteType = view_as<voteType>(None);
				CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Ban Player was disabled.");
				BuildVoteMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Player %N start a ban player vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
				FakeClientCommand(target, "Vote No");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if (g_voteType == view_as<voteType>(kick))
		{
			if (!g_cvarKick)
			{
				g_voteType = view_as<voteType>(None);
				CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Kick Player was disabled.");
				BuildVoteMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Player %N start a kick player vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
				FakeClientCommand(target, "Vote No");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if (g_voteType == view_as<voteType>(mute))
		{
			if (!g_cvarMute)
			{
				g_voteType = view_as<voteType>(None);
				CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Mute Player was disabled.");
				BuildVoteMenu(param1);
				return 0;
			}

			if (BaseComm_IsClientMuted(target))
			{
				g_voteType = view_as<voteType>(None);
				CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Player has been muted.");
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Player %N start a mute player vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
				FakeClientCommand(target, "Vote No");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
	}
	return 0;
}

void AddonsMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(AddonsMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Toggle addons" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Enable addons" ,iClient);
	vMenu.AddItem("enablemod", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Disable addons" ,iClient);
	vMenu.AddItem("disablemod", sBuffer);

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int AddonsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		g_voteType = view_as<voteType>(addons);

		char item[64];
		menu.GetItem(param2, item, sizeof(item));

		if(strcmp(item, "enablemod") == 0)
		{
			if (g_cvarAddons == 1 || (g_cvarAddons == -1 && IsDefaultEnableMod()))
			{
				CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Addons is already Enable");
				AddonsMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Player %N start a enbale addons vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "disablemod") == 0)
		{
			if (g_cvarAddons == 0 || (g_cvarAddons == -1 && !IsDefaultEnableMod()))
			{
				CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Addons is already Disable");
				AddonsMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Player %N start a disable addons vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
	}
	return 0;
}

void ReadyMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(ReadyMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Toggle ready" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Enable ready" ,iClient);
	vMenu.AddItem("enableready", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Disable ready" ,iClient);
	vMenu.AddItem("disableready", sBuffer);

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int ReadyMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		g_voteType = view_as<voteType>(ready);

		char item[64];
		menu.GetItem(param2, item, sizeof(item));

		if(strcmp(item, "enableready") == 0)
		{
			if (g_cvarReady)
			{
				CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Ready plugin was already enabled");
				ReadyMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Player %N start a enbale ready plugin vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "disableready") == 0)
		{
			if (!g_cvarReady)
			{
				CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Ready plugin was already disabled");
				ReadyMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Player %N start a disable ready plugin vote.", param1);
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
	}
	return 0;
}

void MatchModeMenu(int iClient)
{
	Menu hMenu = new Menu(MatchModeMenuHandler);

	char sBuffer[64];
	g_hModesKV.Rewind();

	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Match mode menu", iClient);
	hMenu.SetTitle(sBuffer);

	if (g_hModesKV.GotoFirstSubKey()) {
		do {
			g_hModesKV.GetSectionName(sBuffer, sizeof(sBuffer));
			hMenu.AddItem(sBuffer, sBuffer);
		} while (g_hModesKV.GotoNextKey(false));
	}

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, 20);
}

public int MatchModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Select) {
		char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		g_hModesKV.Rewind();

		if (g_hModesKV.JumpToKey(sInfo) && g_hModesKV.GotoFirstSubKey()) {
			Menu hMenu = new Menu(ConfigsMenuHandler);

			FormatEx(sBuffer, sizeof(sBuffer), "%T", "Match config menu", param1);
			hMenu.SetTitle(sBuffer);

			do {
				g_hModesKV.GetSectionName(sInfo, sizeof(sInfo));
				g_hModesKV.GetString("name", sBuffer, sizeof(sBuffer));

				hMenu.AddItem(sInfo, sBuffer);
			} while (g_hModesKV.GotoNextKey());

			hMenu.Display(param1, 20);
		} else {
			CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}No configs for such mode were found.");
			MatchModeMenu(param1);
		}
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	}

	return 0;
}

public int ConfigsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		MatchModeMenu(param1);
	} else if (action == MenuAction_Select) {
		char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));

		if (StartMatchVote(param1, sBuffer)) {
			strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
			g_voteType = view_as<voteType>(config);
			LogMessage("Player %N start a config vote.", param1);
			//caller is voting for
			FakeClientCommand(param1, "Vote Yes");
		} else {
			MatchModeMenu(param1);
		}
	}

	return 0;
}

bool StartMatchVote(int iClient, const char[] sCfgName)
{
	if (GetClientTeam(iClient) <= L4D2Team_Spectator) {
		CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Match voting isn't allowed for spectators.");
		return false;
	}

	if (!IsBuiltinVoteInProgress()) {
		int iNumPlayers = 0;
		int[] iPlayers = new int[MaxClients];

		//list of non-spectators players
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= L4D2Team_Spectator) {
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		if (iNumPlayers < sm_match_player_limit.IntValue) {
			CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Match vote cannot be started. Not enough players.");
			return false;
		}

		char sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "Load confogl '%s' config?", sCfgName, iClient);

		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, iClient);
		SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 15);

		return true;
	}

	CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Match vote cannot be started now.");
	return false;
}

bool StartVote(int iClient)
{
	if (GetClientTeam(iClient) <= L4D2Team_Spectator) {
		CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote isn't allowed for spectators.");
		return false;
	}

	g_bVoteEnable[iClient] = false;
	CreateTimer(sm_votemenu_timedelay.FloatValue, Timer_VoteDelay, iClient);

	if (!IsBuiltinVoteInProgress()) {
		int iNumPlayers = 0;
		int[] iPlayers = new int[MaxClients];

		if (g_voteType == view_as<voteType>(ban) || g_voteType == view_as<voteType>(kick) || g_voteType == view_as<voteType>(mute))
		{
			for (int i = 1; i <= MaxClients; i++) {
				if (!IsClientInGame(i) || IsFakeClient(i)) {
					continue;
				}

				iPlayers[iNumPlayers++] = i;
			}
		}
		else
		{
			//list of non-spectators players
			for (int i = 1; i <= MaxClients; i++) {
				if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= L4D2Team_Spectator) {
					continue;
				}

				iPlayers[iNumPlayers++] = i;
			}
		}

		if (iNumPlayers < sm_match_player_limit.IntValue) {
			CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote cannot be started. Not enough players.");
			return false;
		}

		char sBuffer[64];
		if (g_voteType == view_as<voteType>(hp))
			FormatEx(sBuffer, sizeof(sBuffer), "%T", "Give hp context", iClient);
		else if (g_voteType == view_as<voteType>(pills))
			FormatEx(sBuffer, sizeof(sBuffer), "%T", "Give pills context", iClient);
		else if (g_voteType == view_as<voteType>(slots))
		{
			if (g_iSlots == 8)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 8", iClient);
			else if (g_iSlots == 10)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 10", iClient);
			else if (g_iSlots == 12)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 12", iClient);
			else if (g_iSlots == 14)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 14", iClient);
			else if (g_iSlots == 16)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 16", iClient);
		}
		else if (g_voteType == view_as<voteType>(nextmap))
		{
			FormatEx(sBuffer, sizeof(sBuffer), "Vote Next Map: %s", g_sVoteNextMapName);
		}
		else if (g_voteType == view_as<voteType>(thirdmap))
		{
			FormatEx(sBuffer, sizeof(sBuffer), "Change Custom Map: %s", g_sVoteCustomMapName);
		}
		else if (g_voteType == view_as<voteType>(ban))
		{
			FormatEx(sBuffer, sizeof(sBuffer), "Ban Player %N 30min", g_selectClient);
		}
		else if (g_voteType == view_as<voteType>(kick))
		{
			FormatEx(sBuffer, sizeof(sBuffer), "Kick Player %N", g_selectClient);
		}
		else if (g_voteType == view_as<voteType>(mute))
		{
			FormatEx(sBuffer, sizeof(sBuffer), "Mute Player %N 30min", g_selectClient);
		}
		else if (g_voteType == view_as<voteType>(addons))
		{
			if(g_cvarAddons == 1 || (g_cvarAddons == -1 && IsDefaultEnableMod()))
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Disable addons", iClient);
			}
			else if(g_cvarAddons == 0 || (g_cvarAddons == -1 && !IsDefaultEnableMod()))
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Enable addons", iClient);
			}
		}
		else if (g_voteType == view_as<voteType>(ready))
		{
			if(g_cvarReady)
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Disable ready", iClient);
			}
			else if(!g_cvarReady)
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Enable ready", iClient);
			}
		}

		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, iClient);
		SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 15);

		return true;
	}

	CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote cannot be started now.");
	return false;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) {
		case BuiltinVoteAction_End: {
			delete vote;
			g_hVote = null;
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void VoteResultHandler(Handle vote, int num_votes, int num_clients, \
										const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				CreateTimer(3.0, ExecVoteRes, _);
				DisplayBuiltinVotePass(vote, "Vote Pass");
				// ExecVoteRes(vote);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action ExecVoteRes(Handle timer, any client)
{
	switch (g_voteType)
	{
		case (view_as<voteType>(hp)):
		{
			RecoveryHealth();
			LogMessage("Vote to give hp pass");	
		}

		case (view_as<voteType>(pills)):
		{
			GivePills();
			LogMessage("Vote to give pills pass");	
		}

		case (view_as<voteType>(slots)):
		{
			ChangeSlots();
			LogMessage("Vote to change slots pass");	
		}

		case (view_as<voteType>(nextmap)):
		{
			ChangeNextMap();
			LogMessage("Vote next map pass");	
		}

		case (view_as<voteType>(thirdmap)):
		{
			ChangeCustomMap();
			LogMessage("Vote to change custom map [%s] pass", g_sVoteCustomMapName);	
		}

		case (view_as<voteType>(ban)):
		{
			BanPlayer();
			LogMessage("Vote to ban player [%s] pass", g_selectClient);	
		}

		case (view_as<voteType>(kick)):
		{
			KickPlayer();
			LogMessage("Vote to kick player [%s] pass", g_selectClient);	
		}

		case (view_as<voteType>(mute)):
		{
			MutePlayer();
			LogMessage("Vote to mute player [%s] pass", g_selectClient);	
		}

		case (view_as<voteType>(addons)):
		{
			ToggleAddons();
			LogMessage("Vote to toggle addons pass");	
		}

		case (view_as<voteType>(ready)):
		{
			ToggleReady();
			LogMessage("Vote to toggle ready pass");	
		}

		case (view_as<voteType>(config)):
		{
			LoadConfig();
			LogMessage("Vote to change [%s] config pass", g_sCfg);	
		}
	}

	g_voteType = view_as<voteType>(None);

	return Plugin_Handled;
}

public Action Timer_VoteDelay(Handle timer, any client)
{
	g_bVoteEnable[client] = true;
	return Plugin_Continue;
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

void SetSurvivorPermanentHealth(int client, int health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

void SetSurvivorTempHealth(int client, int health)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(health));
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

void GivePills()
{
	int flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (int i = 1; i <= MaxClients; i++)
	{
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

void ChangeSlots()
{
	SetConVarInt(cvarMvMaxPlayers, g_iSlots);
	CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Slots {default}has limited to {blue}%i", g_iSlots);
}

void ChangeNextMap()
{
	g_sVoteNextMapCmdIndex = g_sVoteNextMapIndex;
	CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Next map set to {blue}%s", g_sVoteNextMapName);
}

void ChangeCustomMap()
{
	CreateTimer(3.0, Timer_ChangeCustomMapDelay, _);
	CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Map will change to {blue}%s {default}in {blue}3s", g_sVoteCustomMapName);
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

void ToggleReady()
{
	if (g_cvarReady)
	{
		SetConVarInt(cvarReady, 1);
		CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Ready {default}has toggle to {blue}disalbe");
	}
	else if (!g_cvarReady)
	{
		SetConVarInt(cvarReady, 2);
		CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Ready {default}has toggle to {blue}enalbe");
	}

	CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Map will restart after {blue}3s");
	CreateTimer(3.0, RestartMap, _);
}

public Action RestartMap(Handle timer, any client)
{
	char currentMap[256];
	GetCurrentMap(currentMap, 256);
	ServerCommand("changelevel %s", currentMap);

	return Plugin_Continue;
}

public Action Timer_ChangeCustomMapDelay(Handle timer, any client)
{
	ServerCommand("changelevel %s", g_sVoteCustomMapIndex);

	return Plugin_Continue;
}

void LoadConfig()
{
	if (LGO_IsMatchModeLoaded()) {
		ServerCommand("sm_resetmatch");
	}
	ServerCommand("sm_forcematch %s", g_sCfg);
}

bool HasPills(int iClient)
{
	int item = GetPlayerWeaponSlot(iClient, 4);
	if (IsValidEdict(item))
	{
		char buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_pain_pills");
	}
	return false;
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