# expects
# SDK=/path/to/sdk-dir
# XTENSA_BINDIR=/path/to/xtenxa/bin
# FLASH_SIZE=0x400000

# the base ldscript that will be used for rom0/rom1 builds (after
# adjusting rom0 location/size)
BASE_LDSCRIPT = $(SDK)/ld/eagle.app.v6.ld

CC := $(XTENSA_BINDIR)/xtensa-lx106-elf-gcc

ifeq ($(wildcard $(BASE_LDSCRIPT)),)
$(error Missing or invalid SDK setting. Pass SDK=/path/to/sdk/dir)
endif

ifeq ($(wildcard $(CC)),)
$(error Missing or invalid XTENSA_BINDIR setting. Pass XTENSA_BINDIR=/path/to/xtensa/bin)
endif

# convert expression to hexidecimal
define tohex
$(shell printf '0x%x' $$(( $1 )))
endef

# esptool
ESPTOOL = esptool/esptool.py

ESPTOOL_OPTS ?= --port /dev/ttyUSB0 --baud 460800 --chip esp8266

# flash type/mode
ESPTOOL_WRITE_OPTS ?= --flash_freq 40m --flash_mode qio

ifeq ($(FLASH_SIZE),0x80000)
EPSTOOL_WRITE_OPTS += --flash_size 512KB
else ifeq ($(FLASH_SIZE),0x100000)
EPSTOOL_WRITE_OPTS += --flash_size 1MB
else ifeq ($(FLASH_SIZE),0x200000)
EPSTOOL_WRITE_OPTS += --flash-size 2MB
else ifeq ($(FLASH_SIZE),0x400000)
EPSTOOL_WRITE_OPTS += --flash-size 4MB
else
$(error Invalid FLASH_SIZE ($(FLASH_SIZE). Pass FLASH_SIZE=0xsize))
endif

# rom size and locations
#
# rboot is used, so the (default) flash layout is:
# sector size: 0x1000 (4KB)
# 0..0x1000     : rboot
# 0x1000..0x2000: rboot config
# 0x2000..?     : low image
# 0x82000..?    : high image
# flash-20K     : rfcal
# flash-16K     : esp_init_data_default.bin
# flash-8K      : blank.bin

# images begin after rboot + rboot config. The actual images are
# prepended by a v2 header, so the .text section starts at offset 0x10
ROM0 := $(call tohex,0x2000)
ifeq ($(FLASH_SIZE),0x80000)
ROM1 := $(call tohex,0x2000 + 0x40000)
ROM_SIZE = 0x3c000
else
ROM1 := $(call tohex,0x2000 + 0x80000)
ROM_SIZE = 0x7c000
endif

# rfcal/sysparam in the last 20KB of the flash
SYSPARAM_SIZE  := $(call tohex,20 * 1024)
SYSPARAM_START := $(call tohex,$(FLASH_SIZE) - $(SYSPARAM_SIZE))
# esp_init_data_default.bin goes to flash_size - 16K
INITDATA_START := $(call tohex,$(FLASH_SIZE) - 16 * 1024)

FLASH_MEMADDR = 0x40200000


SRCS ?= main.c
OBJS = $(SRCS:.c=.o)
LIBS = c gcc hal phy pp net80211 lwip wpa main
CFLAGS  = -Os -g -O2 -Wpointer-arith -Wundef -Werror -Wno-implicit \
	-Wl,-EL -fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals \
	-D__ets__ -DICACHE_FLASH -I.
LDFLAGS = -nostdlib -Wl,--no-check-sections -u call_user_start -Wl,-static

# fixup rom0 location/size for rom0/rom1 builds
firmware/rom%.ld: $(BASE_LDSCRIPT)
	sed 's/\(.*irom0_0_seg :.*org = \)0x[0-9a-fA-F]*, len = 0x[0-9a-fA-F]*/\1$(ROM), len = $(ROM_SIZE)/' $^ > $@

firmware/rom0.ld: ROM=$(call tohex,$(FLASH_MEMADDR) + $(ROM0) + 0x10)
firmware/rom1.ld: ROM=$(call tohex,$(FLASH_MEMADDR) + $(ROM1) + 0x10)

firmware/%.bin: firmware/%.elf
	$(ESPTOOL) $(ESPTOOL_OPTS) elf2image --version=2 -o $@ $^

firmware/%.elf: $(OBJS) firmware/%.ld
	$(CC) $(LDFLAGS) -L $(SDK)/ld -T $(@F:.elf=.ld) \
		-Wl,--start-group $(addprefix -l,$(LIBS)) $< -Wl,--end-group \
		-o $@

# libesphttpd
libesphttpd/libesphttpd.a:
	$(MAKE) -C libesphttpd SDK_BASE=$(SDK) XTENSA_TOOLS_ROOT=$(XTENSA_BINDIR)/ USE_OPENSDK=yes

# rboot build options
RBOOT_OPTS ?= RBOOT_BAUDRATE=115200

# needed by rboot
esptool2/esptool2:
	$(MAKE) -C esptool2

rboot/firmware/rboot.bin: esptool2/esptool2
	$(MAKE) -C rboot $(RBOOT_OPTS)

firmware:
	mkdir -p $@

firmware/rboot.bin: rboot/firmware/rboot.bin firmware
	cp $< $@

flash: firmware/rboot.bin firmware/rom0.bin firmware/rom1.bin
	$(ESPTOOL) $(ESPTOOL_OPTS) erase_region $(SYSPARAM_START) $(SYSPARAM_SIZE)
	$(ESPTOOL) $(ESPTOOL_OPTS) write_flash $(ESPTOOL_WRITE_OPTS) \
		0x000000 firmware/rboot.bin \
		$(ROM0) firmware/rom0.bin \
		$(ROM1) firmware/rom1.bin \
		$(INITDATA_START) $(SDK)/bin/esp_init_data_default.bin

clean:
	rm -rf firmware
	$(MAKE) -C rboot clean
	$(MAKE) -C esptool2 clean
	$(MAKE) -C libesphttpd clean

.PHONY: clean flash
