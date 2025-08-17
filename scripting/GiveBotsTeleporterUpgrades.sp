#include <sourcemod>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.00"
#define TELEPORTER_ENTRANCE 1
#define TELEPORTER_EXIT 2

bool g_bMVM;
int g_iTeleportId[MAXPLAYERS+1];
int g_iOffsetForMatchingTeleporters;
ConVar g_hCVTimer;
ConVar g_hCVEnabled;
ConVar g_hCVTeam;
ConVar g_hCVMVMSupport;
ConVar g_hCVRequireMetal;
Handle g_hTeleportBuilt[MAXPLAYERS+1];
Handle g_hBuildingStartUpgrading;

public Plugin myinfo =
{
	name = "Give Bots Teleporter Upgrades",
	author = "luki1412",
	description = "Gives TF2 bots teleporter upgrades",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/member.php?u=43109"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		FormatEx(error, err_max, "This plugin only works for Team Fortress 2.");
		return APLRes_Failure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	ConVar hCVversioncvar = CreateConVar("sm_gbtu_version", PLUGIN_VERSION, "Give Bots Teleporter Upgrades version cvar", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCVEnabled = CreateConVar("sm_gbtu_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVTimer = CreateConVar("sm_gbtu_delay", "10.0", "Delay between upgrade attempts, starting when a bot teleporter is created", FCVAR_NONE, true, 1.0, true, 300.0);
	g_hCVTeam = CreateConVar("sm_gbtu_team", "1", "Team to give teleport upgrades to: 1-both, 2-red, 3-blu", FCVAR_NONE, true, 1.0, true, 3.0);
	g_hCVMVMSupport = CreateConVar("sm_gbtu_mvm", "0", "Enables/disables giving teleport upgrades when MVM mode is enabled", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVRequireMetal = CreateConVar("sm_gbtu_consumegmetal", "1", "Enables/disables consuming full metal amount, needed for a level upgrade, at the teleporter upgrade time. The teleporter is not upgraded until the bot has enough metal.", FCVAR_NONE, true, 0.0, true, 1.0);

	OnEnabledChanged(g_hCVEnabled, "", "");
	HookConVarChange(g_hCVEnabled, OnEnabledChanged);

	SetConVarString(hCVversioncvar, PLUGIN_VERSION);
	AutoExecConfig(true, "Give_Bots_Teleport_Upgrades");

	GameData hGameConfig = LoadGameConfigFile("give.bots.stuff");

	if (!hGameConfig)
	{
		SetFailState("Failed to find give.bots.stuff.txt gamedata! Can't continue.");
	}

	g_iOffsetForMatchingTeleporters = GameConfGetOffset(hGameConfig, "MatchingTeleporter");
	StartPrepSDKCall(SDKCall_Entity);

	if (!PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "BuildingStartUpgrading"))
	{
		SetFailState("Failed to prepare the SDKCall for upgrading teleporters. Try updating gamedata or restarting your server.");
	}

	g_hBuildingStartUpgrading = EndPrepSDKCall();

	if (!g_hBuildingStartUpgrading)
	{
		SetFailState("Failed to prepare the SDKCall for upgrading teleporters. Try updating gamedata or restarting your server.");
	}

	delete hGameConfig;
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarBool(g_hCVEnabled))
	{
		HookEvent("player_builtobject", player_builtobject);
		HookEvent("object_removed", object_removed);
	}
	else
	{
		UnhookEvent("player_builtobject", player_builtobject);
		UnhookEvent("object_removed", object_removed);
	}
}

public void OnMapStart()
{
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		g_bMVM = true;
	}
}

public void OnClientDisconnect(int client)
{
	delete g_hTeleportBuilt[client];
	g_iTeleportId[client] = 0;
}

public void player_builtobject(Handle event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(g_hCVEnabled) || (g_bMVM && !GetConVarBool(g_hCVMVMSupport)))
	{
		return;
	}

	int objectid = GetEventInt(event,"index");
	int objtype = GetEntProp(objectid, Prop_Send, "m_iObjectType");

	if (objtype != view_as<int>(TFObject_Teleporter))
	{
		return;
	}

	int teletype = GetEntProp(objectid, Prop_Data, "m_iTeleportType");

	if (teletype != TELEPORTER_ENTRANCE)
	{
		return;
	}

	int userId = GetEventInt(event,"userid");
	int client = GetClientOfUserId(userId);

	if (!IsPlayerHere(client))
	{
		return;
	}

	float timer = GetConVarFloat(g_hCVTimer);
	int team = GetClientTeam(client);
	int team2 = GetConVarInt(g_hCVTeam);

	switch (team2)
	{
		case 1:
		{
			g_hTeleportBuilt[client] = CreateTimer(timer, Timer_UpgradeTeleporter, userId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
			g_iTeleportId[client] = EntIndexToEntRef(objectid);
		}
		case 2:
		{
			if (team == 2)
			{
				g_hTeleportBuilt[client] = CreateTimer(timer, Timer_UpgradeTeleporter, userId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
				g_iTeleportId[client] = EntIndexToEntRef(objectid);
			}
		}
		case 3:
		{
			if (team == 3)
			{
				g_hTeleportBuilt[client] = CreateTimer(timer, Timer_UpgradeTeleporter, userId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
				g_iTeleportId[client] = EntIndexToEntRef(objectid);
			}
		}
	}
}

public Action Timer_UpgradeTeleporter(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (!GetConVarBool(g_hCVEnabled) || (g_bMVM && !GetConVarBool(g_hCVMVMSupport)) || !IsPlayerHere(client))
	{
		g_hTeleportBuilt[client] = null;
		g_iTeleportId[client] = 0;
		return Plugin_Stop;
	}

	int objectid = EntRefToEntIndex(g_iTeleportId[client]);

	if (!IsValidEntity(objectid) || objectid < 1)
	{
		g_hTeleportBuilt[client] = null;
		g_iTeleportId[client] = 0;
		return Plugin_Stop;
	}

	if (GetEntProp(objectid, Prop_Send, "m_bBuilding") == 1 || GetEntProp(objectid, Prop_Send, "m_bHasSapper") == 1 || GetEntProp(objectid, Prop_Send, "m_bCarried") == 1 || GetEntProp(objectid, Prop_Send, "m_bPlacing") == 1)
	{
		return Plugin_Continue;
	}

	int objectlevel = GetEntProp(objectid, Prop_Send, "m_iUpgradeLevel");
	int matchingtele = GetMatchingTeleporter(objectid);

	if (objectlevel < 3)
	{
		if (GetConVarBool(g_hCVRequireMetal))
		{
			int clientsmetal = GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3);
			int metalspent = GetEntProp(objectid, Prop_Send, "m_iUpgradeMetal");
			int metalrequired = GetEntProp(objectid, Prop_Send, "m_iUpgradeMetalRequired");
			int metaltotake = metalrequired - metalspent;

			if (clientsmetal >= metaltotake)
			{
				SetEntProp(client, Prop_Data, "m_iAmmo", (clientsmetal-metaltotake), 4, 3);
				SetEntProp(objectid, Prop_Send, "m_iUpgradeMetal", 0);
				SDKCall(g_hBuildingStartUpgrading, objectid);
			}
		}
		else
		{
			SetEntProp(objectid, Prop_Send, "m_iUpgradeMetal", 0);
			SDKCall(g_hBuildingStartUpgrading, objectid);
		}
	}

	if (matchingtele > 0)
	{
		objectlevel = GetEntProp(objectid, Prop_Send, "m_iUpgradeLevel");
		int matchedtelelevel = GetEntProp(matchingtele, Prop_Send, "m_iUpgradeLevel");

		if (matchedtelelevel != objectlevel && matchedtelelevel < 3 && GetEntProp(matchingtele, Prop_Send, "m_bHasSapper") != 1 && GetEntProp(matchingtele, Prop_Send, "m_bCarried") != 1 && GetEntProp(matchingtele, Prop_Send, "m_bPlacing") != 1)
		{
			SetEntProp(matchingtele, Prop_Send, "m_iUpgradeMetal", 0);

			if (GetEntProp(matchingtele, Prop_Send, "m_bBuilding") == 1)
			{
				SetEntProp(matchingtele, Prop_Send, "m_iUpgradeLevel",objectlevel);
				SetEntProp(matchingtele, Prop_Send, "m_iHighestUpgradeLevel",objectlevel);
			}
			else
			{
				SDKCall(g_hBuildingStartUpgrading, matchingtele);
			}
		}
	}

	return Plugin_Continue;
}

public void object_removed(Handle event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(g_hCVEnabled) || (g_bMVM && !GetConVarBool(g_hCVMVMSupport)))
	{
		return;
	}

	int objectid = GetEventInt(event,"index");
	int userId = GetEventInt(event,"userid");
	int client = GetClientOfUserId(userId);
	int storedobjtid = EntRefToEntIndex(g_iTeleportId[client]);

	if (storedobjtid == objectid)
	{
		g_iTeleportId[client] = 0;

		if (g_hTeleportBuilt[client] != null)
		{
			delete g_hTeleportBuilt[client];
		}
	}
}

int GetMatchingTeleporter(int ent)
{
	int matchingTeleporter = -1;

	if (IsValidEntity(ent) && HasEntProp(ent, Prop_Send, "m_bMatchBuilding"))
	{
		int offset = FindSendPropInfo("CObjectTeleporter", "m_bMatchBuilding") + g_iOffsetForMatchingTeleporters;
		matchingTeleporter = GetEntDataEnt2(ent, offset);
	}

	return matchingTeleporter;
}

bool IsPlayerHere(int client)
{
	return (client && IsClientInGame(client) && IsFakeClient(client) && !IsClientReplay(client) && !IsClientSourceTV(client));
}