#ifndef __MQTT_CONFIG_H__
#define __MQTT_CONFIG_H__

/* From esp_mqtt/include/user_config.sample.h */

//#define MQTT_SSL_ENABLE

#define MQTT_RECONNECT_TIMEOUT  5 /*second*/

#define MQTT_BUF_SIZE   1024

#define DEFAULT_SECURITY  0

#define PROTOCOL_NAMEv311     /*MQTT version 3.11 compatible with https://eclipse.org/paho/clients/testing/*/

#if defined(DEBUG_ON)
#define INFO( format, ... ) os_printf( format, ## __VA_ARGS__ )
#else
#define INFO( format, ... )
#endif

#endif // __MQTT_CONFIG_H__
