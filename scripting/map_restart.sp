#include <sourcemod>

#define PLUGIN_TAG "[MR]"
#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
    name = "Map Restart",
    author = "Christian Deacon",
    description = "A map restart plugin that executes when the server empties out.",
    version = PLUGIN_VERSION,
    url = "Deaconn.net & LBGaming.co"
};

ConVar g_cvRestartOnEmpty = null;
ConVar g_cvRestartType = null;
ConVar g_cvCheckInterval = null;
ConVar g_cvLog = null;

Handle g_hCheckTimer = null;

public void OnPluginStart()
{
    g_cvRestartOnEmpty = CreateConVar("sm_mr_restart_on_empty", "1", "Whether to restart map when the server is reported as empty.", _, true, 0.0, true, 1.0);
    g_cvRestartType = CreateConVar("sm_mr_restart_type", "0", "0 = uses 'changelevel' command. 1 = executes 'quit' command.", _, true, 0.0, true, 1.0);
    g_cvCheckInterval = CreateConVar("sm_mr_check_interval", "10.0", "How often to check if we need to restart the map in seconds.");
    g_cvLog = CreateConVar("sm_mr_log", "1", "Whether to log when a map/server restart is triggered.", _, true, 0.0, true, 1.0);

    HookConVarChange(g_cvCheckInterval, CVarChange);

    AutoExecConfig(true, "plugin.maprestart");
}

public void CVarChange(Handle hCVar, const char[] oldv, const char[] newv)
{
    ResetupTimer();
}

public void OnConfigsExecuted()
{
    ResetupTimer();
}

public void OnMapEnd()
{
    if (g_hCheckTimer != null)
    {
        delete g_hCheckTimer;
    }
}

stock void ResetupTimer()
{
    if (g_hCheckTimer != null)
    {
        delete g_hCheckTimer;
    }

    g_hCheckTimer = CreateTimer(g_cvCheckInterval.FloatValue, Timer_Check, _, TIMER_REPEAT);
}

public Action Timer_Check(Handle hTimer, any data)
{
    // Check if we need to restart the map/server.
    if (!NeedsRestart())
    {
        return Plugin_Continue;
    }

    // Retrieve real client count.
    int cl_cnt = GetClientCountCustom();

    // If restart when empty is on, check client count.
    if (g_cvRestartOnEmpty.BoolValue && cl_cnt > 0)
    {
        return Plugin_Continue;
    }

    // If client count is below 1, restart map or server.
    if (cl_cnt < 1)
    {
        if (g_cvLog.BoolValue)
        {
            LogMessage("%s Found time to trigger map/server restart.", PLUGIN_TAG);
        }

        if (g_cvRestartType.IntValue == 0)
        {
            char map_name[MAX_NAME_LENGTH];
            GetCurrentMap(map_name, sizeof(map_name));

            ServerCommand("changelevel %s", map_name);
        }
        else
        {
            ServerCommand("quit");
        }
    }

    return Plugin_Continue;
}

stock bool NeedsRestart()
{
    int time_left = 0;

    // If GetMapTimeLeft() isn't supported, just return false and log error.
    if (!GetMapTimeLeft(time_left))
    {
        LogError("%s GetMapTimeLeft() not supported. Does this engine/game support mp_timelimit?", PLUGIN_TAG);

        return false;
    }

    // -1 = map timelimit is infinite.
    if (time_left == -1)
    {
        return false;
    }

    return time_left < 1;
}

stock int GetClientCountCustom()
{
	int ret = 0, i;
	
	for (i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i))
		{
			continue;
		}

		if (IsFakeClient(i))
		{
			continue;
		}

		ret++;
	}
	
	return ret;
}