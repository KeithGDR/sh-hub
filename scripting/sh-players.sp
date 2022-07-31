#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define NOT_ASSIGNED -1

bool g_Late;
Database g_Database;

enum struct Player {
	int client;
	int id;

	int accountid;
	char steam2[64];
	char steam3[64];
	char steam64[64];

	void Init(int client) {
		this.client = client;
	}

	void SyncViaSteam() {
		this.accountid = GetSteamAccountID(this.client);
		GetClientAuthId(this.client, AuthId_Steam2, this.steam2, sizeof(Player::steam2));
		GetClientAuthId(this.client, AuthId_Steam3, this.steam3, sizeof(Player::steam3));
		GetClientAuthId(this.client, AuthId_SteamID64, this.steam64, sizeof(Player::steam64));
	}

	void Clear() {
		this.client = 0;
		this.id = NOT_ASSIGNED;
		this.accountid = 0;
		this.steam2[0] = '\0';
		this.steam3[0] = '\0';
		this.steam64[0] = '\0';
	}
}

Player g_Player[MAXPLAYERS + 1];

GlobalForward g_Forward_OnPlayerSynced;

public Plugin myinfo = {
	name = "[SH] Players", 
	author = "Drixevel", 
	description = "Tracks players data and assigns them ids for usage in other plugins.", 
	version = "1.0.0", 
	url = "https://scoutshideaway.tf/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("sh-players");

	CreateNative("SH_GetPlayerID", Native_GetID);

	g_Forward_OnPlayerSynced = new GlobalForward("SH_OnPlayerSynced", ET_Ignore, Param_Cell, Param_Cell);

	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	Database.Connect(OnSQLConnect, "scoutshideaway");

	if (g_Late) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientConnected(i)) {
				OnClientConnected(i);
			}
		}
	}
}

public void OnSQLConnect(Database db, const char[] error, any data) {
	if (db == null) {
		g_Late = false;
		ThrowError("Error while connecting to database: %s", error);
	}
	
	g_Database = db;
	LogMessage("Connected to database successfully.");

	if (g_Late) {
		g_Late = false;

		char auth[64];
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientAuthorized(i) && GetClientAuthId(i, AuthId_Engine, auth, sizeof(auth))) {
				OnClientAuthorized(i, auth);
			}
		}
	}
}

public void OnClientConnected(int client) {
	g_Player[client].Init(client);
}

public void OnClientAuthorized(int client, const char[] auth) {
	if (IsFakeClient(client)) {
		return;
	}

	g_Player[client].SyncViaSteam();

	if (g_Database == null) {
		return;
	}

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id FROM `sh-players` WHERE accountid = '%i';", g_Player[client].accountid);
	g_Database.Query(OnParsePlayer, sQuery, GetClientUserId(client));
}

public void OnClientDisconnect_Post(int client) {
	g_Player[client].Clear();
}

public void OnParsePlayer(Database db, DBResultSet results, const char[] error, any userid) {
	int client;
	if ((client = GetClientOfUserId(userid)) == 0) {
		return;
	}

	if (results == null) {
		ThrowError("Error while parsing player: %s", error);
	}

	if (results.FetchRow()) {
		g_Player[client].id = results.FetchInt(0);
		CallSyncForward(client, g_Player[client].id);
	} else {
		char sQuery[256];
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `sh-players` (accountid, steam2, steam3, steam64) VALUES ('%i', '%s', '%s', '%s');", g_Player[client].accountid, g_Player[client].steam2, g_Player[client].steam3, g_Player[client].steam64);
		g_Database.Query(OnInsertPlayer, sQuery, userid);
	}
}

public void OnInsertPlayer(Database db, DBResultSet results, const char[] error, any userid) {
	int client;
	if ((client = GetClientOfUserId(userid)) == 0) {
		return;
	}

	if (results == null) {
		ThrowError("Error while inserting new player: %s", error);
	}

	g_Player[client].id = results.InsertId;
	CallSyncForward(client, g_Player[client].id);
}

public int Native_GetID(Handle plugin, int numParams) {
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients || IsFakeClient(client)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Client index '%i' is invalid or is a bot.", client);
	}

	return g_Player[client].id;
}

void CallSyncForward(int client, int id) {
	Call_StartForward(g_Forward_OnPlayerSynced);
	Call_PushCell(client);
	Call_PushCell(id);
	Call_Finish();
}