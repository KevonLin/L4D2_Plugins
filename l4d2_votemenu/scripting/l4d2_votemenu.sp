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

#define MATCHMODES_PATH    "configs/matchmodes.txt"
#define TRANSLATION_FILE   "l4d2_votemenu.phrases"
#define MaxHP              100
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
    sm_votemenu_changecustommaps,
    sm_votemenu_ban,
    sm_votemenu_kick,
    sm_votemenu_mute,
    sm_votemenu_toggleaddons,
    sm_votemenu_toggleready,
    sm_votemenu_changeconfigs,
    sm_match_player_limit,
    sm_votemenu_nextmap_timer_delay,
    l4d_votemenu_debug,
    cvarMvMaxPlayers,
    cvarAddons,
    cvarReady;

char
    g_sSlots[64],
    g_sCustomMapIndex[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH],
    g_sCustomMapName[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH],
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
    IsConfoglAvailable,
    g_cvarReady,
    g_bDebug,
    g_bVoteEnable[MAXPLAYERS + 1],
    g_bMatchModesAvailable,
    g_cvarChangeConfigs;

float
    g_cvarNextMapTimerDelay;

enum struct VoteFeature
{
    char     key[MAX_NAME_LENGTH];
    char     textKey[MAX_NAME_LENGTH];
    char     defaultText[MAX_MESSAGE_LENGTH];
    ConVar   config;
    bool     includeSpectators;
    Function onSelect;
    Function buildTitle;
    Function execute;
}

ArrayList g_Features        = null;
int       g_iCurrentFeature = -1;

char g_OfficialMapInfo[][32] = {
    "c1m1_hotel", "c2m1_highway", "c3m1_plankcountry", "c4m1_milltown_a",
    "c5m1_waterfront", "c6m1_riverbank", "c7m1_docks", "c8m1_apartment",
    "c9m1_alleys", "c10m1_caves", "c11m1_greenhouse", "c12m1_hilltop",
    "c13m1_alpinecreek", "c14m1_junkyard"
};

char g_OfficialMapName[][32] = {
    "Dead Center", "Dark Carnival", "Swamp Fever", "Hard Rain",
    "The Parish", "The Passing", "The Sacrifice", "No Mercy",
    "Crash Course", "Death Toll", "Dead Air", "Blood Harvest",
    "Cold Stream", "The Last Stand"
};

public Plugin myinfo =
{
    name        = "Vote Menu",
    author      = "Kevonlin",
    description = "Vote Menu.",
    version     = "3.0.1",
    url         = "https://steamcommunity.com/profiles/76561199044101393/"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
    EngineVersion iEngine = GetEngineVersion();
    if (iEngine != Engine_Left4Dead2)
    {
        strcopy(sError, iErrMax, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    CheckMatchModeConfigs();
    LoadingTranslations();
    CreateConVars();
    GetConVars();
    HookConVarChanges();
    HookEvents();
    RegConsoleCmds();

    ScanMapsDirectory();

    g_Features = new ArrayList(sizeof(VoteFeature));
    RegisterAllFeatures();

    AutoExecConfig(true, "l4d2_votemenu");
}

// ===================== Registration =====================

void RegisterAllFeatures()
{
    RegisterHpFeature();
    RegisterPillsFeature();
    RegisterSlotsFeature();
    RegisterNextMapFeature();
    RegisterCustomMapFeature();
    RegisterBanFeature();
    RegisterKickFeature();
    RegisterMuteFeature();
    RegisterAddonsFeature();
    RegisterReadyFeature();
    if (g_bMatchModesAvailable)
        RegisterChangeConfigFeature();
}

void RegisterHpFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "givehp");
    strcopy(f.textKey, sizeof(f.textKey), "Give hp");
    strcopy(f.defaultText, sizeof(f.defaultText), "Recovery Health");
    f.config            = sm_votemenu_givehp;
    f.includeSpectators = false;
    f.onSelect          = Hp_OnSelect;
    f.buildTitle        = Hp_BuildTitle;
    f.execute           = Hp_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterPillsFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "givepills");
    strcopy(f.textKey, sizeof(f.textKey), "Give pills");
    strcopy(f.defaultText, sizeof(f.defaultText), "Give Pills");
    f.config            = sm_votemenu_pills;
    f.includeSpectators = false;
    f.onSelect          = Pills_OnSelect;
    f.buildTitle        = Pills_BuildTitle;
    f.execute           = Pills_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterSlotsFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "changeslots");
    strcopy(f.textKey, sizeof(f.textKey), "Change slots");
    strcopy(f.defaultText, sizeof(f.defaultText), "Change Slots");
    f.config            = sm_votemenu_changeslots;
    f.includeSpectators = false;
    f.onSelect          = Slots_OnSelect;
    f.buildTitle        = Slots_BuildTitle;
    f.execute           = Slots_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterNextMapFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "nextmap");
    strcopy(f.textKey, sizeof(f.textKey), "Next map");
    strcopy(f.defaultText, sizeof(f.defaultText), "Next Map");
    f.config            = sm_votemenu_nextmap;
    f.includeSpectators = false;
    f.onSelect          = NextMap_OnSelect;
    f.buildTitle        = NextMap_BuildTitle;
    f.execute           = NextMap_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterCustomMapFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "changecustommaps");
    strcopy(f.textKey, sizeof(f.textKey), "Change custom maps");
    strcopy(f.defaultText, sizeof(f.defaultText), "Change Custom Maps");
    f.config            = sm_votemenu_changecustommaps;
    f.includeSpectators = false;
    f.onSelect          = CustomMap_OnSelect;
    f.buildTitle        = CustomMap_BuildTitle;
    f.execute           = CustomMap_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterBanFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "banplayers");
    strcopy(f.textKey, sizeof(f.textKey), "Ban players");
    strcopy(f.defaultText, sizeof(f.defaultText), "Ban Players");
    f.config            = sm_votemenu_ban;
    f.includeSpectators = true;
    f.onSelect          = Ban_OnSelect;
    f.buildTitle        = Ban_BuildTitle;
    f.execute           = Ban_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterKickFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "kickplayers");
    strcopy(f.textKey, sizeof(f.textKey), "Kick players");
    strcopy(f.defaultText, sizeof(f.defaultText), "Kick Players");
    f.config            = sm_votemenu_kick;
    f.includeSpectators = true;
    f.onSelect          = Kick_OnSelect;
    f.buildTitle        = Kick_BuildTitle;
    f.execute           = Kick_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterMuteFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "muteplayers");
    strcopy(f.textKey, sizeof(f.textKey), "Mute players");
    strcopy(f.defaultText, sizeof(f.defaultText), "Mute Players");
    f.config            = sm_votemenu_mute;
    f.includeSpectators = true;
    f.onSelect          = Mute_OnSelect;
    f.buildTitle        = Mute_BuildTitle;
    f.execute           = Mute_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterAddonsFeature()
{
    if (cvarAddons == null) return;
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "toggleaddons");
    strcopy(f.textKey, sizeof(f.textKey), "Toggle addons");
    strcopy(f.defaultText, sizeof(f.defaultText), "Toggle Addons");
    f.config            = sm_votemenu_toggleaddons;
    f.includeSpectators = false;
    f.onSelect          = Addons_OnSelect;
    f.buildTitle        = Addons_BuildTitle;
    f.execute           = Addons_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterReadyFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "toggleready");
    strcopy(f.textKey, sizeof(f.textKey), "Toggle ready");
    strcopy(f.defaultText, sizeof(f.defaultText), "Toggle Ready");
    f.config            = sm_votemenu_toggleready;
    f.includeSpectators = false;
    f.onSelect          = Ready_OnSelect;
    f.buildTitle        = Ready_BuildTitle;
    f.execute           = Ready_Execute;
    g_Features.PushArray(f, sizeof(f));
}

void RegisterChangeConfigFeature()
{
    VoteFeature f;
    strcopy(f.key, sizeof(f.key), "changeconfig");
    strcopy(f.textKey, sizeof(f.textKey), "Change config");
    strcopy(f.defaultText, sizeof(f.defaultText), "Change Config");
    f.config            = null;
    f.includeSpectators = false;
    f.onSelect          = ChangeConfig_OnSelect;
    f.buildTitle        = ChangeConfig_BuildTitle;
    f.execute           = ChangeConfig_Execute;
    g_Features.PushArray(f, sizeof(f));
}

// ===================== Feature Behaviors =====================

public void Hp_OnSelect(int client)
{
    if (StartVote(client))
    {
        LogMessage("Player [%N] start a give hp vote.", client);
        FakeClientCommand(client, "Vote Yes");
    }
    else BuildVoteMenu(client);
}

public void Hp_BuildTitle(int client, char[] buf, int maxlen)
{
    VoteGetText(client, "Give hp context", "Recovery Health?", buf, maxlen);
}

public void Hp_Execute()
{
    RecoveryHealth();
    LogMessage("Vote to give hp pass");
}

public void Pills_OnSelect(int client)
{
    if (StartVote(client))
    {
        LogMessage("Player [%N] start a give pills vote.", client);
        FakeClientCommand(client, "Vote Yes");
    }
    else BuildVoteMenu(client);
}

public void Pills_BuildTitle(int client, char[] buf, int maxlen)
{
    VoteGetText(client, "Give pills context", "Give Pills?", buf, maxlen);
}

public void Pills_Execute()
{
    GivePills();
    LogMessage("Vote to give pills pass");
}

public void Slots_OnSelect(int client)
{
    SlotsMenu(client);
}

public void Slots_BuildTitle(int client, char[] buf, int maxlen)
{
    if (g_iSlots == 8) VoteGetText(client, "Slots 8", "Limit slots to 8", buf, maxlen);
    else if (g_iSlots == 10) VoteGetText(client, "Slots 10", "Limit slots to 10", buf, maxlen);
    else if (g_iSlots == 12) VoteGetText(client, "Slots 12", "Limit slots to 12", buf, maxlen);
    else if (g_iSlots == 14) VoteGetText(client, "Slots 14", "Limit slots to 14", buf, maxlen);
    else if (g_iSlots == 16) VoteGetText(client, "Slots 16", "Limit slots to 16", buf, maxlen);
}

public void Slots_Execute()
{
    ChangeSlots(g_iSlots);
    LogMessage("Vote to change slots pass");
}

public void NextMap_OnSelect(int client)
{
    NextMapMenu(client);
}

public void NextMap_BuildTitle(int client, char[] buf, int maxlen)
{
    char tmp[64];
    VoteGetText(client, "Vote next map", "Vote Next Map", tmp, sizeof(tmp));
    FormatEx(buf, maxlen, "%s [%s]", tmp, g_sVoteNextMapName);
}

public void NextMap_Execute()
{
    ChangeNextMap(g_sVoteNextMapIndex, g_sVoteNextMapName);
    LogMessage("Vote next map pass");
}

public void CustomMap_OnSelect(int client)
{
    CustomMapMenu(client);
}

public void CustomMap_BuildTitle(int client, char[] buf, int maxlen)
{
    char tmp[64];
    VoteGetText(client, "Change custom map", "Change Custom Map", tmp, sizeof(tmp));
    FormatEx(buf, maxlen, "%s [%s]", tmp, g_sVoteCustomMapName);
}

public void CustomMap_Execute()
{
    ChangeCustomMap(g_sVoteCustomMapIndex, g_sVoteCustomMapName);
    LogMessage("Vote to change custom map [%s] pass", g_sVoteCustomMapName);
}

public void Ban_OnSelect(int client)
{
    SelectPlayerMenu(client);
}

public void Ban_BuildTitle(int client, char[] buf, int maxlen)
{
    char tmp[64];
    VoteGetText(client, "Ban players", "Ban Player", tmp, sizeof(tmp));
    FormatEx(buf, maxlen, "%s [%N] 30min", tmp, g_selectClient);
}

public void Ban_Execute()
{
    BanPlayer(g_selectClient);
    LogMessage("Vote to ban player [%N] pass", g_selectClient);
}

public void Kick_OnSelect(int client)
{
    SelectPlayerMenu(client);
}

public void Kick_BuildTitle(int client, char[] buf, int maxlen)
{
    char tmp[64];
    VoteGetText(client, "Kick players", "Kick Player", tmp, sizeof(tmp));
    FormatEx(buf, maxlen, "%s [%N]", tmp, g_selectClient);
}

public void Kick_Execute()
{
    KickPlayer(g_selectClient);
    LogMessage("Vote to kick player [%N] pass", g_selectClient);
}

public void Mute_OnSelect(int client)
{
    SelectPlayerMenu(client);
}

public void Mute_BuildTitle(int client, char[] buf, int maxlen)
{
    char tmp[64];
    VoteGetText(client, "Mute players", "Mute Player", tmp, sizeof(tmp));
    FormatEx(buf, maxlen, "%s [%N] 30min", tmp, g_selectClient);
}

public void Mute_Execute()
{
    MutePlayer(g_selectClient);
    LogMessage("Vote to mute player [%N] pass", g_selectClient);
}

public void Addons_OnSelect(int client)
{
    AddonsMenu(client);
}

public void Addons_BuildTitle(int client, char[] buf, int maxlen)
{
    if (g_cvarAddons == 1 || (g_cvarAddons == -1 && IsDefaultEnableMod()))
        VoteGetText(client, "Disable addons", "Disable Addons", buf, maxlen);
    else
        VoteGetText(client, "Enable addons", "Enable Addons", buf, maxlen);
}

public void Addons_Execute()
{
    ToggleAddons();
    LogMessage("Vote to toggle addons pass");
}

public void Ready_OnSelect(int client)
{
    ReadyMenu(client);
}

public void Ready_BuildTitle(int client, char[] buf, int maxlen)
{
    if (g_cvarReady)
        VoteGetText(client, "Disable ready", "Disable Ready", buf, maxlen);
    else
        VoteGetText(client, "Enable ready", "Enable Ready", buf, maxlen);
}

public void Ready_Execute()
{
    if (cvarReady == null)
    {
        CPrintToChatAll("{blue}[{default}Vote{blue}] {default}Ready ConVar not found.");
        return;
    }
    ToggleReady();
    LogMessage("Vote to toggle ready pass");
}

public void ChangeConfig_OnSelect(int client)
{
    if (!g_cvarChangeConfigs)
    {
        CPrintToChat(client, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
        return;
    }
    FakeClientCommand(client, "sm_chmatch");
}

public void ChangeConfig_BuildTitle(int client, char[] buf, int maxlen) {}

public void ChangeConfig_Execute() {}

// ===================== Base Setup =====================

void RegConsoleCmds()
{
    RegConsoleCmd("sm_votemenu", Command_Votes, "Open vote menu.");
    RegConsoleCmd("sm_votes", Command_Votes, "Open vote menu.");
}

void HookEvents()
{
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
}

void HookConVarChanges()
{
    HookConVarChange(sm_votemenu_givehp, CVarChanged);
    HookConVarChange(sm_votemenu_pills, CVarChanged);
    HookConVarChange(sm_votemenu_changeslots, CVarChanged);
    HookConVarChange(sm_votemenu_nextmap, CVarChanged);
    HookConVarChange(sm_votemenu_changecustommaps, CVarChanged);
    HookConVarChange(sm_votemenu_ban, CVarChanged);
    HookConVarChange(sm_votemenu_kick, CVarChanged);
    HookConVarChange(sm_votemenu_mute, CVarChanged);
    HookConVarChange(sm_votemenu_toggleaddons, CVarChanged);
    HookConVarChange(sm_votemenu_toggleready, CVarChanged);
    HookConVarChange(sm_votemenu_nextmap_timer_delay, CVarChanged);

    if (cvarAddons != null)
        HookConVarChange(cvarAddons, CVarChanged);

    if (cvarReady != null)
        HookConVarChange(cvarReady, CVarChanged);
}

void CreateConVars()
{
    sm_votemenu_enable              = CreateConVar("sm_votemenu_enable", "1", "Plugin Enable");
    sm_votemenu_timedelay           = CreateConVar("sm_votemenu_timedelay", "30.0", "Vote time interval", 0, true, 0.0);
    sm_votemenu_givehp              = CreateConVar("sm_votemenu_givehp", "1", "Give hp Enable");
    sm_votemenu_pills               = CreateConVar("sm_votemenu_pills", "1", "Give hp Enable");
    sm_votemenu_changeslots         = CreateConVar("sm_votemenu_changeslots", "1", "Change slots Enable");
    sm_votemenu_nextmap             = CreateConVar("sm_votemenu_nextmap", "1", "Change next map Enable");
    sm_votemenu_changecustommaps    = CreateConVar("sm_votemenu_changecustommaps", "1", "Change custom maps Enable");
    sm_votemenu_ban                 = CreateConVar("sm_votemenu_ban", "1", "Ban Enable");
    sm_votemenu_kick                = CreateConVar("sm_votemenu_kick", "1", "Kick Enable");
    sm_votemenu_mute                = CreateConVar("sm_votemenu_mute", "1", "Mute Enable");
    sm_votemenu_toggleaddons        = CreateConVar("sm_votemenu_toggleaddons", "1", "Toggle addons Enable");
    sm_votemenu_toggleready         = CreateConVar("sm_votemenu_toggleready", "1", "Toggle ready Enable");
    sm_votemenu_changeconfigs       = CreateConVar("sm_votemenu_changeconfigs", "1", "Change configs Enable");
    sm_match_player_limit           = CreateConVar("sm_match_player_limit", "1", "Minimum # of players in game to start the vote", _, true, 1.0, true, 32.0);
    sm_votemenu_nextmap_timer_delay = CreateConVar("sm_votemenu_nextmap_timer_delay", "8.0", "Change next map timer delay", _, true, 0.0);
    l4d_votemenu_debug              = CreateConVar("l4d_votemenu_debug", "0", "Enable debug and kick do not have Admin flag", 0, true, 0.0, true, 1.0);
}

void GetConVars()
{
    IsConfoglAvailable = LibraryExists("confogl");

    cvarMvMaxPlayers   = FindConVar("sv_maxplayers");
    cvarAddons         = FindConVar("l4d2_addons_eclipse");

    if (IsConfoglAvailable)
    {
        cvarReady = FindConVar("l4d_ready_enabled");
    }

    g_cvarNextMapTimerDelay = GetConVarFloat(sm_votemenu_nextmap_timer_delay);
    g_cvarChangeConfigs     = GetConVarBool(sm_votemenu_changeconfigs) && g_bMatchModesAvailable;
    g_bDebug                = GetConVarBool(l4d_votemenu_debug);

    g_cvarAddons            = (cvarAddons != null) ? GetConVarInt(cvarAddons) : 1;

    if (IsConfoglAvailable && cvarReady != null)
    {
        g_cvarReady = GetConVarBool(cvarReady);
    }
}

void CheckMatchModeConfigs()
{
    if (g_hModesKV != null)
    {
        delete g_hModesKV;
        g_hModesKV = null;
    }
    g_bMatchModesAvailable = false;

    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), MATCHMODES_PATH);
    if (!FileExists(sPath))
    {
        LogMessage("[Vote] matchmodes.txt not found, changeconfigs will be disabled.");
        return;
    }

    KeyValues kv = new KeyValues("MatchModes");
    if (!kv.ImportFromFile(sPath))
    {
        LogError("[Vote] matchmodes.txt exists but failed to parse, changeconfigs disabled.");
        delete kv;
        return;
    }

    g_hModesKV             = kv;
    g_bMatchModesAvailable = true;
}

void LoadingTranslations()
{
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "translations/" ... TRANSLATION_FILE... ".txt");
    if (!FileExists(sPath))
    {
        LogMessage("[Vote] Translation file not found, using hardcoded fallback.");
        return;
    }
    LoadTranslations(TRANSLATION_FILE);
}

void VoteGetText(int client, const char[] textKey, const char[] defaultText, char[] buffer, int maxlen)
{
    if (TranslationPhraseExists(textKey))
    {
        FormatEx(buffer, maxlen, "%T", textKey, client);
    }
    else
    {
        strcopy(buffer, maxlen, defaultText);
    }
}

// ===================== Map Scanning =====================

void ScanMapsDirectory()
{
    g_nextMapCount    = 0;
    int officialCount = sizeof(g_OfficialMapInfo);
    for (int i = 0; i < officialCount && i < MAX_CAMPAIGN_LIMIT; i++)
    {
        strcopy(g_nextMapIndex[i], MAX_NAME_LENGTH, g_OfficialMapInfo[i]);
        strcopy(g_nextMapName[i], MAX_NAME_LENGTH, g_OfficialMapName[i]);
        g_nextMapCount++;
    }

    ScanCustomMapsFromVpks();

    LogMessage("[Vote] Loaded: %d official, %d custom.", g_nextMapCount, g_customMapCount);
}

void ScanCustomMapsFromVpks()
{
    g_customMapCount = 0;

    DirectoryListing addonsDir = OpenDirectory("addons");
    if (addonsDir == null)
    {
        LogError("[Vote] Cannot open addons directory.");
        return;
    }

    char     fileName[PLATFORM_MAX_PATH];
    FileType type;
    while (addonsDir.GetNext(fileName, sizeof(fileName), type))
    {
        if (type != FileType_File) continue;
        if (!StrEndsWith(fileName, ".vpk")) continue;
        if (StrEndsWith(fileName, "_dir.vpk")) continue;

        int len = strlen(fileName);
        if (len >= 8 && fileName[len - 8] == '_')
        {
            bool isChunk = true;
            for (int k = len - 7; k < len - 4; k++)
            {
                if (fileName[k] < '0' || fileName[k] > '9')
                {
                    isChunk = false;
                    break;
                }
            }
            if (isChunk) continue;
        }

        char vpkMapsPath[PLATFORM_MAX_PATH];
        FormatEx(vpkMapsPath, sizeof(vpkMapsPath), "addons/%s/maps", fileName);

        DirectoryListing mapsDir = OpenDirectory(vpkMapsPath, true);
        if (mapsDir == null) continue;

        char     mapFile[PLATFORM_MAX_PATH];
        FileType mt;
        while (mapsDir.GetNext(mapFile, sizeof(mapFile), mt))
        {
            if (mt != FileType_File) continue;
            if (!StrEndsWith(mapFile, ".bsp")) continue;

            int mlen      = strlen(mapFile) - 4;
            mapFile[mlen] = '\0';

            if (StrEndsWith(mapFile, "_sndscape")) continue;
            if (StrEndsWith(mapFile, "_commentary")) continue;

            if (g_customMapCount >= MAX_CAMPAIGN_LIMIT) break;
            if (IsCustomMapAlreadyAdded(mapFile)) continue;

            strcopy(g_sCustomMapIndex[g_customMapCount], MAX_NAME_LENGTH, mapFile);
            strcopy(g_sCustomMapName[g_customMapCount], MAX_NAME_LENGTH, mapFile);
            g_customMapCount++;
        }
        delete mapsDir;
    }
    delete addonsDir;
}

bool IsCustomMapAlreadyAdded(const char[] mapName)
{
    for (int i = 0; i < g_customMapCount; i++)
    {
        if (strcmp(g_sCustomMapIndex[i], mapName) == 0) return true;
    }
    return false;
}

bool StrEndsWith(const char[] str, const char[] suffix)
{
    int lenStr    = strlen(str);
    int lenSuffix = strlen(suffix);
    if (lenSuffix > lenStr) return false;
    int offset = lenStr - lenSuffix;
    for (int i = 0; i < lenSuffix; i++)
    {
        if (str[offset + i] != suffix[i]) return false;
    }
    return true;
}

// ===================== Events & Hooks =====================

public void OnConfigsExecuted()
{
    IsConfoglAvailable  = LibraryExists("confogl");
    CheckMatchModeConfigs();
    g_cvarChangeConfigs = GetConVarBool(sm_votemenu_changeconfigs) && g_bMatchModesAvailable;
}

public void OnClientPostAdminCheck(int client)
{
    if (IsFakeClient(client)) return;
    g_bVoteEnable[client] = true;

    if (!g_bDebug || IsFakeClient(client) || CheckCommandAccess(client, "", ADMFLAG_ROOT) == true)
    {
        return;
    }

    if (!(GetUserFlagBits(client) & ADMFLAG_GENERIC))
    {
        KickClient(client, "Server is in debug mode.");
    }
}

public void OnClientDisconnect(int client)
{
    if (IsFakeClient(client)) return;
    g_bVoteEnable[client] = false;
}

public void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    g_sVoteNextMapCmdIndex = "none";
}

public void RoundEnd_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    CreateTimer(g_cvarNextMapTimerDelay, Timer_ChangeVoteNextMap, _);
}

public Action Timer_ChangeVoteNextMap(Handle timer, any data)
{
    if (strcmp(g_sVoteNextMapCmdIndex, "none") != 0)
    {
        ServerCommand("changelevel %s", g_sVoteNextMapCmdIndex);
        g_sVoteNextMapCmdIndex = "none";
    }
    return Plugin_Handled;
}

public void CVarChanged(Handle cvar, char[] oldValue, char[] newValue)
{
    GetConVars();
}

// ===================== Menu Entry =====================

public Action Command_Votes(int iClient, int iArgs)
{
    if (iClient == 0 || !sm_votemenu_enable.BoolValue)
    {
        return Plugin_Handled;
    }

    if (GetClientTeam(iClient) <= L4D2Team_Spectator)
    {
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

void BuildVoteMenu(int client)
{
    char sBuffer[MAX_MESSAGE_LENGTH];
    Menu vMenu = new Menu(VoteMenuHandler);
    VoteGetText(client, "Menu name", "Vote Menu", sBuffer, sizeof(sBuffer));
    vMenu.SetTitle(sBuffer);

    for (int i = 0; i < g_Features.Length; i++)
    {
        VoteFeature f;
        g_Features.GetArray(i, f, sizeof(f));
        if (f.config != null && !f.config.BoolValue) continue;
        VoteGetText(client, f.textKey, f.defaultText, sBuffer, sizeof(sBuffer));
        vMenu.AddItem(f.key, sBuffer);
    }

    vMenu.ExitButton = true;
    vMenu.Display(client, 30);
}

public int VoteMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }
    if (action != MenuAction_Select) return 0;

    char key[MAX_NAME_LENGTH];
    menu.GetItem(item, key, sizeof(key));

    VoteFeature f;
    for (int i = 0; i < g_Features.Length; i++)
    {
        g_Features.GetArray(i, f, sizeof(f));
        if (strcmp(f.key, key) != 0) continue;

        g_iCurrentFeature = i;
        Call_StartFunction(null, f.onSelect);
        Call_PushCell(client);
        Call_Finish();
        return 0;
    }
    return 0;
}

// ===================== Sub-Menus =====================

void SlotsMenu(int iClient)
{
    char sBuffer[MAX_MESSAGE_LENGTH];
    Menu vMenu = new Menu(SlotsMenuHandler);
    VoteGetText(iClient, "Slots Menu", "Change Slots Menu", sBuffer, sizeof(sBuffer));
    vMenu.SetTitle(sBuffer);

    VoteGetText(iClient, "Slots 8", "Limit slots to 8", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("slots8", sBuffer);
    VoteGetText(iClient, "Slots 10", "Limit slots to 10", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("slots10", sBuffer);
    VoteGetText(iClient, "Slots 12", "Limit slots to 12", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("slots12", sBuffer);
    VoteGetText(iClient, "Slots 14", "Limit slots to 14", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("slots14", sBuffer);
    VoteGetText(iClient, "Slots 16", "Limit slots to 16", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("slots16", sBuffer);

    vMenu.ExitBackButton = true;
    vMenu.ExitButton     = true;
    vMenu.Display(iClient, 30);
}

public int SlotsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        BuildVoteMenu(param1);
    }
    else if (action == MenuAction_Select)
    {
        char item[64];
        menu.GetItem(param2, item, sizeof(item));

        if (strcmp(item, "slots8") == 0) g_sSlots = "8";
        else if (strcmp(item, "slots10") == 0) g_sSlots = "10";
        else if (strcmp(item, "slots12") == 0) g_sSlots = "12";
        else if (strcmp(item, "slots14") == 0) g_sSlots = "14";
        else if (strcmp(item, "slots16") == 0) g_sSlots = "16";

        g_iSlots = StringToInt(g_sSlots);

        if (cvarMvMaxPlayers.IntValue == g_iSlots)
        {
            CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}Slots already has a value of %i", g_iSlots);
            return 0;
        }

        if (StartVote(param1))
        {
            LogMessage("Player [%N] start a Slots %d vote.", param1, g_iSlots);
            FakeClientCommand(param1, "Vote Yes");
        }
        else BuildVoteMenu(param1);
    }
    return 0;
}

void NextMapMenu(int iClient)
{
    char sBuffer[MAX_MESSAGE_LENGTH];
    Menu vMenu = new Menu(NextMapMenuHandler);
    VoteGetText(iClient, "Select map menu", "Select a Map", sBuffer, sizeof(sBuffer));
    vMenu.SetTitle(sBuffer);

    if (g_nextMapCount == 0)
    {
        VoteGetText(iClient, "No maps available", "No Maps Available", sBuffer, sizeof(sBuffer));
        vMenu.AddItem("none", sBuffer, ITEMDRAW_DISABLED);
    }
    else
    {
        for (int i = 0; i < g_nextMapCount; i++)
        {
            char displayName[MAX_MESSAGE_LENGTH];
            VoteGetText(iClient, g_nextMapIndex[i], g_nextMapName[i], displayName, sizeof(displayName));
            vMenu.AddItem(g_nextMapIndex[i], displayName);
        }
    }

    vMenu.ExitBackButton = true;
    vMenu.ExitButton     = true;
    vMenu.Display(iClient, 30);
}

public int NextMapMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        BuildVoteMenu(param1);
    }
    else if (action == MenuAction_Select)
    {
        menu.GetItem(param2, g_sVoteNextMapIndex, sizeof(g_sVoteNextMapIndex), _, g_sVoteNextMapName, sizeof(g_sVoteNextMapName));

        if (StartVote(param1))
        {
            LogMessage("Player [%N] starts a vote: change next map [%s]", param1, g_sVoteNextMapName);
            FakeClientCommand(param1, "Vote Yes");
        }
        else BuildVoteMenu(param1);
    }
    return 0;
}

void CustomMapMenu(int iClient)
{
    char sBuffer[MAX_MESSAGE_LENGTH];
    Menu vMenu = new Menu(CustomMapMenuHandler);
    VoteGetText(iClient, "Select map menu", "Select a Map", sBuffer, sizeof(sBuffer));
    vMenu.SetTitle(sBuffer);

    if (g_customMapCount == 0)
    {
        VoteGetText(iClient, "No maps available", "No Maps Available", sBuffer, sizeof(sBuffer));
        vMenu.AddItem("none", sBuffer, ITEMDRAW_DISABLED);
    }
    else
    {
        for (int i = 0; i < g_customMapCount; i++)
        {
            char displayName[MAX_MESSAGE_LENGTH];
            VoteGetText(iClient, g_sCustomMapIndex[i], g_sCustomMapName[i], displayName, sizeof(displayName));
            vMenu.AddItem(g_sCustomMapIndex[i], displayName);
        }
    }

    vMenu.ExitBackButton = true;
    vMenu.ExitButton     = true;
    vMenu.Display(iClient, 30);
}

public int CustomMapMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        BuildVoteMenu(param1);
    }
    else if (action == MenuAction_Select)
    {
        menu.GetItem(param2, g_sVoteCustomMapIndex, sizeof(g_sVoteCustomMapIndex), _, g_sVoteCustomMapName, sizeof(g_sVoteCustomMapName));

        if (StartVote(param1))
        {
            LogMessage("Player [%N] starts a vote: change custom map [%s]", param1, g_sVoteCustomMapName);
            FakeClientCommand(param1, "Vote Yes");
        }
        else BuildVoteMenu(param1);
    }
    return 0;
}

void SelectPlayerMenu(int iClient)
{
    char sBuffer[MAX_MESSAGE_LENGTH], sClientID[64];
    Menu vMenu = new Menu(SelectPlayerMenuHandler);
    VoteGetText(iClient, "Select pleyer menu", "Select a Player", sBuffer, sizeof(sBuffer));
    vMenu.SetTitle(sBuffer);

    int itemCount = 0;

    VoteFeature f;
    g_Features.GetArray(g_iCurrentFeature, f, sizeof(f));
    if (strcmp(f.key, "kickplayers") == 0)
    {
        VoteGetText(iClient, "Kick all spectators", "Kick All Spectators", sBuffer, sizeof(sBuffer));
        vMenu.AddItem("kickspecs", sBuffer);
        itemCount++;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && iClient != i)
        {
            FormatEx(sClientID, sizeof(sClientID), "%i", GetClientUserId(i));
            FormatEx(sBuffer, sizeof(sBuffer), "%N", i);
            vMenu.AddItem(sClientID, sBuffer);
            itemCount++;
        }
    }

    if (itemCount == 0)
    {
        VoteGetText(iClient, "No players available", "No Players Available", sBuffer, sizeof(sBuffer));
        vMenu.AddItem("none", sBuffer, ITEMDRAW_DISABLED);
    }

    vMenu.ExitBackButton = true;
    vMenu.ExitButton     = true;
    vMenu.Display(iClient, 30);
}

public int SelectPlayerMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        BuildVoteMenu(param1);
    }
    else if (action == MenuAction_Select)
    {
        char item[32];
        menu.GetItem(param2, item, sizeof(item));

        if (strcmp(item, "kickspecs") == 0)
        {
            FakeClientCommand(param1, "sm_kickspecs");
            return 0;
        }

        int target = GetClientOfUserId(StringToInt(item));

        if (!(IsValidPlayerIndex(param1) && IsValidPlayerIndex(target))) return 0;

        AdminId clientAdmin = GetUserAdmin(param1);
        AdminId targetAdmin = GetUserAdmin(target);

        if (clientAdmin != INVALID_ADMIN_ID || targetAdmin != INVALID_ADMIN_ID)
        {
            if (!CanAdminTarget(clientAdmin, targetAdmin))
            {
                CPrintToChat(param1, "{blue}[{default}!{blue}] {default}You may not target Admins.");
                return 0;
            }
        }

        g_selectClient = target;

        if (StartVote(param1))
        {
            LogMessage("Player [%N] start vote on [%N].", param1, target);
            FakeClientCommand(param1, "Vote Yes");
            FakeClientCommand(target, "Vote No");
        }
        else BuildVoteMenu(param1);
    }
    return 0;
}

void AddonsMenu(int iClient)
{
    char sBuffer[MAX_MESSAGE_LENGTH];
    Menu vMenu = new Menu(AddonsMenuHandler);
    VoteGetText(iClient, "Toggle addons", "Toggle Addons", sBuffer, sizeof(sBuffer));
    vMenu.SetTitle(sBuffer);

    VoteGetText(iClient, "Enable addons", "Enable Addons", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("enablemod", sBuffer);
    VoteGetText(iClient, "Disable addons", "Disable Addons", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("disablemod", sBuffer);

    vMenu.ExitBackButton = true;
    vMenu.ExitButton     = true;
    vMenu.Display(iClient, 30);
}

public int AddonsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        BuildVoteMenu(param1);
    }
    else if (action == MenuAction_Select)
    {
        char item[64];
        menu.GetItem(param2, item, sizeof(item));

        bool enable = (strcmp(item, "enablemod") == 0);

        if (enable && (g_cvarAddons == 1 || (g_cvarAddons == -1 && IsDefaultEnableMod())))
        {
            CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Addons is already enabled");
            AddonsMenu(param1);
            return 0;
        }
        if (!enable && (g_cvarAddons == 0 || (g_cvarAddons == -1 && !IsDefaultEnableMod())))
        {
            CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Addons is already disabled");
            AddonsMenu(param1);
            return 0;
        }

        if (StartVote(param1))
        {
            LogMessage("Player [%N] start toggle addons vote.", param1);
            FakeClientCommand(param1, "Vote Yes");
        }
        else BuildVoteMenu(param1);
    }
    return 0;
}

void ReadyMenu(int iClient)
{
    char sBuffer[MAX_MESSAGE_LENGTH];
    Menu vMenu = new Menu(ReadyMenuHandler);
    VoteGetText(iClient, "Toggle ready", "Toggle Ready", sBuffer, sizeof(sBuffer));
    vMenu.SetTitle(sBuffer);

    VoteGetText(iClient, "Enable ready", "Enable Ready", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("enableready", sBuffer);
    VoteGetText(iClient, "Disable ready", "Disable Ready", sBuffer, sizeof(sBuffer));
    vMenu.AddItem("disableready", sBuffer);

    vMenu.ExitBackButton = true;
    vMenu.ExitButton     = true;
    vMenu.Display(iClient, 30);
}

public int ReadyMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        BuildVoteMenu(param1);
    }
    else if (action == MenuAction_Select)
    {
        char item[64];
        menu.GetItem(param2, item, sizeof(item));

        bool enable = (strcmp(item, "enableready") == 0);

        if (enable && g_cvarReady)
        {
            CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Ready plugin is already enabled");
            ReadyMenu(param1);
            return 0;
        }
        if (!enable && !g_cvarReady)
        {
            CPrintToChat(param1, "{blue}[{default}!{blue}] {default}Ready plugin is already disabled");
            ReadyMenu(param1);
            return 0;
        }

        if (StartVote(param1))
        {
            LogMessage("Player [%N] start toggle ready vote.", param1);
            FakeClientCommand(param1, "Vote Yes");
        }
        else BuildVoteMenu(param1);
    }
    return 0;
}

// ===================== Vote Core =====================

bool StartVote(int iClient)
{
    if (GetClientTeam(iClient) <= L4D2Team_Spectator)
    {
        CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote isn't allowed for spectators.");
        return false;
    }

    if (g_iCurrentFeature < 0 || g_iCurrentFeature >= g_Features.Length)
    {
        CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Invalid feature.");
        return false;
    }

    g_bVoteEnable[iClient] = false;
    CreateTimer(sm_votemenu_timedelay.FloatValue, Timer_VoteDelay, iClient);

    if (IsBuiltinVoteInProgress())
    {
        CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote cannot be started now.");
        return false;
    }

    VoteFeature f;
    g_Features.GetArray(g_iCurrentFeature, f, sizeof(f));

    int iNumPlayers = 0;
    int[] iPlayers  = new int[MaxClients];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i)) continue;
        if (!f.includeSpectators && GetClientTeam(i) <= L4D2Team_Spectator) continue;
        iPlayers[iNumPlayers++] = i;
    }

    if (iNumPlayers < sm_match_player_limit.IntValue)
    {
        CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote cannot be started. Not enough players.");
        return false;
    }

    char sBuffer[MAX_MESSAGE_LENGTH];
    Call_StartFunction(null, f.buildTitle);
    Call_PushCell(iClient);
    Call_PushStringEx(sBuffer, sizeof(sBuffer),
                      SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY,
                      SM_PARAM_COPYBACK);
    Call_PushCell(sizeof(sBuffer));
    Call_Finish();

    g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
    SetBuiltinVoteArgument(g_hVote, sBuffer);
    SetBuiltinVoteInitiator(g_hVote, iClient);
    SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
    DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 15);

    return true;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    switch (action)
    {
        case BuiltinVoteAction_End:
        {
            delete vote;
            g_hVote = null;
        }
        case BuiltinVoteAction_Cancel:
        {
            DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
        }
    }
}

public void VoteResultHandler(Handle vote, int num_votes, int num_clients,
                       const int[][] client_info, int num_items, const int[][] item_info)
{
    for (int i = 0; i < num_items; i++)
    {
        if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
        {
            if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
            {
                DataPack dp = new DataPack();
                dp.WriteCell(g_iCurrentFeature);
                dp.WriteCell(g_iSlots);
                dp.WriteString(g_sVoteNextMapIndex);
                dp.WriteString(g_sVoteNextMapName);
                dp.WriteString(g_sVoteCustomMapIndex);
                dp.WriteString(g_sVoteCustomMapName);
                dp.WriteCell(g_selectClient);
                CreateTimer(3.0, ExecVoteRes, dp);
                DisplayBuiltinVotePass(vote, "Vote Pass");
                return;
            }
        }
    }

    DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action ExecVoteRes(Handle timer, any data)
{
    DataPack dp = view_as<DataPack>(data);
    dp.Reset();
    int iFeatureIdx = dp.ReadCell();
    g_iSlots        = dp.ReadCell();
    dp.ReadString(g_sVoteNextMapIndex, sizeof(g_sVoteNextMapIndex));
    dp.ReadString(g_sVoteNextMapName, sizeof(g_sVoteNextMapName));
    dp.ReadString(g_sVoteCustomMapIndex, sizeof(g_sVoteCustomMapIndex));
    dp.ReadString(g_sVoteCustomMapName, sizeof(g_sVoteCustomMapName));
    g_selectClient = dp.ReadCell();
    delete dp;

    if (iFeatureIdx < 0 || iFeatureIdx >= g_Features.Length)
    {
        LogError("[Vote] ExecVoteRes: invalid feature index %d", iFeatureIdx);
        return Plugin_Handled;
    }

    VoteFeature f;
    g_Features.GetArray(iFeatureIdx, f, sizeof(f));

    Call_StartFunction(null, f.execute);
    Call_Finish();

    return Plugin_Handled;
}

public Action Timer_VoteDelay(Handle timer, any client)
{
    g_bVoteEnable[client] = true;
    return Plugin_Continue;
}

// ===================== Execution Functions =====================

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
    SetCommandFlags("give", flags | FCVAR_CHEAT);
    CPrintToChatAll("{blue}[{default}Vote{blue}] {olive}All survivors {default}health has been restored.");
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
        if (!IsValidPlayerIndex(i)) continue;
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
        {
            if (HasPills(i)) continue;
            FakeClientCommand(i, "give pain_pills");
        }
    }
    SetCommandFlags("give", flags | FCVAR_CHEAT);
    CPrintToChatAll("{blue}[{default}Vote{blue}] {olive}Pills {default}has been distributed to {blue}All survivors");
}

void ChangeSlots(int iSlots)
{
    SetConVarInt(cvarMvMaxPlayers, iSlots);
    CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Slots {default}has been limited to {blue}%i", iSlots);
}

void ChangeNextMap(const char[] mapIndex, const char[] mapName)
{
    strcopy(g_sVoteNextMapCmdIndex, sizeof(g_sVoteNextMapCmdIndex), mapIndex);
    CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Next map set to {blue}%s", mapName);
}

void ChangeCustomMap(const char[] mapIndex, const char[] mapName)
{
    DataPack dp = new DataPack();
    dp.WriteString(mapIndex);
    CreateTimer(3.0, Timer_ChangeCustomMapDelay, dp);
    CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Map will change to {blue}%s {default}in {blue}3s", mapName);
}

Action Timer_ChangeCustomMapDelay(Handle timer, any data)
{
    DataPack dp = view_as<DataPack>(data);
    dp.Reset();
    char mapIndex[MAX_NAME_LENGTH];
    dp.ReadString(mapIndex, sizeof(mapIndex));
    delete dp;
    ServerCommand("changelevel %s", mapIndex);
    return Plugin_Handled;
}

void BanPlayer(int iSelectClient)
{
    if (!IsClientInGame(iSelectClient) || IsFakeClient(iSelectClient)) return;
    ServerCommand("sm_ban %i 30 Vote", iSelectClient);
    CPrintToChatAll("{blue}[{default}Vote{olive}] Player {blue}%N {default}has been banned for 30 min.", iSelectClient);
}

void KickPlayer(int iSelectClient)
{
    if (!IsClientInGame(iSelectClient) || IsFakeClient(iSelectClient)) return;
    KickClient(iSelectClient, "You have been voted off.");
    CPrintToChatAll("{blue}[{default}Vote{olive}] Player {blue}%N {default}has been voted off.", iSelectClient);
}

void MutePlayer(int iSelectClient)
{
    if (!IsClientInGame(iSelectClient) || IsFakeClient(iSelectClient)) return;
    ServerCommand("sm_mute %i 30 Vote", iSelectClient);
    CPrintToChatAll("{blue}[{default}Vote{olive}] Player {blue}%N {default}has been muted.", iSelectClient);
}

void ToggleAddons()
{
    if (cvarAddons == null)
    {
        CPrintToChatAll("{blue}[{default}Vote{blue}] {default}Addons plugin not loaded.");
        return;
    }

    bool currentOn = (g_cvarAddons == 1 || (g_cvarAddons == -1 && IsDefaultEnableMod()));
    SetConVarBool(cvarAddons, !currentOn);

    CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Addons {default}has been toggled.");
    CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Map will restart after {blue}3s");
    CreateTimer(3.0, RestartMap, _);
}

void ToggleReady()
{
    if (g_cvarReady)
    {
        SetConVarInt(cvarReady, 1);
    }
    else
    {
        SetConVarInt(cvarReady, 2);
    }

    CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Ready {default}has been toggled.");
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

// ===================== Utility Functions =====================

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

bool IsValidPlayerIndex(int client)
{
    return ((client > 0) && (client <= MaxClients));
}