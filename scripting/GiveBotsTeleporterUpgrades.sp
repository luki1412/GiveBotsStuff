#include <sourcemod>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.01"
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
	ConVar hCVVersioncvar = CreateConVar("sm_gbtu_version", PLUGIN_VERSION, "Give Bots Teleporter Upgrades version cvar", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCVEnabled = CreateConVar("sm_gbtu_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVTimer = CreateConVar("sm_gbtu_delay", "10.0", "Delay between upgrade attempts, starting when a bot teleporter is created", FCVAR_NONE, true, 1.0, true, 300.0);
	g_hCVTeam = CreateConVar("sm_gbtu_team", "1", "Team to give teleport upgrades to: 1-both, 2-red, 3-blu", FCVAR_NONE, true, 1.0, true, 3.0);
	g_hCVMVMSupport = CreateConVar("sm_gbtu_mvm", "0", "Enables/disables giving teleport upgrades when MVM mode is enabled", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVRequireMetal = CreateConVar("sm_gbtu_consumemetal", "1", "Enables/disables consuming full metal amount, needed for a level upgrade, at the teleporter upgrade time. The teleporter is not upgraded until the bot has enough metal.", FCVAR_NONE, true, 0.0, true, 1.0);

	OnEnabledChanged(g_hCVEnabled, "", "");
	HookConVarChange(g_hCVEnabled, OnEnabledChanged);
	SetConVarString(hCVVersioncvar, PLUGIN_VERSION);
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
	delete hCVVersioncvar;
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

	int objectId = GetEventInt(event,"index");
	int objectType = GetEntProp(objectId, Prop_Send, "m_iObjectType");

	if (objectType != view_as<int>(TFObject_Teleporter))
	{
		return;
	}

	int teleType = GetEntProp(objectId, Prop_Data, "m_iTeleportType");

	if (teleType != TELEPORTER_ENTRANCE)
	{
		return;
	}

	int userId = GetEventInt(event,"userid");
	int client = GetClientOfUserId(userId);

	if (!IsPlayerHere(client))
	{
		return;
	}

	float cvdelay = GetConVarFloat(g_hCVTimer);
	int team = GetClientTeam(client);
	int cvteam = GetConVarInt(g_hCVTeam);

	switch (cvteam)
	{
		case 1:
		{
			g_hTeleportBuilt[client] = CreateTimer(cvdelay, Timer_UpgradeTeleporter, userId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
			g_iTeleportId[client] = EntIndexToEntRef(objectId);
		}
		case 2:
		{
			if (team == 2)
			{
				g_hTeleportBuilt[client] = CreateTimer(cvdelay, Timer_UpgradeTeleporter, userId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
				g_iTeleportId[client] = EntIndexToEntRef(objectId);
			}
		}
		case 3:
		{
			if (team == 3)
			{
				g_hTeleportBuilt[client] = CreateTimer(cvdelay, Timer_UpgradeTeleporter, userId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
				g_iTeleportId[client] = EntIndexToEntRef(objectId);
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

	int objectId = EntRefToEntIndex(g_iTeleportId[client]);

	if (!IsValidEntity(objectId) || objectId < 1)
	{
		g_hTeleportBuilt[client] = null;
		g_iTeleportId[client] = 0;
		return Plugin_Stop;
	}

	if (GetEntProp(objectId, Prop_Send, "m_bBuilding") == 1 || GetEntProp(objectId, Prop_Send, "m_bHasSapper") == 1 || GetEntProp(objectId, Prop_Send, "m_bCarried") == 1 || GetEntProp(objectId, Prop_Send, "m_bPlacing") == 1)
	{
		return Plugin_Continue;
	}

	int objectLevel = GetEntProp(objectId, Prop_Send, "m_iUpgradeLevel");
	int matchingTele = GetMatchingTeleporter(objectId);

	if (objectLevel < 3)
	{
		if (GetConVarBool(g_hCVRequireMetal))
		{
			int clientMetal = GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3);
			int metalSpent = GetEntProp(objectId, Prop_Send, "m_iUpgradeMetal");
			int metalTotalRequired = GetEntProp(objectId, Prop_Send, "m_iUpgradeMetalRequired");
			int metalCurrentlyRequired = metalTotalRequired - metalSpent;

			if (clientMetal >= metalCurrentlyRequired)
			{
				SetEntProp(client, Prop_Data, "m_iAmmo", (clientMetal-metalCurrentlyRequired), 4, 3);
				SetEntProp(objectId, Prop_Send, "m_iUpgradeMetal", 0);
				SDKCall(g_hBuildingStartUpgrading, objectId);
			}
		}
		else
		{
			SDKCall(g_hBuildingStartUpgrading, objectId);
		}
	}

	if (matchingTele > 0)
	{
		objectLevel = GetEntProp(objectId, Prop_Send, "m_iUpgradeLevel");
		int matchedTeleLevel = GetEntProp(matchingTele, Prop_Send, "m_iUpgradeLevel");

		if (matchedTeleLevel != objectLevel && matchedTeleLevel < 3 && GetEntProp(matchingTele, Prop_Send, "m_bHasSapper") != 1 && GetEntProp(matchingTele, Prop_Send, "m_bCarried") != 1 && GetEntProp(matchingTele, Prop_Send, "m_bPlacing") != 1)
		{
			SetEntProp(matchingTele, Prop_Send, "m_iUpgradeMetal", 0);

			if (GetEntProp(matchingTele, Prop_Send, "m_bBuilding") == 1)
			{
				SetEntProp(matchingTele, Prop_Send, "m_iUpgradeLevel",objectLevel);
				SetEntProp(matchingTele, Prop_Send, "m_iHighestUpgradeLevel",objectLevel);
			}
			else
			{
				SDKCall(g_hBuildingStartUpgrading, matchingTele);
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

	int objectId = GetEventInt(event, "index");
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int storedObjectId = EntRefToEntIndex(g_iTeleportId[client]);

	if (storedObjectId == objectId)
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