#if defined _sh_players_included
  #endinput
#endif
#define _sh_players_included

native int SH_GetPlayerID(int client);
forward void SH_OnPlayerSynced(int client, int id);

#if !defined REQUIRE_PLUGIN
public void __pl_sh_players_SetNTVOptional()
{
	MarkNativeAsOptional("SH_GetPlayerID");
}
#endif

public SharedPlugin __pl_sh_players =
{
	name = "sh-players",
	file = "sh-players.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};