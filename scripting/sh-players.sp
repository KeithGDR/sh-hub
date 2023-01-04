#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define INVALID_ID -1

Database g_Database;

enum struct Player {
	char steamid[64];

	int id;

	void Clear() {
		this.steamid[0] = '\0';

		this.id = INVALID_ID;
	}
}

Player g_Player[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[SH] Players", 
	author = "Drixevel", 
	description = "Tracks players data and assigns them ids for usage in other plugins.", 
	version = "1.0.0", 
	url = "https://scoutshideaway.tf/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {

	return APLRes_Success;
}

public void OnPluginStart() {
	Database.Connect(OnSQLConnect, "scoutshideaway");
	RegConsoleCmd("sm_id", Command_ID, "Displays your player id.");
}

public void OnSQLConnect(Database db, const char[] error, any data) {
	if (db == null) {
		ThrowError("Failed to connect to database: %s", error);
	}

	g_Database = db;
	LogMessage("Connected to database successfully.");

	char auth[64];
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientAuthorized(i) && GetClientAuthId(i, AuthId_Engine, auth, sizeof(auth))) {
			OnClientAuthorized(i, auth);
		}
	}
}

public void OnClientAuthorized(int client, const char[] auth) {
	strcopy(g_Player[client].steamid, 64, auth);

	if (g_Database == null) {
		return;
	}

	char sQuery[1024];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM `players` WHERE steamid = '%s';", g_Player[client].steamid);
	g_Database.Query(OnParsePlayer, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void OnParsePlayer(Database db, DBResultSet results, const char[] error, any data) {
	int client;
	if ((client = GetClientOfUserId(data)) == 0) {
		return;
	}

	if (results == null) {
		ThrowError("Error while parsing player: %s", error);
	}

	if (results.FetchRow()) {
		g_Player[client].id = results.FetchInt(0);
	} else {
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		int size = 2 * strlen(sName) + 1;
		char[] sSafeName = new char[size];
		g_Database.Escape(sName, sSafeName, size);

		char sQuery[1024];
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `players` (name, steamid) VALUES ('%s', '%s');", sSafeName, g_Player[client].steamid);
		g_Database.Query(OnCreatePlayer, sQuery, GetClientUserId(client), DBPrio_Low);
	}
}

public void OnCreatePlayer(Database db, DBResultSet results, const char[] error, any data) {
	int client;
	if ((client = GetClientOfUserId(data)) == 0) {
		return;
	}

	if (results == null) {
		ThrowError("Error while creating player: %s", error);
	}

	g_Player[client].id = results.InsertId;
}

public void OnClientDisconnect_Post(int client) {
	g_Player[client].Clear();
}

public Action Command_ID(int client, int args) {
	if (client == 0) {
		ReplyToCommand(client, "You must be in-game to use this command.");
		return Plugin_Handled;
	}

	if (g_Player[client].id == INVALID_ID) {
		ReplyToCommand(client, "You do not have an id yet.");
		return Plugin_Handled;
	}

	ReplyToCommand(client, "Your id is %d.", g_Player[client].id);
	return Plugin_Handled;
}