#ifndef CGIRBOOT_H
#define CGIRBOOT_H

#include "httpd.h"

int cgi_rboot_get_firmware_next(HttpdConnData *connData);
int cgi_rboot_upload_firmware(HttpdConnData *connData);

void rboot_init(void);

#endif
