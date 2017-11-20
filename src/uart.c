#include <user_interface.h>
#include "uart.h"

void ICACHE_FLASH_ATTR uart_init(void)
{
	// Enable TxD pin
	PIN_PULLUP_DIS(PERIPHS_IO_MUX_U0TXD_U);
	PIN_FUNC_SELECT(PERIPHS_IO_MUX_U0TXD_U, FUNC_U0TXD);

	// Set baud rate
	uart_div_modify(0, UART_CLK_FREQ/115200);
}
