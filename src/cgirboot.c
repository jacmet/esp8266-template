/*
 * Some flash handling cgi routines for rboot. Used for updating the
 * ESPFS/OTA image. Based on libesphttpd code.
*/

/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * Jeroen Domburg <jeroen@spritesmods.com> wrote this file. As long as you retain 
 * this notice you can do whatever you want with this stuff. If we meet some day, 
 * and you think this stuff is worth it, you can buy me a beer in return. 
 * ----------------------------------------------------------------------------
 */

#include <esp8266.h>
#include "rboot-api.h"
#include "cgirboot.h"

/* two roms supported */
static inline uint8 get_next_rom(void)
{
		return !rboot_get_current_rom();
}

/* we need to finish up http request before restarting */
static void ICACHE_FLASH_ATTR rboot_schedule_restart(void)
{
	static os_timer_t resetTimer;

	os_timer_disarm(&resetTimer);
	os_timer_setfn(&resetTimer, (os_timer_func_t *)system_restart, NULL);
	os_timer_arm(&resetTimer, 200, 0);
}

// Cgi to query which firmware needs to be uploaded next
int ICACHE_FLASH_ATTR cgi_rboot_get_firmware_next(HttpdConnData *connData)
{
	if (connData->conn == NULL) {
		// Connection aborted. Clean up.
		return HTTPD_CGI_DONE;
	}
	uint8 id = get_next_rom();
	httpdStartResponse(connData, 200);
	httpdHeader(connData, "Content-Type", "text/plain");
	httpdHeader(connData, "Content-Length", "9");
	httpdEndHeaders(connData);
	char *next = id ? "rom1.bin" : "rom0.bin";
	httpdSend(connData, next, -1);
	httpd_printf("Next firmware: %s (got %d)\n", next, id);
	return HTTPD_CGI_DONE;
}

// Cgi that allows the firmware to be replaced via http POST This takes
// a direct POST from e.g. Curl or a Javascript AJAX call with either the
// firmware given by cgiGetFirmwareNext or an OTA upgrade image.
int ICACHE_FLASH_ATTR cgi_rboot_upload_firmware(HttpdConnData *connData)
{
	rboot_write_status *status = connData->cgiData;

	if (connData->conn == NULL) {
		// Connection aborted. Clean up.
		if (status)
			free(status);
		return HTTPD_CGI_DONE;
	}

	if (status == NULL) {
		rboot_config cfg = rboot_get_config();
		uint8 id = get_next_rom();

		// First call. Allocate and initialize state variable.
		httpd_printf("Firmware upload cgi of %d bytes start at 0x%x.\n",
					 connData->post->len, cfg.roms[id]);

		status = malloc(sizeof(rboot_write_status));
		if (status == NULL) {
			httpd_printf("Can't allocate firmware upload struct!\n");
			return HTTPD_CGI_DONE;
		}
		*status = rboot_write_init(cfg.roms[id]);
		connData->cgiData = status;
	}

	httpd_printf("upload %d %%\n", (connData->post->received * 100) / connData->post->len);

	if (!rboot_write_flash(status, (uint8 *)connData->post->buff, connData->post->buffLen)) {
		httpd_printf("write error\n");
		return HTTPD_CGI_DONE;
	}

	if (connData->post->len == connData->post->received) {
		bool ok = rboot_write_end(status);
		// We're done! Format a response.
		httpd_printf("Upload done. Sending response.\n");
		httpdStartResponse(connData, ok ? 200 : 400);
		httpdHeader(connData, "Content-Type", "text/plain");
		httpdEndHeaders(connData);
		free(status);

		if (ok) {
#ifdef BOOT_RTC_ENABLED
			rboot_set_temp_rom(get_next_rom());
#else
			rboot_set_current_rom(get_next_rom());
#endif
			rboot_schedule_restart();
		}

		return HTTPD_CGI_DONE;
	}

	return HTTPD_CGI_MORE;
}

void ICACHE_FLASH_ATTR rboot_init(void)
{
// mark firmware as good
#ifdef BOOT_RTC_ENABLED
	uint8 mode;

	if (rboot_get_last_boot_mode(&mode) && (mode & MODE_TEMP_ROM)) {
		uint8 rom;

		if (!rboot_get_last_boot_rom(&rom) || !rboot_set_current_rom(rom))
			httpd_printf("Error permanently changing rom (%u)\n", rom);
	}
#endif
}
