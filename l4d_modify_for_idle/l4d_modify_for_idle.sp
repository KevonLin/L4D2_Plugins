#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#pragma newdecls required
#pragma semicolon 1

ConVar
	//无限子弹
	sv_infinite_primary_ammo,
	//无敌
	god,
	//无限丧尸
	z_background_limit,
	z_common_limit,
	z_stand_still,
	//丧尸血量
	z_health,
	//无限特感
	z_ghost_checkpoint_spawn_interval,
	z_ghost_spawn_interval,
	z_special_spawn_interval,
	//特感血量
	tongue_health,
	z_charger_health,
	z_exploding_health,
	z_hunter_health,
	z_jockey_health,
	z_spitter_health,
	z_tank_health,
	z_witch_health;

bool flag = false;

public Plugin myinfo =
{
	name		= "刷成就面板插件",
	author		= "KevonLin",
	description = "无限丧尸、特感[,自动开枪 ,自动瞄准]",
	version		= "1.0.0",
	url			= "https://github.com/KevonLin/"
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
	GetConvar();
	
	RegAdminCmd("sm_startset", Command_StartSet, ADMFLAG_ROOT, "Modify");
	RegAdminCmd("sm_stopset", Command_StopSet, ADMFLAG_ROOT, "Stop");
}

public Action Command_StartSet(int client, int args)
{
	if(flag)
	{
		SetConvarModify();
		PrintToChat(client,"Modify access.");
	}
	PrintToChat(client,"Already modified.");
	return Plugin_Handled;
}

public Action Command_StopSet(int client, int args)
{
	if(!flag)
	{
		SetConvarDefault();
		PrintToChat(client,"Modify default access.");
	}
	PrintToChat(client,"Already modified default.");
	return Plugin_Handled;
}

void GetConvar()
{
	//无限子弹
	sv_infinite_primary_ammo = FindConVar("sv_infinite_primary_ammo");
	//无敌
	god = FindConVar("god");
	//无限丧尸
	z_background_limit = FindConVar("z_background_limit");
	z_common_limit = FindConVar("z_common_limit");
	z_stand_still = FindConVar("z_stand_still");
	//丧尸血量
	z_health = FindConVar("z_health");
	//无限特感
	z_ghost_checkpoint_spawn_interval = FindConVar("z_ghost_checkpoint_spawn_interval");
	z_ghost_spawn_interval = FindConVar("z_ghost_spawn_interval");
	z_special_spawn_interval = FindConVar("z_special_spawn_interval");
	//特感血量
	tongue_health = FindConVar("tongue_health");
	z_charger_health = FindConVar("z_charger_health");
	z_exploding_health = FindConVar("z_exploding_health");
	z_hunter_health = FindConVar("z_hunter_health");
	z_jockey_health = FindConVar("z_jockey_health");
	z_spitter_health = FindConVar("z_spitter_health");
	z_tank_health = FindConVar("z_tank_health");
	z_witch_health = FindConVar("z_witch_health");
}

void SetConvarModify()
{
	//无限子弹
	sv_infinite_primary_ammo.SetBool(true, .notify = false);
	//无敌
	god.SetBool(true, .notify = false);
	//无限丧尸
	z_background_limit.SetInt(512, .notify = false);
	z_common_limit.SetInt(512, .notify = false);
	z_stand_still.SetBool(true, .notify = false);
	//丧尸血量
	z_health.SetInt(1, .notify = false);
	//无限特感
	z_ghost_checkpoint_spawn_interval.SetInt(2, .notify = false);
	z_ghost_spawn_interval.SetInt(2, .notify = false);
	z_special_spawn_interval.SetInt(2, .notify = false);
	//特感血量
	tongue_health.SetInt(1, .notify = false);
	z_charger_health.SetInt(1, .notify = false);
	z_exploding_health.SetInt(1, .notify = false);
	z_hunter_health.SetInt(1, .notify = false);
	z_jockey_health.SetInt(1, .notify = false);
	z_spitter_health.SetInt(1, .notify = false);
	z_tank_health.SetInt(1, .notify = false);
	z_witch_health.SetInt(1, .notify = false);
	//自动开枪
	//自动瞄准
}

void SetConvarDefault()
{
	//无限子弹
	sv_infinite_primary_ammo.SetBool(false, .notify = false);
	//无敌
	god.SetBool(false, .notify = false);
	//无限丧尸
	z_background_limit.SetInt(20, .notify = false);
	z_common_limit.SetInt(50, .notify = false);
	z_stand_still.SetBool(false, .notify = false);
	//丧尸血量
	z_health.SetInt(50, .notify = false);
	//无限特感
	z_ghost_checkpoint_spawn_interval.SetInt(30, .notify = false);
	z_ghost_spawn_interval.SetInt(60, .notify = false);
	z_special_spawn_interval.SetInt(45, .notify = false);
	//特感血量
	tongue_health.SetInt(100, .notify = false);
	z_charger_health.SetInt(600, .notify = false);
	z_exploding_health.SetInt(50, .notify = false);
	z_hunter_health.SetInt(250, .notify = false);
	z_jockey_health.SetInt(325, .notify = false);
	z_spitter_health.SetInt(100, .notify = false);
	z_tank_health.SetInt(4000, .notify = false);
	z_witch_health.SetInt(1000, .notify = false);
	//自动开枪
	//自动瞄准
}

//无限子弹
// sv_infinite_primary_ammo.SetBool(true, .notify = false);
//无敌
// god.SetBool(true, .notify = false);

//特感血量
// tongue_health                            : 100      : , "sv", "cheat"  : Tongue health
// z_charger_health                         : 600      : , "sv", "cheat"  : Charger max health
// z_exploding_health                       : 50       : , "sv", "cheat"  : Exploding Zombie max health
// z_hunter_health                          : 250      : , "sv", "cheat"  : Zombie max health
// z_jockey_health                          : 325      : , "sv", "cheat"  : Zombie max health
// z_spitter_health                         : 100      : , "sv", "cheat"  : Spitter zombie max health
// z_tank_health                            : 4000     : , "sv", "cheat"  : Tank Zombie max health
// z_witch_health                           : 1000     : , "sv", "cheat"  : Witch max health

//特感数量
// z_ghost_checkpoint_spawn_interval : 30 : , "sv", "cheat" : 当幸存者在检查点时生成特殊僵尸的间隔
// z_ghost_spawn_interval : 60 : , "sv", "cheat" : 生成特殊僵尸的间隔
// z_special_spawn_interval : 45 : , "sv", "cheat" : 生成特殊僵尸的间隔
// z_safe_spawn_range : 250 : , "sv", "cheat" : 生成特殊僵尸的最小范围

//僵尸血量
// z_health                                 : 50       : , "sv", "cheat"  : Zombie max health
// z_spawn_health                           : 0        : , "sv", "cheat"  : If non-0, health given to a zombie spawned with z_spawn
// z_gas_health                             : 250      : , "sv", "cheat"  : Gas Zombie max health

//丧尸数量
// z_background_limit                       : 20       : , "sv", "cheat"  : How many common infected are on the background map at once.
// z_common_limit                           : 30       : , "sv", "cheat"  : How many common infecteds we can have at once.
// z_spawn                                  : cmd      : , "sv", "cheat"  : <tank|boomer|smoker|witch|hunter|spitter|jockey|charger|mob|common> <auto> <ragdoll> <area>.  Spawns the specified zombie(s) under your cursor, or out in the world/in the targetted nav area if auto or area is specified.
// z_stand_still                            : 0        : , "sv", "cheat"  : For testing.  0: default.  1: unalerted common infected will stand still instead of wandering, turning, sitting, etc.