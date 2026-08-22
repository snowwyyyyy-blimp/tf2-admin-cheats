#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#undef REQUIRE_EXTENSIONS
#include <vphysics>
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION "1.2.0"
#define ADMIN_FLAG ADMFLAG_CHEATS

#define AIMBOT_FOV 30.0
#define KILLAURA_RADIUS 600.0
#define KILLAURA_DMG 500.0
#define HOMING_TURN 8.0
#define HOMING_RANGE 2500.0
#define HSTATS_DMG_MULT 5.0
#define HSTATS_PROJ_MULT 1.75
#define SENTRY3_MODEL "models/buildables/sentry3.mdl"
#define SENTRY3_HEALTH 216
#define SENTRY3_SHELLS 200
#define SENTRY3_ROCKETS 20

public Plugin myinfo =
{
    name = "[TF2] Admin Cheats",
    author = "you",
    description = "Per-player hack-style cheat features restricted to admins",
    version = PLUGIN_VERSION,
    url = ""
};

enum
{
    FEAT_AIMBOT = 0,
    FEAT_INFAMMO,
    FEAT_CRITS,
    FEAT_RAPIDFIRE,
    FEAT_KILLAURA,
    FEAT_HOMING,
    FEAT_SPEED,
    FEAT_INVIS,
    FEAT_INFHEALTH,
    FEAT_GOD,
    FEAT_NOCLIP,
    FEAT_NOFALL,
    FEAT_ONESHOT,
    FEAT_CLOAK,
    FEAT_UBER,
    FEAT_STATS,
    FEAT_BUILD,
    FEAT_INSTACHARGE,
    FEAT_COUNT
}

static const char g_FeatureNames[FEAT_COUNT][16] =
{
    "aimbot", "infammo", "crits", "rapidfire", "killaura",
    "homing", "speed", "invis", "infhealth", "god",
    "noclip", "nofall", "oneshot", "cloak", "uber",
    "stats", "build", "instacharge"
};

static const char g_FeatureTitles[FEAT_COUNT][32] =
{
    "Silent Aimbot", "Infinite Ammo", "Always Crits", "Rapid Fire",
    "Kill Aura", "Homing Projectiles", "Speed Hack",
    "Invisibility", "Infinite Health", "Godmode", "Noclip",
    "No Fall Damage", "One-Shot Kill", "Infinite Cloak", "Instant Uber",
    "Hacked Stats", "Instant Lvl3 Buildings", "Instant Charge"
};

bool g_Aimbot[MAXPLAYERS + 1];
bool g_InfAmmo[MAXPLAYERS + 1];
bool g_Crits[MAXPLAYERS + 1];
bool g_RapidFire[MAXPLAYERS + 1];
bool g_KillAura[MAXPLAYERS + 1];
bool g_Homing[MAXPLAYERS + 1];
bool g_Invis[MAXPLAYERS + 1];
bool g_InfHealth[MAXPLAYERS + 1];
bool g_God[MAXPLAYERS + 1];
bool g_Noclip[MAXPLAYERS + 1];
bool g_NoFall[MAXPLAYERS + 1];
bool g_OneShot[MAXPLAYERS + 1];
bool g_Cloak[MAXPLAYERS + 1];
bool g_Uber[MAXPLAYERS + 1];
bool g_HStats[MAXPLAYERS + 1];
bool g_Build[MAXPLAYERS + 1];

float g_SpeedMult[MAXPLAYERS + 1];

int g_AmmoRef[MAXPLAYERS + 1];
int g_MaxClip[MAXPLAYERS + 1];

int g_MenuTarget[MAXPLAYERS + 1];
bool g_InstaCharge[MAXPLAYERS + 1];
StringMap g_ProjScaled;

#define PROJ_TRACK_MAX 2048
float g_ProjLastPos[PROJ_TRACK_MAX][3];
float g_ProjLastTime[PROJ_TRACK_MAX];
bool g_HDebug;
float g_DbgT[7];
ArrayList g_ProjList;

ConVar g_cvBaseSpeed;

public void OnMapStart()
{
    PrecacheModel(SENTRY3_MODEL, true);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("tfadmincheats");
    return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
    if (GetFeatureStatus(FeatureType_Native, "Phys_SetVelocity") != FeatureStatus_Available)
    {
        SetFailState("The 'vphysics' extension is required. Install it in addons/sourcemod/extensions/ and restart.");
    }
}

public void OnPluginStart()
{
    g_ProjList = new ArrayList();
    CreateConVar("sm_tfcheats_version", PLUGIN_VERSION, "Admin Cheats version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    g_cvBaseSpeed = CreateConVar("sm_tfcheats_basespeed", "420.0", "Base maxspeed used by the speed hack", FCVAR_NONE, true, 100.0, true, 2000.0);

    RegAdminCmd("sm_hacks", Cmd_Main, ADMIN_FLAG, "sm_hacks <target> [feature|all] [0/1] - manage cheat features");
    RegAdminCmd("sm_cheats", Cmd_Main, ADMIN_FLAG, "Alias for sm_hacks");
    RegAdminCmd("sm_speedhack", Cmd_Speed, ADMIN_FLAG, "sm_speedhack <target> <multiplier>");
    RegAdminCmd("sm_tp", Cmd_TP, ADMIN_FLAG, "Teleport yourself to where you are looking");
    RegAdminCmd("sm_respawnme", Cmd_RespawnMe, ADMIN_FLAG, "Instantly respawn yourself");
    RegAdminCmd("sm_thirdperson", Cmd_ThirdPerson, ADMIN_FLAG, "Force third person camera");
    RegAdminCmd("sm_hdebug", Cmd_HDebug, ADMIN_FLAG, "Toggle homing debug output");
    RegAdminCmd("sm_firstperson", Cmd_FirstPerson, ADMIN_FLAG, "Restore first person camera");

    HookEvent("player_spawn", Event_Spawn);

    g_ProjScaled = new StringMap();

    CreateTimer(0.01, Timer_Master, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, Hook_TakeDamage);
}

public void OnClientDisconnect(int client)
{
    ResetPlayer(client);
}

void ResetPlayer(int client)
{
    g_Aimbot[client] = false;
    g_InfAmmo[client] = false;
    g_Crits[client] = false;
    g_RapidFire[client] = false;
    g_KillAura[client] = false;
    g_Homing[client] = false;
    g_Invis[client] = false;
    g_InfHealth[client] = false;
    g_God[client] = false;
    g_Noclip[client] = false;
    g_NoFall[client] = false;
    g_OneShot[client] = false;
    g_Cloak[client] = false;
    g_Uber[client] = false;
    g_InstaCharge[client] = false;
    g_HStats[client] = false;
    g_Build[client] = false;
    g_SpeedMult[client] = 1.0;
    g_AmmoRef[client] = INVALID_ENT_REFERENCE;
    g_MaxClip[client] = -1;

    if (IsClientInGame(client))
    {
        ApplyRender(client, false);
        if (IsPlayerAlive(client))
        {
            SetEntityMoveType(client, MOVETYPE_WALK);
            SetEntProp(client, Prop_Data, "m_takedamage", 2);
        }
    }
}

public Action Cmd_Main(int client, int args)
{
    if (args == 0)
    {
        ShowTargetMenu(client);
        return Plugin_Handled;
    }

    char argTarget[64];
    GetCmdArg(1, argTarget, sizeof(argTarget));

    char targetName[MAX_TARGET_LENGTH];
    int targets[MAXPLAYERS + 1];
    bool tn_is_ml;

    int count = ProcessTargetString(argTarget, client, targets, MAXPLAYERS, COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_MULTI, targetName, sizeof(targetName), tn_is_ml);
    if (count <= 0)
    {
        ReplyToCommand(client, "[Cheats] No matching alive target found.");
        return Plugin_Handled;
    }

    if (args == 1)
    {
        if (count == 1 && client != 0 && IsClientInGame(client))
        {
            g_MenuTarget[client] = targets[0];
            ShowFeatureMenu(client);
        }
        else
        {
            PrintStatus(client, targets[0]);
        }
        return Plugin_Handled;
    }

    char argFeat[32];
    GetCmdArg(2, argFeat, sizeof(argFeat));

    int stateArg = -1;
    if (args >= 3)
    {
        char argState[8];
        GetCmdArg(3, argState, sizeof(argState));
        stateArg = (StringToInt(argState) != 0) ? 1 : 0;
    }

    int applied;
    for (int i = 0; i < count; i++)
    {
        if (ApplyByName(targets[i], argFeat, stateArg))
        {
            applied++;
        }
        else
        {
            ReplyToCommand(client, "[Cheats] Unknown feature '%s'.", argFeat);
            return Plugin_Handled;
        }
    }

    char label[48];
    GetFeatureLabel(argFeat, label, sizeof(label));

    char verb[8];
    strcopy(verb, sizeof(verb), stateArg == 0 ? "OFF" : (stateArg == 1 ? "ON" : "TOGGLED"));

    ReplyToCommand(client, "[Cheats] %s %s for %s (%d player%s)", label, verb, targetName, applied, applied == 1 ? "" : "s");
    return Plugin_Handled;
}

public Action Cmd_Speed(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "Usage: sm_speedhack <target> <multiplier>");
        return Plugin_Handled;
    }

    char argTarget[64], argMult[16];
    GetCmdArg(1, argTarget, sizeof(argTarget));
    GetCmdArg(2, argMult, sizeof(argMult));

    float mult = StringToFloat(argMult);
    if (mult < 0.1 || mult > 20.0)
    {
        ReplyToCommand(client, "[Cheats] Multiplier must be between 0.1 and 20.");
        return Plugin_Handled;
    }

    char targetName[MAX_TARGET_LENGTH];
    int targets[MAXPLAYERS + 1];
    bool tn_is_ml;
    int count = ProcessTargetString(argTarget, client, targets, MAXPLAYERS, COMMAND_FILTER_ALIVE, targetName, sizeof(targetName), tn_is_ml);
    if (count <= 0)
    {
        ReplyToCommand(client, "[Cheats] No matching alive target found.");
        return Plugin_Handled;
    }

    for (int i = 0; i < count; i++)
    {
        g_SpeedMult[targets[i]] = mult;
    }

    ReplyToCommand(client, "[Cheats] Speed x%.2f set for %s (%d player%s)", mult, targetName, count, count == 1 ? "" : "s");
    return Plugin_Handled;
}

public Action Cmd_TP(int client, int args)
{
    if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        ReplyToCommand(client, "[Cheats] Must be used by an alive player in game.");
        return Plugin_Handled;
    }

    float eye[3], fwd[3], end[3];
    GetClientEyePosition(client, eye);
    GetClientEyeAngles(client, fwd);
    GetAngleVectors(fwd, fwd, NULL_VECTOR, NULL_VECTOR);
    ScaleVector(fwd, 4096.0);
    AddVectors(eye, fwd, end);

    Handle tr = TR_TraceRayFilterEx(eye, end, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_IgnoreClients);
    TR_GetEndPosition(end, tr);
    float normal[3];
    TR_GetPlaneNormal(tr, normal);
    delete tr;

    ScaleVector(normal, 64.0);
    AddVectors(end, normal, end);

    float vel[3];
    TeleportEntity(client, end, NULL_VECTOR, vel);
    PrintToChat(client, "\x04[Cheats]\x01 Teleported.");
    return Plugin_Handled;
}

public Action Cmd_RespawnMe(int client, int args)
{
    if (client == 0 || !IsClientInGame(client))
    {
        ReplyToCommand(client, "[Cheats] Must be used by a player in game.");
        return Plugin_Handled;
    }
    TF2_RespawnPlayer(client);
    return Plugin_Handled;
}

public Action Cmd_ThirdPerson(int client, int args)
{
    if (client == 0 || !IsClientInGame(client))
    {
        ReplyToCommand(client, "[Cheats] Must be used by a player in game.");
        return Plugin_Handled;
    }
    SetEntProp(client, Prop_Send, "m_nForceTauntCam", 1);
    return Plugin_Handled;
}

public Action Cmd_FirstPerson(int client, int args)
{
    if (client == 0 || !IsClientInGame(client))
    {
        ReplyToCommand(client, "[Cheats] Must be used by a player in game.");
        return Plugin_Handled;
    }
    SetEntProp(client, Prop_Send, "m_nForceTauntCam", 0);
    return Plugin_Handled;
}

void ShowTargetMenu(int client)
{
    if (client == 0 || !IsClientInGame(client))
    {
        ReplyToCommand(client, "Usage: sm_hacks <target> [feature|all] [0/1]");
        return;
    }

    Menu menu = new Menu(MenuHandler_Target);
    menu.SetTitle("[Cheats] Select target player");

    char userid[16], display[MAX_NAME_LENGTH + 12];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i)) continue;
        IntToString(GetClientUserId(i), userid, sizeof(userid));
        Format(display, sizeof(display), "%N%s", i, IsPlayerAlive(i) ? "" : " (dead)");
        menu.AddItem(userid, display);
    }

    if (menu.ItemCount == 0)
    {
        delete menu;
        PrintToChat(client, "\x04[Cheats]\x01 No players online.");
        return;
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Target(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        int target = GetClientOfUserId(StringToInt(info));
        if (!target || !IsClientInGame(target))
        {
            PrintToChat(param1, "\x04[Cheats]\x01 Target left the server.");
            return 0;
        }
        g_MenuTarget[param1] = target;
        ShowFeatureMenu(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowFeatureMenu(int client)
{
    int target = g_MenuTarget[client];
    if (!target || !IsClientInGame(target))
    {
        PrintToChat(client, "\x04[Cheats]\x01 Target left the server.");
        return;
    }

    Menu menu = new Menu(MenuHandler_Feature);
    menu.SetTitle("[Cheats] Hacks for %N", target);

    char index[4], display[64];
    for (int f = 0; f < FEAT_COUNT; f++)
    {
        IntToString(f, index, sizeof(index));
        Format(display, sizeof(display), "[%s] %s", GetFeatureBool(target, f) ? "ON " : "OFF", g_FeatureTitles[f]);
        menu.AddItem(index, display);
    }

    menu.AddItem("all_on", ">>> ENABLE ALL <<<", ITEMDRAW_DEFAULT);
    menu.AddItem("all_off", ">>> DISABLE ALL <<<");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Feature(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(param2, info, sizeof(info));

        int target = g_MenuTarget[param1];
        if (!target || !IsClientInGame(target))
        {
            PrintToChat(param1, "\x04[Cheats]\x01 Target left the server.");
            return 0;
        }

        if (StrEqual(info, "all_on"))
        {
            for (int f = 0; f < FEAT_COUNT; f++) SetFeatureByIndex(target, f, true);
            g_SpeedMult[target] = 1.5;
            PrintToChat(param1, "\x04[Cheats]\x01 ALL hacks ON for %N.", target);
        }
        else if (StrEqual(info, "all_off"))
        {
            for (int f = 0; f < FEAT_COUNT; f++) SetFeatureByIndex(target, f, false);
            g_SpeedMult[target] = 1.0;
            PrintToChat(param1, "\x04[Cheats]\x01 ALL hacks OFF for %N.", target);
        }
        else
        {
            int f = StringToInt(info);
            SetFeatureByIndex(target, f, !GetFeatureBool(target, f));
            PrintToChat(param1, "\x04[Cheats]\x01 %s %s for %N.", g_FeatureTitles[f], GetFeatureBool(target, f) ? "ON" : "OFF", target);
        }

        ShowFeatureMenu(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

bool GetFeatureBool(int client, int feat)
{
    switch (feat)
    {
        case FEAT_AIMBOT: return g_Aimbot[client];
        case FEAT_INFAMMO: return g_InfAmmo[client];
        case FEAT_CRITS: return g_Crits[client];
        case FEAT_RAPIDFIRE: return g_RapidFire[client];
        case FEAT_KILLAURA: return g_KillAura[client];
        case FEAT_HOMING: return g_Homing[client];
        case FEAT_SPEED: return g_SpeedMult[client] > 1.001;
        case FEAT_INVIS: return g_Invis[client];
        case FEAT_INFHEALTH: return g_InfHealth[client];
        case FEAT_GOD: return g_God[client];
        case FEAT_NOCLIP: return g_Noclip[client];
        case FEAT_NOFALL: return g_NoFall[client];
        case FEAT_ONESHOT: return g_OneShot[client];
        case FEAT_CLOAK: return g_Cloak[client];
        case FEAT_UBER: return g_Uber[client];
        case FEAT_STATS: return g_HStats[client];
        case FEAT_BUILD: return g_Build[client];
        case FEAT_INSTACHARGE: return g_InstaCharge[client];
    }
    return false;
}

void SetFeatureByIndex(int client, int feat, bool value)
{
    switch (feat)
    {
        case FEAT_AIMBOT: g_Aimbot[client] = value;
        case FEAT_INFAMMO:
        {
            g_InfAmmo[client] = value;
            g_AmmoRef[client] = INVALID_ENT_REFERENCE;
        }
        case FEAT_CRITS: g_Crits[client] = value;
        case FEAT_RAPIDFIRE: g_RapidFire[client] = value;
        case FEAT_KILLAURA: g_KillAura[client] = value;
        case FEAT_HOMING: g_Homing[client] = value;
        case FEAT_SPEED: g_SpeedMult[client] = value ? 1.5 : 1.0;
        case FEAT_INVIS:
        {
            g_Invis[client] = value;
            if (IsClientInGame(client)) ApplyRender(client, value);
        }
        case FEAT_INFHEALTH: g_InfHealth[client] = value;
        case FEAT_GOD:
        {
            g_God[client] = value;
            if (IsClientInGame(client) && IsPlayerAlive(client))
            {
                SetEntProp(client, Prop_Data, "m_takedamage", value ? 0 : 2);
            }
        }
        case FEAT_NOCLIP:
        {
            g_Noclip[client] = value;
            if (IsClientInGame(client) && IsPlayerAlive(client))
            {
                SetEntityMoveType(client, value ? MOVETYPE_NOCLIP : MOVETYPE_WALK);
            }
        }
        case FEAT_NOFALL: g_NoFall[client] = value;
        case FEAT_ONESHOT: g_OneShot[client] = value;
        case FEAT_CLOAK: g_Cloak[client] = value;
        case FEAT_UBER: g_Uber[client] = value;
        case FEAT_STATS: g_HStats[client] = value;
        case FEAT_BUILD: g_Build[client] = value;
        case FEAT_INSTACHARGE: g_InstaCharge[client] = value;
    }
}

bool ApplyByName(int client, const char[] featName, int stateArg)
{
    if (StrEqual(featName, "all"))
    {
        bool on = (stateArg != 0);
        for (int f = 0; f < FEAT_COUNT; f++)
        {
            SetFeatureByIndex(client, f, on);
        }
        g_SpeedMult[client] = on ? 1.5 : 1.0;
        return true;
    }

    for (int f = 0; f < FEAT_COUNT; f++)
    {
        if (StrEqual(featName, g_FeatureNames[f]))
        {
            bool cur = GetFeatureBool(client, f);
            bool val = (stateArg == -1) ? !cur : (stateArg != 0);
            SetFeatureByIndex(client, f, val);
            return true;
        }
    }
    return false;
}

void GetFeatureLabel(const char[] featName, char[] out, int maxlen)
{
    for (int f = 0; f < FEAT_COUNT; f++)
    {
        if (StrEqual(featName, g_FeatureNames[f]))
        {
            strcopy(out, maxlen, g_FeatureTitles[f]);
            return;
        }
    }
    strcopy(out, maxlen, featName);
}

void PrintStatus(int client, int target)
{
    char buf[192];
    Format(buf, sizeof(buf), "[Cheats] Status for %N:", target);
    ReplyToCommand(client, "%s", buf);

    buf[0] = '\0';
    for (int f = 0; f < FEAT_COUNT; f++)
    {
        if (GetFeatureBool(target, f))
        {
            Format(buf, sizeof(buf), "%s %s,", buf, g_FeatureNames[f]);
        }
    }

    if (buf[0] == '\0')
    {
        ReplyToCommand(client, "  (none active)");
    }
    else
    {
        int len = strlen(buf);
        if (len > 0 && buf[len - 1] == ',') buf[len - 1] = '\0';
        ReplyToCommand(client, "  Active:%s", buf);
    }
}

public Action Timer_Master(Handle timer)
{
    for (int c = 1; c <= MaxClients; c++)
    {
        if (!IsClientInGame(c) || !IsPlayerAlive(c)) continue;

        if (g_God[c])
        {
            SetEntProp(c, Prop_Data, "m_takedamage", 0);
        }

        if (g_Crits[c])
        {
            TF2_AddCondition(c, TFCond_CritOnWin, 0.5, 0);
        }

        if (g_InfHealth[c])
        {
            SetEntProp(c, Prop_Send, "m_iHealth", GetEntProp(c, Prop_Data, "m_iMaxHealth"));
        }

        if (g_Cloak[c])
        {
            SetEntPropFloat(c, Prop_Send, "m_flCloakMeter", 100.0);
        }

        if (g_Uber[c])
        {
            SetEntPropFloat(c, Prop_Send, "m_flChargeLevel", 100.0);
        }

        if (g_KillAura[c])
        {
            DoKillAura(c);
        }

        if (g_Build[c])
        {
            DoInstaBuild(c);
        }

        if (g_InstaCharge[c])
        {
            DoInstaCharge(c);
        }
    }

    return Plugin_Continue;
}

void DoInstaCharge(int client)
{
    if (HasEntProp(client, Prop_Send, "m_flChargeMeter"))
    {
        SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
    }

    int wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (wep == -1 || !IsValidEntity(wep)) return;

    char cls[64];
    GetEntityClassname(wep, cls, sizeof(cls));

    if (StrContains(cls, "tf_weapon_sniperrifle") == 0 && HasEntProp(wep, Prop_Send, "m_flChargedDamage"))
    {
        SetEntPropFloat(wep, Prop_Send, "m_flChargedDamage", 150.0);
    }

    if (StrEqual(cls, "tf_weapon_medigun") && HasEntProp(wep, Prop_Send, "m_flChargeLevel"))
    {
        SetEntPropFloat(wep, Prop_Send, "m_flChargeLevel", 1.0);
    }

    if (StrEqual(cls, "tf_weapon_compound_bow"))
    {
        if (HasEntProp(wep, Prop_Send, "m_flChargeBeginTime"))
        {
            SetEntPropFloat(wep, Prop_Send, "m_flChargeBeginTime", GetGameTime() - 10.0);
        }
        else if (HasEntProp(wep, Prop_Data, "m_flChargeBeginTime"))
        {
            SetEntPropFloat(wep, Prop_Data, "m_flChargeBeginTime", GetGameTime() - 10.0);
        }
    }
}

void DoKillAura(int client)
{
    int team = GetClientTeam(client);
    float pos[3], head[3];
    GetClientAbsOrigin(client, pos);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i)) continue;
        if (GetClientTeam(i) == team) continue;
        if (TF2_IsPlayerInCondition(i, TFCond_Disguised)) continue;
        if (TF2_IsPlayerInCondition(i, TFCond_DeadRingered)) continue;

        GetClientEyePosition(i, head);
        float dist = GetVectorDistance(pos, head);
        if (dist > KILLAURA_RADIUS) continue;
        if (!CanSeePoint(pos, head)) continue;

        SDKHooks_TakeDamage(i, client, client, KILLAURA_DMG, DMG_GENERIC);
    }
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!client || !IsClientInGame(client)) return;

    g_AmmoRef[client] = INVALID_ENT_REFERENCE;
    g_MaxClip[client] = -1;

    if (!IsPlayerAlive(client)) return;

    if (g_Noclip[client]) SetEntityMoveType(client, MOVETYPE_NOCLIP);
    if (g_God[client]) SetEntProp(client, Prop_Data, "m_takedamage", 0);
    if (g_Invis[client]) ApplyRender(client, true);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (client <= 0 || client > MaxClients) return Plugin_Continue;
    if (!IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client)) return Plugin_Continue;

    bool changed = false;

    if (g_SpeedMult[client] > 1.001)
    {
        SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", g_cvBaseSpeed.FloatValue * g_SpeedMult[client]);
        changed = true;
    }

    if (g_RapidFire[client])
    {
        int w = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
        if (w > MaxClients && IsValidEntity(w))
        {
            SetEntPropFloat(w, Prop_Send, "m_flNextPrimaryAttack", GetGameTime());
            changed = true;
        }
    }

    if (g_InfAmmo[client] && DoInfAmmo(client))
    {
        changed = true;
    }

    if (g_Aimbot[client] && (buttons & IN_ATTACK) && !(buttons & IN_ATTACK2))
    {
        int w = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
        if (w > MaxClients && IsValidEntity(w) && GetGameTime() >= GetEntPropFloat(w, Prop_Send, "m_flNextPrimaryAttack"))
        {
            if (DoSilentAim(client, angles))
            {
                changed = true;
            }
        }
    }

    return changed ? Plugin_Changed : Plugin_Continue;
}

bool DoInfAmmo(int client)
{
    int w = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
    if (w <= MaxClients || !IsValidEntity(w)) return false;

    int ref = EntIndexToEntRef(w);
    if (ref != g_AmmoRef[client])
    {
        g_AmmoRef[client] = ref;
        int clip = GetEntProp(w, Prop_Send, "m_iClip1");
        g_MaxClip[client] = clip;
    }

    bool changed = false;

    int clip = GetEntProp(w, Prop_Send, "m_iClip1");
    if (clip > g_MaxClip[client]) g_MaxClip[client] = clip;

    if (clip != -1 && clip < g_MaxClip[client])
    {
        SetEntProp(w, Prop_Send, "m_iClip1", g_MaxClip[client]);
        changed = true;
    }

    int atype = GetEntProp(w, Prop_Send, "m_iPrimaryAmmoType");
    if (atype >= 0)
    {
        int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, atype);
        if (ammo < 200)
        {
            SetEntProp(client, Prop_Send, "m_iAmmo", 200, _, atype);
            changed = true;
        }
    }

    return changed;
}

bool DoSilentAim(int client, float angles[3])
{
    float eye[3], fwd[3];
    GetClientEyePosition(client, eye);
    GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);

    float cosFov = Cosine(DegToRad(AIMBOT_FOV));
    float bestDot = 0.0;
    int best = -1;
    float bestHead[3];
    int team = GetClientTeam(client);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i)) continue;
        if (GetClientTeam(i) == team) continue;
        if (TF2_IsPlayerInCondition(i, TFCond_DeadRingered)) continue;

        float head[3];
        GetClientEyePosition(i, head);

        float dir[3];
        SubtractVectors(head, eye, dir);
        float dist = GetVectorLength(dir);
        if (dist > 8000.0) continue;

        NormalizeVector(dir, dir);
        float dot = GetVectorDotProduct(fwd, dir);
        if (dot < cosFov || dot <= bestDot) continue;

        if (!CanSeePoint(eye, head)) continue;

        bestDot = dot;
        best = i;
        CopyVec(head, bestHead);
    }

    if (best == -1) return false;

    float dir[3];
    SubtractVectors(bestHead, eye, dir);
    NormalizeVector(dir, dir);
    GetVectorAngles(dir, angles);
    return true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity > 0 && entity < PROJ_TRACK_MAX)
    {
        g_ProjLastTime[entity] = 0.0;
    }
    if (strncmp(classname, "tf_projectile_", 14) == 0 && !StrEqual(classname, "tf_projectile_sticky_bomb") && !StrEqual(classname, "tf_projectile_grapplinghook"))
    {
        g_ProjList.Push(EntIndexToEntRef(entity));
        Dbg(6, "registered cls=%s ent=%d", classname, entity);
    }
}

public void OnGameFrame()
{
    int count = g_ProjList.Length;
    if (!count) return;

    for (int i = count - 1; i >= 0; i--)
    {
        int ent = EntRefToEntIndex(g_ProjList.Get(i));
        if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent))
        {
            g_ProjList.Erase(i);
            continue;
        }
        Hook_ProjectileThink(ent);
    }
}

public Action Hook_ProjectileThink(int entity)
{
    int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    char src[12] = "ownerent";

    if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
    {
        int thr = ResolveThrower(entity);
        if (thr != -1)
        {
            owner = thr;
            strcopy(src, sizeof(src), "thrower");
        }
    }

    if (g_HDebug)
    {
        char c[32];
        GetEntityClassname(entity, c, sizeof(c));
        Dbg(0, "think cls=%s ent=%d owner=%d src=%s homing=%s", c, entity, owner, src,
            (owner >= 1 && owner <= MaxClients && IsClientInGame(owner)) ? (g_Homing[owner] ? "1" : "0") : "?");
    }

    if (owner < 1 || owner > MaxClients || !IsClientInGame(owner)) return Plugin_Continue;

    if (g_HStats[owner] && !(GetEntityFlags(entity) & FL_ONGROUND))
    {
        BoostProjectileSpeed(entity);
    }

    char cls[64];
    GetEntityClassname(entity, cls, sizeof(cls));
    bool isHealBolt = StrEqual(cls, "tf_projectile_healing_bolt");

    float pos[3], vel[3];
    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);
    if (!GetProjVelocity(entity, pos, vel))
    {
        Dbg(5, "bail slow cls=%s", cls);
        return Plugin_Continue;
    }

    float speed = GetVectorLength(vel);
    bool aimHead = StrEqual(cls, "tf_projectile_arrow");

    if (!g_Homing[owner]) return Plugin_Continue;
    if (GetEntityFlags(entity) & FL_ONGROUND)
    {
        Dbg(4, "bail onground ent=%d", entity);
        return Plugin_Continue;
    }

    int ownerTeam = GetClientTeam(owner);
    int best = -1;
    float bestDistSq = HOMING_RANGE * HOMING_RANGE;
    float bestPos[3];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i)) continue;

        bool enemy = GetClientTeam(i) != ownerTeam;
        if (isHealBolt)
        {
            if (enemy) continue;
            if (GetEntProp(i, Prop_Send, "m_iHealth") >= GetEntProp(i, Prop_Data, "m_iMaxHealth")) continue;
        }
        else
        {
            if (!enemy) continue;
            if (TF2_IsPlayerInCondition(i, TFCond_Disguised)) continue;
            if (TF2_IsPlayerInCondition(i, TFCond_DeadRingered)) continue;
        }

        float body[3];
        if (aimHead)
        {
            GetClientEyePosition(i, body);
        }
        else
        {
            float mins[3], maxs[3];
            GetClientAbsOrigin(i, body);
            GetEntPropVector(i, Prop_Send, "m_vecMins", mins);
            GetEntPropVector(i, Prop_Send, "m_vecMaxs", maxs);
            body[2] += (mins[2] + maxs[2]) * 0.5;
        }
        float d[3];
        SubtractVectors(body, pos, d);
        float distSq = GetVectorLength(d);
        distSq *= distSq;
        if (distSq >= bestDistSq) continue;

        bestDistSq = distSq;
        best = i;
        CopyVec(body, bestPos);
    }

    if (best == -1)
    {
        Dbg(1, "no target owner=%d", owner);
        return Plugin_Continue;
    }

    char tname[32];
    GetClientName(best, tname, sizeof(tname));
    float td[3];
    SubtractVectors(bestPos, pos, td);
    Dbg(2, "target=%s dist=%.0f speed=%.0f", tname, GetVectorLength(td), speed);

    float wantDir[3], newVel[3];
    SubtractVectors(bestPos, pos, wantDir);
    NormalizeVector(wantDir, wantDir);
    ScaleVector(wantDir, speed);
    CopyVec(wantDir, newVel);

    ApplyProjVelocity(entity, newVel);
    Dbg(3, "steered old=%.0f,%.0f,%.0f new=%.0f,%.0f,%.0f vphys=1", vel[0], vel[1], vel[2], newVel[0], newVel[1], newVel[2]);
    return Plugin_Continue;
}

public Action Hook_TakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsClientInGame(victim)) return Plugin_Continue;

    if (g_NoFall[victim] && (damagetype & DMG_FALL))
    {
        return Plugin_Handled;
    }

    if (attacker >= 1 && attacker <= MaxClients && attacker != victim)
    {
        if (g_OneShot[attacker])
        {
            damage *= 10000.0;
            return Plugin_Changed;
        }
        if (g_HStats[attacker])
        {
            damage *= HSTATS_DMG_MULT;
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

int ResolveThrower(int entity)
{
    if (HasEntProp(entity, Prop_Send, "m_hThrower"))
    {
        int t = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
        if (t >= 1 && t <= MaxClients && IsClientInGame(t)) return t;
    }
    if (HasEntProp(entity, Prop_Data, "m_hThrower"))
    {
        int t = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
        if (t >= 1 && t <= MaxClients && IsClientInGame(t)) return t;
    }
    return -1;
}

void Dbg(int slot, const char[] fmt, any ...)
{
    if (!g_HDebug) return;
    float now = GetGameTime();
    if (now < g_DbgT[slot]) return;
    g_DbgT[slot] = now + 0.5;

    char buf[254];
    VFormat(buf, sizeof(buf), fmt, 3);
    PrintToServer("[hdbg] %s", buf);
}

public Action Cmd_HDebug(int client, int args)
{
    g_HDebug = !g_HDebug;
    ReplyToCommand(client, "[tfhacks] homing debug %s (server console)", g_HDebug ? "ON" : "OFF");
    return Plugin_Handled;
}

bool GetProjVelocity(int entity, const float pos[3], float vel[3])
{
    GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vel);

    bool ok = GetVectorLength(vel) > 10.0;

    if (!ok && entity > 0 && entity < PROJ_TRACK_MAX)
    {
        float now = GetGameTime();
        float dt = now - g_ProjLastTime[entity];

        if (g_ProjLastTime[entity] > 0.0 && dt > 0.001 && dt < 1.0)
        {
            float delta[3];
            SubtractVectors(pos, g_ProjLastPos[entity], delta);
            ScaleVector(delta, 1.0 / dt);
            CopyVec(delta, vel);
            ok = GetVectorLength(vel) > 10.0;
        }

        g_ProjLastPos[entity][0] = pos[0];
        g_ProjLastPos[entity][1] = pos[1];
        g_ProjLastPos[entity][2] = pos[2];
        g_ProjLastTime[entity] = now;
    }

    return ok;
}

void ApplyProjVelocity(int entity, const float vel[3])
{
    float ang[3];
    GetVectorAngles(vel, ang);

    if (HasEntProp(entity, Prop_Send, "m_vInitialVelocity"))
    {
        SetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", vel);
    }
    if (HasEntProp(entity, Prop_Data, "m_vInitialVelocity"))
    {
        SetEntPropVector(entity, Prop_Data, "m_vInitialVelocity", vel);
    }

    SetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vel);
    SetEntPropVector(entity, Prop_Data, "m_vecVelocity", vel);

    if (Phys_IsPhysicsObject(entity))
    {
        float spin[3];
        Phys_Wake(entity);
        Phys_SetVelocity(entity, vel, spin, true);
    }

    TeleportEntity(entity, NULL_VECTOR, ang, vel);
}

void BoostProjectileSpeed(int entity)
{
    int ref = EntIndexToEntRef(entity);
    char key[16];
    IntToString(ref, key, sizeof(key));

    bool dummy;
    if (g_ProjScaled.GetValue(key, dummy)) return;

    float vel[3];
    GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vel);
    if (GetVectorLength(vel) < 10.0) return;

    ScaleVector(vel, HSTATS_PROJ_MULT);
    ApplyProjVelocity(entity, vel);
    g_ProjScaled.SetValue(key, true, true);

    if (g_ProjScaled.Size > 4096)
    {
        g_ProjScaled.Clear();
    }
}

void DoInstaBuild(int client)
{
    int team = GetClientTeam(client);
    InstaScan("obj_sentrygun", client, team, true);
    InstaScan("obj_dispenser", client, team, false);
    InstaScan("obj_teleporter", client, team, false);
}

void InstaScan(const char[] classname, int client, int team, bool isSentry)
{
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, classname)) != -1)
    {
        if (!IsValidEntity(ent)) continue;
        if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") != client) continue;
        if (GetEntProp(ent, Prop_Send, "m_iTeamNum") != team) continue;

        if (GetEntProp(ent, Prop_Send, "m_bBuilding"))
        {
            SetEntProp(ent, Prop_Send, "m_bBuilding", false);
        }
        if (GetEntProp(ent, Prop_Send, "m_bPlacing"))
        {
            SetEntProp(ent, Prop_Send, "m_bPlacing", false);
        }

        float built = GetEntPropFloat(ent, Prop_Send, "m_flPercentageConstructed");
        int maxhp = GetEntProp(ent, Prop_Data, "m_iMaxHealth");
        if (built < 1.0 || GetEntProp(ent, Prop_Send, "m_iHealth") < maxhp)
        {
            SetEntPropFloat(ent, Prop_Send, "m_flPercentageConstructed", 1.0);
            SetEntProp(ent, Prop_Send, "m_iHealth", maxhp);
        }

        if (isSentry && GetEntProp(ent, Prop_Send, "m_iUpgradeLevel") < 3)
        {
            UpgradeSentry(ent);
        }
    }
}

void UpgradeSentry(int ent)
{
    SetEntityModel(ent, SENTRY3_MODEL);
    SetEntProp(ent, Prop_Send, "m_iUpgradeLevel", 3);
    SetEntProp(ent, Prop_Send, "m_iHighestUpgradeLevel", 3);
    SetEntProp(ent, Prop_Send, "m_iAmmoShells", SENTRY3_SHELLS);
    SetEntProp(ent, Prop_Send, "m_iAmmoRockets", SENTRY3_ROCKETS);
    SetEntProp(ent, Prop_Data, "m_iMaxHealth", SENTRY3_HEALTH);
    SetEntProp(ent, Prop_Send, "m_iHealth", SENTRY3_HEALTH);
}

void CopyVec(const float src[3], float dst[3])
{
    dst[0] = src[0];
    dst[1] = src[1];
    dst[2] = src[2];
}

bool CanSeePoint(float start[3], float end[3])
{
    Handle tr = TR_TraceRayFilterEx(start, end, MASK_SHOT, RayType_EndPoint, TraceFilter_IgnoreClients);
    bool visible = !TR_DidHit(tr);
    delete tr;
    return visible;
}

public bool TraceFilter_IgnoreClients(int entity, int contentsMask)
{
    return !(entity >= 1 && entity <= MaxClients);
}

void ApplyRender(int client, bool invisible)
{
    if (invisible)
    {
        SetEntityRenderMode(client, RENDER_TRANSCOLOR);
        SetEntityRenderColor(client, 255, 255, 255, 0);
    }
    else
    {
        SetEntityRenderMode(client, RENDER_NORMAL);
        SetEntityRenderColor(client, 255, 255, 255, 255);
    }
}
