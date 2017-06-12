# esptool
ESPTOOL = esptool/esptool.py

ESPTOOL_OPTS ?= --port /dev/ttyUSB0 --baud 460800

# flash type/mode
ESPTOOL_WRITE_OPTS ?= --flash_freq 40m --flash_mode qio --flash_size 4MB


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

flash: firmware/rboot.bin
	$(ESPTOOL) $(ESPTOOL_OPTS) write_flash $(ESPTOOL_WRITE_OPTS) \
		0x0000 firmware/rboot.bin

clean:
	rm -rf firmware
	$(MAKE) -C rboot clean
	$(MAKE) -C esptool2 clean

.PHONY: clean flash
