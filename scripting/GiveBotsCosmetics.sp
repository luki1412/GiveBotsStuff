#include <sourcemod>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.41"

bool g_bMVM;
bool g_bLateLoad;
ConVar g_hCVTimer;
ConVar g_hCVEnabled;
ConVar g_hCVTeam;
ConVar g_hCVMVMSupport;
Handle g_hWearableEquip;
Handle g_hTouched[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "Give Bots Cosmetics",
	author = "luki1412",
	description = "Gives TF2 bots cosmetics",
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

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	ConVar hCVversioncvar = CreateConVar("sm_gbc_version", PLUGIN_VERSION, "Give Bots Cosmetics version cvar", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCVEnabled = CreateConVar("sm_gbc_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVTimer = CreateConVar("sm_gbc_delay", "0.1", "Delay for giving cosmetics to bots", FCVAR_NONE, true, 0.1, true, 30.0);
	g_hCVTeam = CreateConVar("sm_gbc_team", "1", "Team to give cosmetics to: 1-both, 2-red, 3-blu", FCVAR_NONE, true, 1.0, true, 3.0);
	g_hCVMVMSupport = CreateConVar("sm_gbc_mvm", "0", "Enables/disables giving bots cosmetics when MVM mode is enabled", FCVAR_NONE, true, 0.0, true, 1.0);

	OnEnabledChanged(g_hCVEnabled, "", "");
	HookConVarChange(g_hCVEnabled, OnEnabledChanged);

	SetConVarString(hCVversioncvar, PLUGIN_VERSION);
	AutoExecConfig(true, "Give_Bots_Cosmetics");

	if (g_bLateLoad)
	{
		OnMapStart();
	}

	GameData hGameConfig = LoadGameConfigFile("give.bots.stuff");

	if (!hGameConfig)
	{
		SetFailState("Failed to find give.bots.stuff.txt gamedata! Can't continue.");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hWearableEquip = EndPrepSDKCall();

	if (!g_hWearableEquip)
	{
		SetFailState("Failed to prepare the SDKCall for giving cosmetics. Try updating gamedata or restarting your server.");
	}

	delete hGameConfig;
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarBool(g_hCVEnabled))
	{
		HookEvent("post_inventory_application", player_inv);
	}
	else
	{
		UnhookEvent("post_inventory_application", player_inv);
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
	delete g_hTouched[client];
}

public void player_inv(Handle event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarInt(g_hCVEnabled) || (g_bMVM && !GetConVarBool(g_hCVMVMSupport)))
	{
		return;
	}

	int userd = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userd);
	delete g_hTouched[client];

	if (!IsPlayerHere(client))
	{
		return;
	}

	int team = GetClientTeam(client);
	int team2 = GetConVarInt(g_hCVTeam);
	float timer = GetConVarFloat(g_hCVTimer);

	switch (team2)
	{
		case 1:
		{
			g_hTouched[client] = CreateTimer(timer, Timer_GiveCosmetic, userd, TIMER_FLAG_NO_MAPCHANGE);
		}
		case 2:
		{
			if (team == 2)
			{
				g_hTouched[client] = CreateTimer(timer, Timer_GiveCosmetic, userd, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		case 3:
		{
			if (team == 3)
			{
				g_hTouched[client] = CreateTimer(timer, Timer_GiveCosmetic, userd, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public Action Timer_GiveCosmetic(Handle timer, any data)
{
	int client = GetClientOfUserId(data);
	g_hTouched[client] = null;

	if (!GetConVarInt(g_hCVEnabled) || (g_bMVM && !GetConVarBool(g_hCVMVMSupport)) || !IsPlayerHere(client))
	{
		return Plugin_Stop;
	}

	int team = GetClientTeam(client);
	int team2 = GetConVarInt(g_hCVTeam);

	switch (team2)
	{
		case 2:
		{
			if (team != 2)
			{
				return Plugin_Stop;
			}
		}
		case 3:
		{
			if (team != 3)
			{
				return Plugin_Stop;
			}
		}
	}

	TFClassType class = TF2_GetPlayerClass(client);
	bool faceCovered = GetRandomUInt(0,1) ? SelectAllClassHat(client) : SelectClassHat(client, class);

	if (!faceCovered)
	{
		GetRandomUInt(0,1) ? SelectAllClassFacialCosmetic(client) : SelectClassFacialCosmetic(client, class);

		if(GetRandomUInt(0,1))
		{
			GetRandomUInt(0,1) ? SelectAllClassTorsoCosmetic(client) : SelectClassTorsoCosmetic(client, class);
		}
		else
		{
			GetRandomUInt(0,1) ? SelectAllClassLegsCosmetic(client) : SelectClassLegsCosmetic(client, class);
		}
	}
	else
	{
		GetRandomUInt(0,1) ? SelectAllClassTorsoCosmetic(client) : SelectClassTorsoCosmetic(client, class);
		GetRandomUInt(0,1) ? SelectAllClassLegsCosmetic(client) : SelectClassLegsCosmetic(client, class);
	}

	return Plugin_Continue;
}

bool SelectAllClassHat(int client)
{
	bool face = false;
	int rnd = GetRandomUInt(0,45);

	switch (rnd)
	{
		case 1:
		{
			CreateCosmetic(client, 940, 6, 10); //Ghostly Gibus
		}
		case 2:
		{
			CreateCosmetic(client, 668, 6); //The Full Head of Steam
		}
		case 3:
		{
			CreateCosmetic(client, 774, 6); //The Gentle Munitionne of Leisure
		}
		case 4:
		{
			CreateCosmetic(client, 941, 6, 31); //The Skull Island Topper
		}
		case 5:
		{
			CreateCosmetic(client, 30357, 6); //Dark Falkirk Helm
		}
		case 6:
		{
			CreateCosmetic(client, 538, 6); //Killer Exclusive
		}
		case 7:
		{
			CreateCosmetic(client, 139, 6); //Modest Pile of Hat
		}
		case 8:
		{
			CreateCosmetic(client, 137, 6); //Noble Amassment of Hats
		}
		case 9:
		{
			CreateCosmetic(client, 135, 6); //Towering Pillar of Hats
		}
		case 10:
		{
			CreateCosmetic(client, 30119, 6); //The Federal Casemaker
		}
		case 11:
		{
			CreateCosmetic(client, 252, 6); //Dr's Dapper Topper
		}
		case 12:
		{
			CreateCosmetic(client, 341, 6); //A Rather Festive Tree
		}
		case 13:
		{
			CreateCosmetic(client, 523, 6, 10); //The Sarif Cap
		}
		case 14:
		{
			CreateCosmetic(client, 614, 6); //The Hot Dogger
		}
		case 15:
		{
			CreateCosmetic(client, 611, 6); //The Salty Dog
		}
		case 16:
		{
			CreateCosmetic(client, 671, 6); //The Brown Bomber
		}
		case 17:
		{
			CreateCosmetic(client, 817, 6); //The Human Cannonball
		}
		case 18:
		{
			CreateCosmetic(client, 993, 6); //Antlers
		}
		case 19:
		{
			CreateCosmetic(client, 984, 6); //Tough Stuff Muffs
		}
		case 20:
		{
			CreateCosmetic(client, 1014, 6); //The Brutal Bouffant
		}
		case 21:
		{
			CreateCosmetic(client, 30066, 6); //The Brotherhood of Arms
		}
		case 22:
		{
			CreateCosmetic(client, 30067, 6); //The Well-Rounded Rifleman
		}
		case 23:
		{
			CreateCosmetic(client, 30175, 6); //The Cotton Head
		}
		case 24:
		{
			CreateCosmetic(client, 30177, 6); //Hong Kong Cone
		}
		case 25:
		{
			CreateCosmetic(client, 30313, 6); //The Kiss King
		}
		case 26:
		{
			CreateCosmetic(client, 30307, 6); //Neckwear Headwear
		}
		case 27:
		{
			CreateCosmetic(client, 30329, 6); //The Polar Pullover
		}
		case 28:
		{
			CreateCosmetic(client, 30362, 6); //The Law
		}
		case 29:
		{
			CreateCosmetic(client, 30567, 6); //The Crown of the Old Kingdom
		}
		case 30:
		{
			CreateCosmetic(client, 1164, 6, 50); //Civilian Grade JACK Hat
		}
		case 31:
		{
			CreateCosmetic(client, 920, 6); //The Crone's Dome
		}
		case 32:
		{
			CreateCosmetic(client, 30425, 6); //Tipped Lid
		}
		case 33:
		{
			CreateCosmetic(client, 30413, 6); //The Merc's Mohawk
		}
		case 34:
		{
			CreateCosmetic(client, 921, 6); //The Executioner
			face = true;
		}
		case 35:
		{
			CreateCosmetic(client, 30422, 6); //Vive La France
			face = true;
		}
		case 36:
		{
			CreateCosmetic(client, 291, 6); //Horrific Headsplitter
		}
		case 37:
		{
			CreateCosmetic(client, 345, 6, 10); //MNC hat
		}
		case 38:
		{
			CreateCosmetic(client, 785, 6, 10); //Robot Chicken Hat
		}
		case 39:
		{
			CreateCosmetic(client, 702, 6); //Warsworn Helmet
			face = true;
		}
		case 40:
		{
			CreateCosmetic(client, 634, 6); //Point and Shoot
		}
		case 41:
		{
			CreateCosmetic(client, 942, 6); //Cockfighter
		}
		case 42:
		{
			CreateCosmetic(client, 944, 6); //That 70s Chapeau
			face = true;
		}
		case 43:
		{
			CreateCosmetic(client, 30065, 6); //Hardy Laurel
		}
		case 44:
		{
			CreateCosmetic(client, 30571, 6); //Brimstone
		}
		case 45:
		{
			CreateCosmetic(client, 30473, 6); //MK 50
		}
	}

	return face;
}

bool SelectClassHat(int client, TFClassType class)
{
	bool face = false;
	int rnd = 0;

	switch (class)
	{
		case TFClass_Scout:
		{
			rnd = GetRandomUInt(0,17);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 111, 6); // Baseball Bill's Sports Shine
				}
				case 2:
				{
					CreateCosmetic(client, 106, 6); // Bonk Helm
				}
				case 3:
				{
					CreateCosmetic(client, 107, 6); // Ye Olde Baker Boy
				}
				case 4:
				{
					CreateCosmetic(client, 150, 6); // Scout Beanie
				}
				case 5:
				{
					CreateCosmetic(client, 174, 6); // Whoopee Cap
				}
				case 6:
				{
					CreateCosmetic(client, 249, 6); // Bombing Run
				}
				case 7:
				{
					CreateCosmetic(client, 219, 6); // Milkman
				}
				case 8:
				{
					CreateCosmetic(client, 324, 6); // Flipped Trilby
				}
				case 9:
				{
					CreateCosmetic(client, 346, 6, 10, 10); // MNC Mascot Hat
				}
				case 10:
				{
					CreateCosmetic(client, 453, 6); // Hero's Tail
				}
				case 11:
				{
					CreateCosmetic(client, 539, 6, 10, 10); // El Jefe
				}
				case 12:
				{
					CreateCosmetic(client, 617, 6, 10, 10); // Backwards Ballcap
				}
				case 13:
				{
					CreateCosmetic(client, 633, 6, 10, 10); // Hermes
				}
				case 14:
				{
					CreateCosmetic(client, 652, 6); // Big Elfin Deal
				}
				case 15:
				{
					CreateCosmetic(client, 760, 6); // Front Runner
				}
				case 16:
				{
					CreateCosmetic(client, 765, 6); // Cross-Comm Express
				}
				case 17:
				{
					CreateCosmetic(client, 780, 6); // Fed-Fightin' Fedora
				}
			}
		}
		case TFClass_Sniper:
		{
			rnd = GetRandomUInt(0,18);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 110, 6); // Master's Yellow Belt
				}
				case 2:
				{
					CreateCosmetic(client, 109, 6); // Professional's Panama
				}
				case 3:
				{
					CreateCosmetic(client, 117, 6); // Ritzy Rick's Hair Fixative
				}
				case 4:
				{
					CreateCosmetic(client, 158, 6); // Sniper Pith Helmet
				}
				case 5:
				{
					CreateCosmetic(client, 181, 6); // Sniper Fishing Hat
				}
				case 6:
				{
					CreateCosmetic(client, 229, 6); // Ol' Snaggletooth
				}
				case 7:
				{
					CreateCosmetic(client, 314, 6); // Larrikin Robin
				}
				case 8:
				{
					CreateCosmetic(client, 344, 6); // Crocleather Slouch
				}
				case 9:
				{
					CreateCosmetic(client, 400, 6); // Desert Marauder
				}
				case 10:
				{
					CreateCosmetic(client, 518, 6, 10, 10); // Anger
					face = true;
				}
				case 11:
				{
					CreateCosmetic(client, 631, 6, 10, 10); // Hat With No Name
				}
				case 12:
				{
					CreateCosmetic(client, 626, 6, 10, 10); // Swagman's Swatter
				}
				case 13:
				{
					CreateCosmetic(client, 600, 6, 10, 10); // Your Worst Nightmare
				}
				case 14:
				{
					CreateCosmetic(client, 720, 6); // Bushman's Boonie
				}
				case 15:
				{
					CreateCosmetic(client, 759, 6); // Fruit Shoot
				}
				case 16:
				{
					CreateCosmetic(client, 783, 6); // HazMat Headcase
					face = true;
				}
				case 17:
				{
					CreateCosmetic(client, 779, 6); // Liquidator's Lid
				}
				case 18:
				{
					CreateCosmetic(client, 819, 6); // Lone Star
				}
			}
		}
		case TFClass_Soldier:
		{
			rnd = GetRandomUInt(0,24);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 98, 6); // Stainless Pot
				}
				case 2:
				{
					CreateCosmetic(client, 99, 6); // Tyrant's Helm
				}
				case 3:
				{
					CreateCosmetic(client, 152, 6); // Soldier Samurai Hat
				}
				case 4:
				{
					CreateCosmetic(client, 183, 6); // Soldier Drill Hat
				}
				case 5:
				{
					CreateCosmetic(client, 250, 6); // Chieftain's Challenge
				}
				case 6:
				{
					CreateCosmetic(client, 227, 6); // Grenadier's Softcap
				}
				case 7:
				{
					CreateCosmetic(client, 251, 6); // Stout Shako
				}
				case 8:
				{
					CreateCosmetic(client, 340, 6); // Defiant Spartan
					face = true;
				}
				case 9:
				{
					CreateCosmetic(client, 339, 6); // Exquisite Rack
				}
				case 10:
				{
					CreateCosmetic(client, 391, 6); // Honcho's Headgear
					face = true;
				}
				case 11:
				{
					CreateCosmetic(client, 434, 6); // Bucket Hat
					face = true;
				}
				case 12:
				{
					CreateCosmetic(client, 395, 6); // Furious Fukaamigasa
				}
				case 13:
				{
					CreateCosmetic(client, 378, 6); // Team Captain
				}
				case 14:
				{
					CreateCosmetic(client, 445, 6); // Armored Authority
				}
				case 15:
				{
					CreateCosmetic(client, 417, 6); // Jumper's Jeepcap
				}
				case 16:
				{
					CreateCosmetic(client, 439, 6); // Lord Cockswain's Pith Helmet
				}
				case 17:
				{
					CreateCosmetic(client, 516, 6, 10, 10); // Stahlhelm
				}
				case 18:
				{
					CreateCosmetic(client, 631, 6, 10, 10); // Hat With No Name
				}
				case 19:
				{
					CreateCosmetic(client, 575, 6, 13, 13); // Infernal Impaler
				}
				case 20:
				{
					CreateCosmetic(client, 701, 6); // Lucky Shot
				}
				case 21:
				{
					CreateCosmetic(client, 719, 6); // Battle Bob
				}
				case 22:
				{
					CreateCosmetic(client, 721, 6); // Conquistador
				}
				case 23:
				{
					CreateCosmetic(client, 764, 6); // Cross-Comm Crash Helmet
				}
				case 24:
				{
					CreateCosmetic(client, 732, 6); // Helmet Without a Home
				}
			}
		}
		case TFClass_DemoMan:
		{
			rnd = GetRandomUInt(0,20);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 100, 6); // Glengarry Bonnet
				}
				case 2:
				{
					CreateCosmetic(client, 120, 6); // Scotsman's Stove Pipe
				}
				case 3:
				{
					CreateCosmetic(client, 146, 6); // Demoman Hallmark
				}
				case 4:
				{
					CreateCosmetic(client, 179, 6); // Demoman Tricorne
				}
				case 5:
				{
					CreateCosmetic(client, 259, 6); // Carouser's Capotain
				}
				case 6:
				{
					CreateCosmetic(client, 216, 6); // Rimmed Raincatcher
				}
				case 7:
				{
					CreateCosmetic(client, 255, 6); // Sober Stuntman
				}
				case 8:
				{
					CreateCosmetic(client, 342, 6); // Prince Tavish's Crown
				}
				case 9:
				{
					CreateCosmetic(client, 306, 6); // Scotch Bonnet
				}
				case 10:
				{
					CreateCosmetic(client, 359, 6); // Demo Kabuto
				}
				case 11:
				{
					CreateCosmetic(client, 388, 6); // Private Eye
				}
				case 12:
				{
					CreateCosmetic(client, 390, 6); // Reggaelator
				}
				case 13:
				{
					CreateCosmetic(client, 465, 6); // Conjurer's Cowl
				}
				case 14:
				{
					CreateCosmetic(client, 403, 6); // Sultan's Ceremonial
				}
				case 15:
				{
					CreateCosmetic(client, 480, 6); // Tam O' Shanter
				}
				case 16:
				{
					CreateCosmetic(client, 514, 6, 10, 10); // Mask of the Shaman
					face = true;
				}
				case 17:
				{
					CreateCosmetic(client, 607, 6, 10, 10); // Buccaneer's Bicorne
				}
				case 18:
				{
					CreateCosmetic(client, 631, 6, 10, 10); // Hat With No Name
				}
				case 19:
				{
					CreateCosmetic(client, 604, 6, 10, 10); // Tavish DeGroot Experience
				}
				case 20:
				{
					CreateCosmetic(client, 703, 6); // Bolgan
					face = true;
				}
			}
		}
		case TFClass_Medic:
		{
			rnd = GetRandomUInt(0,15);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 104, 6); // Otolaryngologist's Mirror
				}
				case 2:
				{
					CreateCosmetic(client, 101, 6); // Vintage Tyrolean
				}
				case 3:
				{
					CreateCosmetic(client, 184, 6); // Medic Gatsby
				}
				case 4:
				{
					CreateCosmetic(client, 303, 6); // Berliner's Bucket Helm
					face = true;
				}
				case 5:
				{
					CreateCosmetic(client, 177, 6); // Medic Goggles
				}
				case 6:
				{
					CreateCosmetic(client, 323, 6); // German Gonzila
				}
				case 7:
				{
					CreateCosmetic(client, 363, 6); // Medic Geisha Hair
				}
				case 8:
				{
					CreateCosmetic(client, 383, 6); // Grimm Hatte
				}
				case 9:
				{
					CreateCosmetic(client, 381, 6); // Medic's Mountain Cap
				}
				case 10:
				{
					CreateCosmetic(client, 388, 6); // Private Eye
				}
				case 11:
				{
					CreateCosmetic(client, 398, 6); // Doctor's Sack
				}
				case 12:
				{
					CreateCosmetic(client, 378, 6); // Team Captain
				}
				case 13:
				{
					CreateCosmetic(client, 467, 6); // Planeswalker Helm
				}
				case 14:
				{
					CreateCosmetic(client, 616, 6, 10, 10); // Surgeon's Stahlhelm
				}
				case 15:
				{
					CreateCosmetic(client, 778, 6); // Gentleman's Ushanka
				}
			}
		}
		case TFClass_Heavy:
		{
			rnd = GetRandomUInt(0,23);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 96, 6); // Officer's Ushanka
				}
				case 2:
				{
					CreateCosmetic(client, 97, 6); // Tough Guy's Toque
				}
				case 3:
				{
					CreateCosmetic(client, 145, 6); // Heavy Hair
					face = true;
				}
				case 4:
				{
					CreateCosmetic(client, 185, 6); // Heavy Do-rag
				}
				case 5:
				{
					CreateCosmetic(client, 254, 6); // Hard Counter
				}
				case 6:
				{
					CreateCosmetic(client, 246, 6); // Pugilist's Protector
				}
				case 7:
				{
					CreateCosmetic(client, 290, 6, 31, 31); // Cadaver's Cranium
				}
				case 8:
				{
					CreateCosmetic(client, 309, 6); // Big Chief
				}
				case 9:
				{
					CreateCosmetic(client, 330, 6); // Coupe D'isaster
				}
				case 10:
				{
					CreateCosmetic(client, 313, 6); // Magnificent Mongolian
				}
				case 11:
				{
					CreateCosmetic(client, 358, 6); // Heavy Topknot
				}
				case 12:
				{
					CreateCosmetic(client, 380, 6); // Large Luchadore
					face = true;
				}
				case 13:
				{
					CreateCosmetic(client, 378, 6); // Team Captain
				}
				case 14:
				{
					CreateCosmetic(client, 427, 6); // Capone's Capper
				}
				case 15:
				{
					CreateCosmetic(client, 485, 6); // Big Steel Jaw of Summer Fun
				}
				case 16:
				{
					CreateCosmetic(client, 478, 6); // Copper's Hard Top
				}
				case 17:
				{
					CreateCosmetic(client, 515, 6, 10, 10); // Pilotka
				}
				case 18:
				{
					CreateCosmetic(client, 517, 6, 10, 10); // Dragonborn Helmet
					face = true;
				}
				case 19:
				{
					CreateCosmetic(client, 613, 6, 10, 10); // Gym Rat
				}
				case 20:
				{
					CreateCosmetic(client, 601, 6, 10, 10); // One-Man Army
				}
				case 21:
				{
					CreateCosmetic(client, 603, 6, 10, 10); // Outdoorsman
				}
				case 22:
				{
					CreateCosmetic(client, 585, 6, 10, 10); // Cold War Luchador
					face = true;
				}
				case 23:
				{
					CreateCosmetic(client, 635, 6, 10, 10); // War Head
				}
			}
		}
		case TFClass_Pyro:
		{
			rnd = GetRandomUInt(0,23);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 105, 6); // Brigade Helm
				}
				case 2:
				{
					CreateCosmetic(client, 102, 6); // Respectless Rubber Glove
				}
				case 3:
				{
					CreateCosmetic(client, 151, 6); // Pyro Brain Sucker
				}
				case 4:
				{
					CreateCosmetic(client, 182, 6); // Pyro Helm
				}
				case 5:
				{
					CreateCosmetic(client, 213, 6); // Attendant
				}
				case 6:
				{
					CreateCosmetic(client, 253, 6); // Handyman's Handle
				}
				case 7:
				{
					CreateCosmetic(client, 248, 6); // Napper's Respite
				}
				case 8:
				{
					CreateCosmetic(client, 247, 6); // Old Guadalajara
				}
				case 9:
				{
					CreateCosmetic(client, 321, 6); // Madame Dixie
				}
				case 10:
				{
					CreateCosmetic(client, 318, 6); // Prancer's Pride
				}
				case 11:
				{
					CreateCosmetic(client, 435, 6); // Traffic Cone
				}
				case 12:
				{
					CreateCosmetic(client, 394, 6); // Connoisseur's Cap
				}
				case 13:
				{
					CreateCosmetic(client, 377, 6); // Hottie's Hoodie
				}
				case 14:
				{
					CreateCosmetic(client, 481, 6); // Stately Steel Toe
				}
				case 15:
				{
					CreateCosmetic(client, 615, 6, 10, 10); // Birdcage
				}
				case 16:
				{
					CreateCosmetic(client, 627, 6, 10, 10); // Flamboyant Flamenco
				}
				case 17:
				{
					CreateCosmetic(client, 934, 6, 20, 20); // Little Buddy
				}
				case 18:
				{
					CreateCosmetic(client, 597, 6); // Bubble Pipe
				}
				case 19:
				{
					CreateCosmetic(client, 644, 6); // Head Warmer
				}
				case 20:
				{
					CreateCosmetic(client, 571, 6, 13, 13); // Apparition's Aspect
					face = true;
				}
				case 21:
				{
					CreateCosmetic(client, 570, 6, 13, 13); // Last Breath
					face = true;
				}
				case 22:
				{
					CreateCosmetic(client, 753, 6); // Waxy Wayfinder
				}
				case 23:
				{
					CreateCosmetic(client, 783, 6); // HazMat Headcase
					face = true;
				}
			}
		}
		case TFClass_Spy:
		{
			rnd = GetRandomUInt(0,13);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 108, 6); // Backbiter's Billycock
				}
				case 2:
				{
					CreateCosmetic(client, 147, 6); // Spy Noble Hair
				}
				case 3:
				{
					CreateCosmetic(client, 180, 6); // Spy Beret
				}
				case 4:
				{
					CreateCosmetic(client, 223, 6); // Familiar Fez
					face = true;
				}
				case 5:
				{
					CreateCosmetic(client, 319, 6); // Détective Noir
				}
				case 6:
				{
					CreateCosmetic(client, 397, 6); // Charmer's Chapeau
				}
				case 7:
				{
					CreateCosmetic(client, 388, 6); // Private Eye
				}
				case 8:
				{
					CreateCosmetic(client, 437, 6); // Janissary Hat
				}
				case 9:
				{
					CreateCosmetic(client, 459, 6); // Cosa Nostra Cap
				}
				case 10:
				{
					CreateCosmetic(client, 521, 6, 10, 10); // Belltower Spec Ops
				}
				case 11:
				{
					CreateCosmetic(client, 602, 6, 10, 10); // Counterfeit Billycock
				}
				case 12:
				{
					CreateCosmetic(client, 622, 6, 10, 10); // L'Inspecteur
				}
				case 13:
				{
					CreateCosmetic(client, 637, 6, 10, 10); // Dashin' Hashshashin
				}
			}
		}
		case TFClass_Engineer:
		{
			rnd = GetRandomUInt(0,16);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 95, 6); // Engineer's Cap
				}
				case 2:
				{
					CreateCosmetic(client, 118, 6); // Texas Slim's Dome Shine
				}
				case 3:
				{
					CreateCosmetic(client, 94, 6); // Texas Ten Gallon
				}
				case 4:
				{
					CreateCosmetic(client, 148, 6); // Engineer Welding Mask
				}
				case 5:
				{
					CreateCosmetic(client, 178, 6); // Engineer Earmuffs
				}
				case 6:
				{
					CreateCosmetic(client, 322, 6); // Buckaroo's Hat
				}
				case 7:
				{
					CreateCosmetic(client, 338, 6); // Industrial Festivizer
				}
				case 8:
				{
					CreateCosmetic(client, 382, 6); // Big Country
				}
				case 9:
				{
					CreateCosmetic(client, 384, 6); // Professor's Peculiarity
					face = true;
				}
				case 10:
				{
					CreateCosmetic(client, 436, 6); // Polish War Babushka
				}
				case 11:
				{
					CreateCosmetic(client, 399, 6); // Ol' Geezer
				}
				case 12:
				{
					CreateCosmetic(client, 379, 6); // Western Wear
				}
				case 13:
				{
					CreateCosmetic(client, 631, 6, 10, 10); // Hat With No Name
				}
				case 14:
				{
					CreateCosmetic(client, 605, 6, 10, 10); // Pencil Pusher
				}
				case 15:
				{
					CreateCosmetic(client, 628, 6, 10, 10); // Virtual Reality Headset
				}
				case 16:
				{
					CreateCosmetic(client, 590); // Brainiac Hairpiece
				}
			}
		}
	}

	return face;
}

void SelectAllClassFacialCosmetic(int client)
{
	int rnd = GetRandomUInt(0,10);

	switch (rnd)
	{
		case 1:
		{
			CreateCosmetic(client, 30569, 6); //The Tomb Readers
		}
		case 2:
		{
			CreateCosmetic(client, 744, 6); //Pyrovision Goggles
		}
		case 3:
		{
			CreateCosmetic(client, 522, 6); //The Deus Specs
		}
		case 4:
		{
			CreateCosmetic(client, 816, 6); //The Marxman
		}
		case 5:
		{
			CreateCosmetic(client, 30104, 6); //Graybanns
		}
		case 6:
		{
			CreateCosmetic(client, 30306, 6); //The Dictator
		}
		case 7:
		{
			CreateCosmetic(client, 30352, 6); //The Mustachioed Mann
		}
		case 8:
		{
			CreateCosmetic(client, 30414, 6); //The Eye-Catcher
		}
		case 9:
		{
			CreateCosmetic(client, 30140, 6); //The Virtual Viewfinder
		}
		case 10:
		{
			CreateCosmetic(client, 30397, 6); //The Bruiser's Bandanna
		}
	}
}

void SelectClassFacialCosmetic(int client, TFClassType class)
{
	int rnd = 0;

	switch (class)
	{
		case TFClass_Scout:
		{
			rnd = GetRandomUInt(0,3);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 460, 6); // Scout MtG Hat
				}
				case 2:
				{
					CreateCosmetic(client, 451, 6); // Bonk Boy
				}
				case 3:
				{
					CreateCosmetic(client, 630, 6); // Stereoscopic Shades
				}
			}
		}
		case TFClass_Sniper:
		{
			rnd = GetRandomUInt(0,3);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 393, 6); // Villain's Veil
				}
				case 2:
				{
					CreateCosmetic(client, 647, 6, 15, 15); // All-Father
				}
				case 3:
				{
					CreateCosmetic(client, 766, 6); // Doublecross-Comm
				}
			}
		}
		case TFClass_Soldier:
		{
			rnd = GetRandomUInt(0,3);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 440, 6); // Lord Cockswain's Novelty Mutton Chops and Pipe
				}
				case 2:
				{
					CreateCosmetic(client, 360, 6); // Hero's Hachimaki
				}
				case 3:
				{
					CreateCosmetic(client, 647, 6, 15, 15); // All-Father
				}
			}
		}
		case TFClass_DemoMan:
		{
			rnd = GetRandomUInt(0,2);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 647, 6, 15, 15); // All-Father
				}
				case 2:
				{
					CreateCosmetic(client, 709, 6); // Snapped Pupil
				}
			}
		}
		case TFClass_Medic:
		{
			rnd = GetRandomUInt(0,4);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 315, 6); // Blighted Beak
				}
				case 2:
				{
					CreateCosmetic(client, 144, 6); // Medic Mask
				}
				case 3:
				{
					CreateCosmetic(client, 647, 6, 15, 15); // All-Father
				}
				case 4:
				{
					CreateCosmetic(client, 657, 6); // Nine-Pipe Problem
				}
			}
		}
		case TFClass_Heavy:
		{
			rnd = GetRandomUInt(0,2);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 479, 6); // Security Shades
				}
				case 2:
				{
					CreateCosmetic(client, 647, 6, 15, 15); // All-Father
				}
			}
		}
		case TFClass_Pyro:
		{
			rnd = GetRandomUInt(0,3);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 316, 6); // Pyromancer's Mask
				}
				case 2:
				{
					CreateCosmetic(client, 175, 6); // Pyro Monocle
				}
				case 3:
				{
					CreateCosmetic(client, 387, 6); // Sight for Sore Eyes
				}
			}
		}
		case TFClass_Spy:
		{
			rnd = GetRandomUInt(0,6);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 103, 6); // Camera Beard
				}
				case 2:
				{
					CreateCosmetic(client, 462, 6); // Made Man
				}
				case 3:
				{
					CreateCosmetic(client, 629, 6); // Spectre's Spectacles
				}
				case 4:
				{
					CreateCosmetic(client, 337, 6); // Le Party Phantom
				}
				case 5:
				{
					CreateCosmetic(client, 361, 6); // Spy Oni Mask
				}
				case 6:
				{
					CreateCosmetic(client, 766, 6); // Doublecross-Comm
				}
			}
		}
		case TFClass_Engineer:
		{
			rnd = GetRandomUInt(0,3);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 389, 6); // Googly Gazer
				}
				case 2:
				{
					CreateCosmetic(client, 647, 6, 15, 15); // All-Father
				}
				case 3:
				{
					CreateCosmetic(client, 591, 6, 20, 20); // Brainiac Goggles
				}
			}
		}
	}
}

void SelectAllClassTorsoCosmetic(int client)
{
	int rnd = GetRandomUInt(0,21);

	switch (rnd)
	{
		case 1:
		{
			CreateCosmetic(client, 868, 6, 20); //Heroic Companion Badge
		}
		case 2:
		{
			CreateCosmetic(client, 583, 6, 20); //Bombinomicon
		}
		case 3:
		{
			CreateCosmetic(client, 586, 6); //Mark of the Saint
		}
		case 4:
		{
			CreateCosmetic(client, 625, 6, 20); //Clan Pride
		}
		case 5:
		{
			CreateCosmetic(client, 619, 6, 20); //Flair!
		}
		case 6:
		{
			CreateCosmetic(client, 1096, 6); //The Baronial Badge
		}
		case 7:
		{
			CreateCosmetic(client, 623, 6, 20); //Photo Badge
		}
		case 8:
		{
			CreateCosmetic(client, 738, 6); //Pet Balloonicorn
		}
		case 9:
		{
			CreateCosmetic(client, 955, 6); //The Tuxxy
		}
		case 10:
		{
			CreateCosmetic(client, 995, 6, 20); //Pet Reindoonicorn
		}
		case 11:
		{
			CreateCosmetic(client, 987, 6); //The Merc's Muffler
		}
		case 12:
		{
			CreateCosmetic(client, 855, 6); //Vigilant Pin
		}
		case 13:
		{
			CreateCosmetic(client, 818, 6); //Awesomenauts Badge
		}
		case 14:
		{
			CreateCosmetic(client, 767, 6); //Atomic Accolade
		}
		case 15:
		{
			CreateCosmetic(client, 718, 6); //Merc Medal
		}
		case 16:
		{
			CreateCosmetic(client, 30309, 6); //Dead of Night
		}
		case 17:
		{
			CreateCosmetic(client, 1024, 6); //Crofts Crest
		}
		case 18:
		{
			CreateCosmetic(client, 992, 6); //Smissmas Wreath
		}
		case 19:
		{
			CreateCosmetic(client, 956, 6); //Faerie Solitaire Pin
		}
		case 20:
		{
			CreateCosmetic(client, 943, 6); //Hitt Mann Badge
		}
		case 21:
		{
			CreateCosmetic(client, 873, 6, 20); //Whale Bone Charm
		}
	}
}

void SelectClassTorsoCosmetic(int client, TFClassType class)
{
	int rnd = 0;

	switch (class)
	{
		case TFClass_Scout:
		{
			rnd = GetRandomUInt(0,6);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 454, 6, 20, 20); // Sign of the Wolf's School
				}
				case 2:
				{
					CreateCosmetic(client, 707, 6); // Boston Boom-Bringer
				}
				case 3:
				{
					CreateCosmetic(client, 722, 6); // Fast Learner
				}
				case 4:
				{
					CreateCosmetic(client, 781, 6); // Dillinger's Duffel
				}
				case 5:
				{
					CreateCosmetic(client, 815, 6); // Champ Stamp
				}
				case 6:
				{
					CreateCosmetic(client, 814, 6); // Triad Trinket
				}
			}
		}
		case TFClass_Sniper:
		{
			rnd = GetRandomUInt(0,4);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 618, 6, 20, 20); // The Crocodile Smile
				}
				case 2:
				{
					CreateCosmetic(client, 645, 6, 15, 15); // Outback Intellectual
				}
				case 3:
				{
					CreateCosmetic(client, 815, 6); // Champ Stamp
				}
				case 4:
				{
					CreateCosmetic(client, 814, 6); // Triad Trinket
				}
			}
		}
		case TFClass_Soldier:
		{
			rnd = GetRandomUInt(0,5);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 446, 6); // Fancy Dress Uniform
				}
				case 2:
				{
					CreateCosmetic(client, 650, 6); // Kringle Collection
				}
				case 3:
				{
					CreateCosmetic(client, 641, 6, 20, 20); // Ornament Armament
				}
				case 4:
				{
					CreateCosmetic(client, 768, 6); // Professor's Pineapple
				}
				case 5:
				{
					CreateCosmetic(client, 731, 6); // Captain's Cocktails
				}
			}
		}
		case TFClass_DemoMan:
		{
			rnd = GetRandomUInt(0,5);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 610, 6, 20, 20); // A Whiff of the Old Brimstone
				}
				case 2:
				{
					CreateCosmetic(client, 641, 6, 20, 20); // Ornament Armament
				}
				case 3:
				{
					CreateCosmetic(client, 768, 6); // Professor's Pineapple
				}
				case 4:
				{
					CreateCosmetic(client, 771, 6); // Liquor Locker
				}
				case 5:
				{
					CreateCosmetic(client, 776, 6); // Bird-Man of Aberdeen
				}
			}
		}
		case TFClass_Medic:
		{
			rnd = GetRandomUInt(0,5);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 620, 6, 20, 20); // Couvre Corner
				}
				case 2:
				{
					CreateCosmetic(client, 621, 6, 20, 20); // Surgeon's Stethoscope
				}
				case 3:
				{
					CreateCosmetic(client, 639, 6, 15, 15); // Dr. Whoa
				}
				case 4:
				{
					CreateCosmetic(client, 754, 6); // Scrap Pack
				}
				case 5:
				{
					CreateCosmetic(client, 769, 6); // Quadwrangler
				}
			}
		}
		case TFClass_Heavy:
		{
			rnd = GetRandomUInt(0,5);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 524, 6, 10, 10); // The Purity Fist
				}
				case 2:
				{
					CreateCosmetic(client, 757, 6); // Toss-Proof Towel
				}
				case 3:
				{
					CreateCosmetic(client, 777, 6); // Apparatchik's Apparel
				}
				case 4:
				{
					CreateCosmetic(client, 815, 6); // Champ Stamp
				}
				case 5:
				{
					CreateCosmetic(client, 814, 6); // Triad Trinket
				}
			}
		}
		case TFClass_Pyro:
		{
			rnd = GetRandomUInt(0,9);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 632, 6, 15, 15); // Cremator's Conscience
				}
				case 2:
				{
					CreateCosmetic(client, 641, 6, 20, 20); // Ornament Armament
				}
				case 3:
				{
					CreateCosmetic(client, 651, 6); // Jingle Belt
				}
				case 4:
				{
					CreateCosmetic(client, 596, 6, 15, 15); // Moonman Backpack
				}
				case 5:
				{
					CreateCosmetic(client, 754, 6); // Scrap Pack
				}
				case 6:
				{
					CreateCosmetic(client, 768, 6); // Professor's Pineapple
				}
				case 7:
				{
					CreateCosmetic(client, 746, 6); // Burning Bongos
				}
				case 8:
				{
					CreateCosmetic(client, 745, 6); // Infernal Orchestrina
				}
				case 9:
				{
					CreateCosmetic(client, 820, 6); // Russian Rocketeer
				}
			}
		}
		case TFClass_Spy:
		{
			rnd = GetRandomUInt(0,4);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 483, 6, 15, 15); // Rogue's Col Roule
				}
				case 2:
				{
					CreateCosmetic(client, 639, 6, 15, 15); // Dr. Whoa
				}
				case 3:
				{
					CreateCosmetic(client, 782, 6); // Business Casual
				}
				case 4:
				{
					CreateCosmetic(client, 814, 6); // Triad Trinket
				}
			}
		}
		case TFClass_Engineer:
		{
			rnd = GetRandomUInt(0,4);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 519, 6, 10, 10); // Pip-Boy
				}
				case 2:
				{
					CreateCosmetic(client, 784, 6); // Idea Tube
				}
				case 3:
				{
					CreateCosmetic(client, 815, 6); // Champ Stamp
				}
				case 4:
				{
					CreateCosmetic(client, 814, 6); // Triad Trinket
				}
			}
		}
	}
}

void SelectAllClassLegsCosmetic(int client)
{
	int rnd = GetRandomUInt(0,4);

	switch (rnd)
	{
		case 1:
		{
			CreateCosmetic(client, 1025, 6); //The Fortune Hunter
		}
		case 2:
		{
			CreateCosmetic(client, 30607, 6); //The Pocket Raiders
		}
		case 3:
		{
			CreateCosmetic(client, 30068, 6); //The Breakneck Baggies
		}
		case 4:
		{
			CreateCosmetic(client, 869, 6); //The Rump-o-Lantern
		}
	}
}

void SelectClassLegsCosmetic(int client, TFClassType class)
{
	int rnd = 0;

	switch (class)
	{
		case TFClass_Scout:
		{
			rnd = GetRandomUInt(0,2);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 653, 6, 10, 10); // Bootie Time
				}
				case 2:
				{
					CreateCosmetic(client, 734, 6, 10, 10); // Teufort Tooth Kicker
				}
			}
		}
		case TFClass_Sniper:
		{
			rnd = GetRandomUInt(0,2);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 646, 6, 15, 15); // Itsy Bitsy Spyer
				}
				case 2:
				{
					CreateCosmetic(client, 734, 6, 10, 10); // Teufort Tooth Kicker
				}
			}
		}
		case TFClass_Soldier:
		{
			rnd = GetRandomUInt(0,2);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 392, 6, 15, 15); // Pocket Medic
				}
				case 2:
				{
					CreateCosmetic(client, 734, 6, 10, 10); // Teufort Tooth Kicker
				}
			}
		}
		case TFClass_DemoMan:
		{
			rnd = GetRandomUInt(0,2);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 708, 6); // Aladdin's Private Reserve
				}
				case 2:
				{
					CreateCosmetic(client, 734, 6, 10, 10); // Teufort Tooth Kicker
				}
			}
		}
		case TFClass_Medic:
		{
			rnd = GetRandomUInt(0,1);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 770, 6); // Surgeon's Side Satchel
				}
			}
		}
		case TFClass_Heavy:
		{
			rnd = GetRandomUInt(0,2);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 392, 6, 15, 15); // Pocket Medic
				}
				case 2:
				{
					CreateCosmetic(client, 643, 6, 15, 15); // Sandvich Safe
				}
			}
		}
		case TFClass_Pyro:
		{
			// nothing for now
		}
		case TFClass_Spy:
		{
			rnd = GetRandomUInt(0,1);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 763, 6); // Sneaky Spats of Sneaking
				}
			}
		}
		case TFClass_Engineer:
		{
			rnd = GetRandomUInt(0,8);

			switch (rnd)
			{
				case 1:
				{
					CreateCosmetic(client, 520, 6, 10, 10); // Wingstick
				}
				case 2:
				{
					CreateCosmetic(client, 755, 6); // Texas Half-Pants
				}
				case 3:
				{
					CreateCosmetic(client, 606, 6, 15, 15); // Builder's Blueprints
				}
				case 4:
				{
					CreateCosmetic(client, 484, 6, 15, 15); // Prairie Heel Biters
				}
				case 5:
				{
					CreateCosmetic(client, 386, 6); // Teddy Roosebelt
				}
				case 6:
				{
					CreateCosmetic(client, 646, 6, 15, 15); // Itsy Bitsy Spyer
				}
				case 7:
				{
					CreateCosmetic(client, 670, 6); // Stocking Stuffer
				}
				case 8:
				{
					CreateCosmetic(client, 734, 6, 10, 10); // Teufort Tooth Kicker
				}
			}
		}
	}
}

bool CreateCosmetic(int client, int itemindex, int quality = 6, int minlevel = 0, int maxlevel = 0)
{
	int hat = CreateEntityByName("tf_wearable");

	if (!IsValidEntity(hat))
	{
		LogError("Failed to create a valid entity with class name [tf_wearable]! Skipping.");
		return false;
	}

	char entclass[64];
	GetEntityNetClass(hat, entclass, sizeof(entclass));
	SetEntData(hat, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), itemindex);
	SetEntData(hat, FindSendPropInfo(entclass, "m_iEntityQuality"), quality);

	if (minlevel && maxlevel)
	{
		SetEntData(hat, FindSendPropInfo(entclass, "m_iEntityLevel"), GetRandomUInt(minlevel,maxlevel));
	}
	else
	{
		SetEntData(hat, FindSendPropInfo(entclass, "m_iEntityLevel"), GetRandomUInt(1,100));
	}

	SetEntData(hat, FindSendPropInfo(entclass, "m_bInitialized"), 1);

	if (!DispatchSpawn(hat))
	{
		LogError("The created cosmetic entity [Class name: tf_wearable, Item index: %i, Index: %i], failed to spawn! Skipping.", itemindex, hat);
		AcceptEntityInput(hat, "Kill");
		return false;
	}

	SDKCall(g_hWearableEquip, client, hat);
	return true;
}

bool IsPlayerHere(int client)
{
	return (client && IsClientInGame(client) && IsFakeClient(client) && !IsClientReplay(client) && !IsClientSourceTV(client));
}

int GetRandomUInt(int min, int max)
{
	return RoundToFloor(GetURandomFloat() * (max - min + 1)) + min;
}