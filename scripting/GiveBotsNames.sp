#include <sourcemod>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.02"

bool g_bMVM = false;
int g_iNamesArraySize = 0;
int g_iNamesFilePosition = 0;
char g_sNamesFilePath[PLATFORM_MAX_PATH];
ConVar g_hCVEnabled;
ConVar g_hCVTeam;
ConVar g_hCVMVMSupport;
ConVar g_hCVPrefix;
ConVar g_hCVSuffix;
ConVar g_hCVRandomize;
ConVar g_hCVEnforceNameChange;
ConVar g_hCVRenameOnReload;
ConVar g_hCVSuppressNameChangeText;
Handle g_hOrderedNamesArray;
Handle g_hRandomizedNamesArray;
Handle g_hSelectedNamesArray;

public Plugin myinfo =
{
	name = "Give Bots Names",
	author = "luki1412",
	description = "Gives TF2 bots custom names",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/member.php?u=43109"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		Format(error, err_max, "This plugin only works for Team Fortress 2.");
		return APLRes_Failure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	ConVar hCVversioncvar = CreateConVar("sm_gbn_version", PLUGIN_VERSION, "Give Bots Names version cvar", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCVEnabled = CreateConVar("sm_gbn_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVTeam = CreateConVar("sm_gbn_team", "1", "Team whose players get renamed: 1-both, 2-red, 3-blu", FCVAR_NONE, true, 1.0, true, 3.0);
	g_hCVMVMSupport = CreateConVar("sm_gbn_mvm", "0", "Enables/disables giving bots names when MVM mode is enabled", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVPrefix = CreateConVar("sm_gbn_prefix", "", "Prefix for all bot names. Requires names reload and rename trigger.", FCVAR_NONE);
	g_hCVSuffix = CreateConVar("sm_gbn_suffix", "", "Suffix for all bot names. Requires names reload and rename trigger.", FCVAR_NONE);
	g_hCVRandomize = CreateConVar("sm_gbn_randomize", "1", "Enables/disables randomizing names from the file. Takes Effect on next bot renaming.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVEnforceNameChange = CreateConVar("sm_gbn_enforcenames", "0", "Enables/disables enforcing names by catching name changes. This has a performance impact.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVRenameOnReload = CreateConVar("sm_gbn_renameonreload", "1", "Enables disables checking and renaming all bots after the bot names file is reloaded.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVSuppressNameChangeText = CreateConVar("sm_gbn_suppressnamechangetext", "1", "Enables/disables suppressing chat text when bots are renamed.", FCVAR_NONE, true, 0.0, true, 1.0);
    RegAdminCmd("sm_gbn_reloadnames", ReloadNames, ADMFLAG_CONFIG, "Reloads the file with names.");

	OnEnabledChanged(g_hCVEnabled, "", "");
	HookConVarChange(g_hCVEnabled, OnEnabledChanged);
	SetConVarString(hCVversioncvar, PLUGIN_VERSION);
	AutoExecConfig(true, "Give_Bots_Names");
	BuildPath(Path_SM, g_sNamesFilePath, sizeof(g_sNamesFilePath), "configs/GiveBotsNames.txt");
	UserMsg SayText2 = GetUserMessageId("SayText2");

	if (SayText2 == INVALID_MESSAGE_ID)
	{
		LogError("This game doesn't support SayText2. Unable to suppress chat messages.");
	}
	else 
	{
		HookUserMessage(SayText2, UserMessage_SayText2, true);
	}
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarBool(g_hCVEnabled))
	{
		HookEvent("player_changename", Event_PlayerChangename);
		HookEvent("player_team", Event_PlayerTeam);

	}
	else
	{
		UnhookEvent("player_changename", Event_PlayerChangename);
		UnhookEvent("player_team", Event_PlayerTeam);
	}
}

public void OnRandomizeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_hSelectedNamesArray = GetConVarBool(g_hCVRandomize) == true ? g_hRandomizedNamesArray : g_hOrderedNamesArray;
}

public void OnMapStart()
{
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		g_bMVM = true;
	}
}

public void OnConfigsExecuted()
{
	ReloadNames(0,0);
}

public Action UserMessage_SayText2(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!GetConVarBool(g_hCVEnabled) || !GetConVarBool(g_hCVSuppressNameChangeText))
	{
		return Plugin_Continue;
	}

	char message[256];
	BfReadShort(bf);
	BfReadString(bf, message, sizeof(message));

	if (StrContains(message, "Name_Change") != -1)
	{
		BfReadString(bf, message, sizeof(message));

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsPlayerHere(i))
			{
				continue;
			}
			
			char currentName[MAX_NAME_LENGTH];
			GetClientName(i, currentName, sizeof(currentName));

			if (StrEqual(message, currentName))
			{
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

Action ReloadNames(int client, int args)
{
	Handle file = OpenFile(g_sNamesFilePath, "r");

	if (file == null)
	{
		ReplyToCommand(client, "Could not open the bot names file - GiveBotsNames.txt!");
		SetFailState("Could not open the bot names file - GiveBotsNames.txt!");
		return Plugin_Handled;
	}

	g_iNamesFilePosition = 0;

	if (g_hOrderedNamesArray != null)
	{
		ClearArray(g_hOrderedNamesArray);
	}
	else
	{
		g_hOrderedNamesArray = CreateArray(MAX_NAME_LENGTH);
	}

	if (g_hRandomizedNamesArray != null)
	{
		ClearArray(g_hRandomizedNamesArray);
	}
	else
	{
		g_hRandomizedNamesArray = CreateArray(MAX_NAME_LENGTH);
	}

	char prefix[MAX_NAME_LENGTH/2], suffix[MAX_NAME_LENGTH/2];
	GetConVarString(g_hCVPrefix, prefix, sizeof(prefix));
	GetConVarString(g_hCVSuffix, suffix, sizeof(suffix));

	while (!IsEndOfFile(file))
	{
		char combinedName[MAX_NAME_LENGTH], newName[MAX_NAME_LENGTH];

		if (!ReadFileLine(file, newName, sizeof(newName)))
		{
			break;
		}

		TrimString(newName);

		if ((newName[0] == ';') || (strlen(newName) < 1))
		{
			continue;
		}

		Format(combinedName, sizeof(combinedName), "%s%s%s", prefix, newName, suffix);
		PushArrayString(g_hOrderedNamesArray, combinedName);
		PushArrayString(g_hRandomizedNamesArray, combinedName);
	}

	delete file;
	RandomizeNames();
	g_hSelectedNamesArray = GetConVarBool(g_hCVRandomize) == true ? g_hRandomizedNamesArray : g_hOrderedNamesArray;
	g_iNamesArraySize = GetArraySize(g_hSelectedNamesArray);
	ReplyToCommand(client, "Bot name file GiveBotsNames.txt loaded");

	if (g_iNamesArraySize == 0)
	{
		LogError("No valid names inside GiveBotsNames.txt! Using Bot");
		ReplyToCommand(client, "No valid names inside GiveBotsNames.txt! Using Bot");
		PushArrayString(g_hOrderedNamesArray, "Bot");
		PushArrayString(g_hRandomizedNamesArray, "Bot");
		g_iNamesArraySize = GetArraySize(g_hSelectedNamesArray);
	}

	if (!GetConVarBool(g_hCVEnabled) || !GetConVarBool(g_hCVRenameOnReload) || (g_bMVM && !GetConVarBool(g_hCVMVMSupport)))
	{
		return Plugin_Handled;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsPlayerHere(i))
		{
			RenameClient(i);
		}
	}

	return Plugin_Handled;
}

void RandomizeNames()
{
	int botNamesArraySize = GetArraySize(g_hRandomizedNamesArray);

	for (int i = 1; i < botNamesArraySize; i++)
	{
		SwapArrayItems(g_hRandomizedNamesArray, GetRandomUInt(0, i - 1), i);
	}
}

void RenameClient(int client)
{
	if ((g_hSelectedNamesArray == null) || (g_iNamesArraySize < 1))
	{
		return;
	}

	char currentName[MAX_NAME_LENGTH];
	GetClientName(client, currentName, MAX_NAME_LENGTH);

	if (currentName[0] == '(' && IsCharNumeric(currentName[1]))
	{
		if (currentName[2] == ')')
		{
			currentName[0] = ' ';
			currentName[1] = ' ';
			currentName[2] = ' ';
			TrimString(currentName);
		}
		else if (IsCharNumeric(currentName[2]) && currentName[3] == ')')
		{
			currentName[0] = ' ';
			currentName[1] = ' ';
			currentName[2] = ' ';
			currentName[3] = ' ';
			TrimString(currentName);
		}
	}

	if (FindStringInArray(g_hSelectedNamesArray, currentName) != -1 )
	{
		return;
	}

	char newName[MAX_NAME_LENGTH];
	PullNextName(newName);
	strcopy(currentName, sizeof(newName), newName);
	int playersWithThisName = 0;

	while (IsNameInUse(newName))
	{
		playersWithThisName++;
		Format(newName, sizeof(newName), "(%i)%s", playersWithThisName, currentName);
	}

	SetClientName(client, newName);
}

bool IsNameInUse(char[] name)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			char currentName[MAX_NAME_LENGTH];
			GetClientName(i, currentName, MAX_NAME_LENGTH);

			if (StrEqual(currentName, name, false))
			{
				return true;
			}
		}
	}

	return false;
}

void PullNextName(char[] nextName)
{
	GetArrayString(g_hSelectedNamesArray, g_iNamesFilePosition, nextName, MAX_NAME_LENGTH);
	g_iNamesFilePosition++;

	if (g_iNamesFilePosition > (g_iNamesArraySize - 1))
	{
		g_iNamesFilePosition = 0;
	}
}

public void Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(g_hCVEnabled) || (g_bMVM && !GetConVarBool(g_hCVMVMSupport)))
	{
		return;
	}

	int userId = GetEventInt(event, "userid");
	RequestFrame(BotRenameFrame, userId);
	return;
}

public void Event_PlayerChangename(Handle event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(g_hCVEnabled) || !GetConVarBool(g_hCVEnforceNameChange) || (g_bMVM && !GetConVarBool(g_hCVMVMSupport)))
	{
		return;
	}

	int userId = GetEventInt(event, "userid");
	RequestFrame(BotRenameFrame, userId);
	return;
}

void BotRenameFrame(int userId)
{
	int client = GetClientOfUserId(userId);

	if (!IsPlayerHere(client))
	{
		return;
	}

	int team = GetClientTeam(client);
	int team2 = GetConVarInt(g_hCVTeam);

	switch (team2)
	{
		case 1:
		{
			RenameClient(client);
		}
		case 2:
		{
			if (team == 2)
			{
				RenameClient(client);
			}
		}
		case 3:
		{
			if (team == 3)
			{
				RenameClient(client);
			}
		}
	}
}

bool IsPlayerHere(int client)
{
	return (client && IsClientInGame(client) && IsFakeClient(client) && !IsClientReplay(client) && !IsClientSourceTV(client));
}

int GetRandomUInt(int min, int max)
{
	return RoundToFloor(GetURandomFloat() * (max - min + 1)) + min;
}