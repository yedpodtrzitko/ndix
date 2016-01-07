#include <sourcemod>

#define PL_VERSION "1.4"

new Handle:cvarEnabled = INVALID_HANDLE;
new Handle:cvarTime = INVALID_HANDLE;
new Handle:g_Startup 	= INVALID_HANDLE;

public const Plugin:myinfo = {
	name = "AutoRestart",
	author = "MikeJS, modified by yed_",
	description = "Restarts servers once a day when they empty.",
	version = PL_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=87291",
}

public OnPluginStart() {
	CreateConVar( "sm_autorestart_version", PL_VERSION, "AutoRestart version.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY );

	cvarEnabled = CreateConVar( "sm_autorestart", "1", "Enable AutoRestart.", FCVAR_PLUGIN );
	cvarTime = CreateConVar( "sm_autorestart_time", "0500", "Time to restart server at.", FCVAR_PLUGIN, true, 0.0, true, 2400.0 );
	g_Startup = CreateConVar("sm_startup", "0", "This checks to see if the plugin is booting up", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);

	CreateTimer( 300.0, CheckRestart, 0, TIMER_REPEAT );
}

public OnConfigsExecuted()
{
 	int IsStartup = GetConVarInt(g_Startup);
 	if(IsStartup == 0){
	 	SetConVarInt(g_Startup, 1, false, true);
		LogToGame("Server triggered \"RESTART\"");
 	}
}

public Action:CheckRestart( Handle:timer, any:ignore ) {
	if( !GetConVarBool( cvarEnabled ) ) {
		return;
	}

	// Is the server empty?
	for( int i = 1; i <= MaxClients; i++ ) {
		if( IsClientConnected( i ) && !IsFakeClient( i ) ) {
			return;
		}
	}

	decl String:path[ PLATFORM_MAX_PATH ];
	BuildPath( Path_SM, path, sizeof( path ), "data/lastrestart.txt" );

	// Did we already restart today?
	decl String:currentDay[ 8 ];
	FormatTime( currentDay, sizeof( currentDay ), "%j" );

	new const lastRestart = GetFileTime( path, FileTime_LastChange );
	char lastRestartDay[ 8 ] = "";

	if( lastRestart != -1 ) {
		FormatTime( lastRestartDay, sizeof( lastRestartDay ), "%j", lastRestart );
	}

	if( StrEqual( currentDay, lastRestartDay ) ) {
		return;
	}

	decl String:time[ 8 ];
	FormatTime( time, sizeof( time ), "%H%M" );

	// Is it too early to restart?
	if( StringToInt( time ) < GetConVarInt( cvarTime ) ) {
		return;
	}

	// Touch autorestart.txt
	new const Handle:file = OpenFile( path, "w" );
	bool written = false;
	int closed;

	if( file != INVALID_HANDLE ) {
		written = WriteFileString( file, "Don't touch this file", true );
		closed = CloseHandle( file );
	}

	// Don't restart endlessly if we couldn't...
	if( file == INVALID_HANDLE || !written || !closed ) {
		LogError( "Couldn't write %s.", path );

		return;
	}

	// All good
	LogMessage( "Restarting..." );
	ServerCommand( "_restart" );
}
