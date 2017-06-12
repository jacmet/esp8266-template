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

clean:
	rm -rf firmware
	$(MAKE) -C rboot clean
	$(MAKE) -C esptool2 clean
