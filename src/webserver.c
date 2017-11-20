#include "webserver.h"
#include "esp8266.h" /* needed by httpd.h */
#include "httpd.h"
#include "captdns.h"
#include "cgirboot.h"
#include "cgiwifi.h"
#include "httpdespfs.h"
#include "webpages-espfs.h"

static HttpdBuiltInUrl urls[] = {
	{"*", cgiRedirectApClientToHostname, "esp8266.nonet"},

	{"/", cgiRedirect, "/index.tpl"},
	{"/flash/", cgiRedirect, "/flash/index.html"},
	{"/flash/next", cgi_rboot_get_firmware_next, NULL},
	{"/flash/upload", cgi_rboot_upload_firmware, NULL},

	{"/wifi", cgiRedirect, "/wifi/wifi.tpl"},
	{"/wifi/", cgiRedirect, "/wifi/wifi.tpl"},
	{"/wifi/wifiscan.cgi", cgiWiFiScan, NULL},
	{"/wifi/wifi.tpl", cgiEspFsTemplate, tplWlan},
	{"/wifi/connect.cgi", cgiWiFiConnect, NULL},
	{"/wifi/connstatus.cgi", cgiWiFiConnStatus, NULL},
	{"/wifi/setmode.cgi", cgiWiFiSetMode, NULL},

	{"*", cgiEspFsHook, NULL}, // Catch-all cgi function for the filesystem
	{NULL, NULL, NULL}
};

void ICACHE_FLASH_ATTR webserver_init(void)
{
	captdnsInit();
	espFsInit((void*)(webpages_espfs_start));
	httpdInit(urls, 80);
}
