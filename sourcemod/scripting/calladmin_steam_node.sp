/**
 * -----------------------------------------------------
 * File        calladmin_steam_node.sp
 * Authors     Jasper Abbink
 * License     MIT
 * Web         http://abb.ink
 * -----------------------------------------------------
 */
 
#include <sourcemod>
#include <autoexecconfig>
#include "calladmin"
#include <socket>
#include <regex>
#pragma semicolon 1

//#define STEAMTOOLS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "Steam_CreateHTTPRequest") == FeatureStatus_Available)

// Global stuff
new Handle:g_hVersion;

new Handle:g_hGatewayHost;
new String:g_sGatewayHost[128];

new Handle:g_hGatewayPort;
new g_iGatewayPort;

new Handle:g_hGatewayPassword;
new String:g_sGatewayPassword[128];

public Plugin:myinfo = 
{
	name = "CallAdmin: Steam node module",
	author = "Jasper Abbink",
	description = "The steam chat module for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://abb.ink"
}

public OnPluginStart()
{
	AutoExecConfig_SetFile("plugin.calladmin_steamchat");
	
	g_hVersion         = AutoExecConfig_CreateConVar("sm_calladmin_steamchat_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hGatewayHost     = AutoExecConfig_CreateConVar("sm_calladmin_steamchat_gateway_host", "", "The host of the gateway", FCVAR_PLUGIN|FCVAR_PROTECTED);
	g_hGatewayPort     = AutoExecConfig_CreateConVar("sm_calladmin_steamchat_gateway_port", "9876", "The port on the gateway", FCVAR_PLUGIN|FCVAR_PROTECTED);
	g_hGatewayPassword = AutoExecConfig_CreateConVar("sm_calladmin_steamchat_gateway_password", "", "The password for the gateway", FCVAR_PLUGIN|FCVAR_PROTECTED);
	
	
	AutoExecConfig(true, "plugin.calladmin_steamchat");
	AutoExecConfig_CleanFile();
	
	
	SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	HookConVarChange(g_hVersion, OnCvarChanged);
	
	GetConVarString(g_hGatewayHost, g_sGatewayHost, sizeof(g_sGatewayHost));
	HookConVarChange(g_hGatewayHost, OnCvarChanged);

	g_iGatewayPort = GetConVarInt(g_hGatewayPort);
	HookConVarChange(g_hGatewayPort, OnCvarChanged);
	
	GetConVarString(g_hGatewayPassword, g_sGatewayPassword, sizeof(g_sGatewayPassword));
	HookConVarChange(g_hGatewayPassword, OnCvarChanged);
}

public OnCvarChanged(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if(cvar == g_hVersion)
	{
		SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	}
	else if(cvar == g_hGatewayHost)
	{
		GetConVarString(g_hGatewayHost, g_sGatewayHost, sizeof(g_sGatewayHost));
	}
	else if(cvar == g_hGatewayPort)
	{
		g_iGatewayPort = GetConVarInt(g_hGatewayPort);
	}
	else if(cvar == g_hGatewayPassword)
	{
		GetConVarString(g_hGatewayPassword, g_sGatewayPassword, sizeof(g_sGatewayPassword));
	}
}

public OnAllPluginsLoaded()
{
	if(!LibraryExists("calladmin"))
	{
		SetFailState("CallAdmin not found");
	}
}

public CallAdmin_OnReportPost(client, target, const String:reason[])
{
	decl String:sClientName[MAX_NAME_LENGTH];
	decl String:sClientID[32];
	
	decl String:sTargetName[MAX_NAME_LENGTH];
	decl String:sTargetID[32];
	
	decl String:sServerIP[16];
	new serverPort;
	decl String:sServerName[128];
	
	CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
	serverPort = CallAdmin_GetHostPort();
	CallAdmin_GetHostName(sServerName, sizeof(sServerName));
	
	// Reporter wasn't a real client (initiated by a module)
	if(client == REPORTER_CONSOLE)
	{
		strcopy(sClientName, sizeof(sClientName), "Server/Console");
		strcopy(sClientID, sizeof(sClientID), "Server/Console");
	}
	else
	{
		GetClientName(client, sClientName, sizeof(sClientName));
		GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
	}
	
	GetClientName(target, sTargetName, sizeof(sTargetName));
	GetClientAuthId(target, AuthId_Steam3, sTargetID, sizeof(sTargetID));
	
	decl String:sMessage[4096];
	Format(sMessage, sizeof(sMessage), "%s\n%s\n%d\n%s\n%s\n%s\n%s\n%s\n%s", sServerName, sServerIP, serverPort, sClientName, sClientID, sTargetName, sTargetID, reason, g_sGatewayPassword);

	SteamChat_SendMessage(sMessage);
}

#define MAX_REDIRECTS 5

static DLPack_Header = 0;
static DLPack_Redirects = 0;
static DLPack_File = 0;
static DLPack_Request = 0;

SteamChat_SendMessage(const String:message[])
{
	decl String:sRequest[8192];
	FormatEx(sRequest, sizeof(sRequest), "POST /report HTTP/1.0\r\nHost: %s\r\nConnection: close\r\nPragma: no-cache\r\nCache-Control: no-cache\r\nContent-Length: %d\r\n\r\n%s", g_sGatewayHost, strlen(message), message);
	
	//LogMessage("%s", sRequest);
	new Handle:hDLPack = CreateDataPack();
	
	DLPack_Header = GetPackPosition(hDLPack);
	WritePackCell(hDLPack, 0);
	
	DLPack_Redirects = GetPackPosition(hDLPack);
	WritePackCell(hDLPack, 0);
	
	/*DLPack_File = GetPackPosition(hDLPack);
	WritePackCell(hDLPack, _:hFile);*/
	
	DLPack_Request = GetPackPosition(hDLPack);
	WritePackString(hDLPack, sRequest);


	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetArg(socket, hDLPack);
	SocketSetOption(socket, ConcatenateCallbacks, 4096);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, g_sGatewayHost, g_iGatewayPort);
}

public OnSocketConnected(Handle:socket, any:hDLPack) {
	decl String:sRequest[8192];
	SetPackPosition(hDLPack, DLPack_Request);
	ReadPackString(hDLPack, sRequest, sizeof(sRequest));
	
	SocketSend(socket, sRequest);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:hFile) {
	// receive another chunk and write it to <modfolder>/dl.htm
	// we could strip the http response header here, but for example's sake we'll leave it in

	//WriteFileString(hFile, receiveData, false);
}

public OnSocketDisconnected(Handle:socket, any:hFile) {
	// Connection: close advises the webserver to close the connection when the transfer is finished
	// we're done here

	CloseHandle(hFile);
	CloseHandle(socket);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:hFile) {
	// a socket error occured

	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(hFile);
	CloseHandle(socket);
}