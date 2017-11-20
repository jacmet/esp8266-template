#include <user_interface.h>

#include "uart.h"
#include "webserver.h"

void ICACHE_FLASH_ATTR user_init(void)
{
	uart_init();

	ets_printf("hello world wifi\r\n");

	webserver_init();
	rboot_init();
}
