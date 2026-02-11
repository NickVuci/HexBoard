FQBN := rp2040:rp2040:generic:flash=16777216_2097152,freq=133,opt=Small,rtti=Disabled,stackprotect=Disabled,exceptions=Disabled,dbgport=Disabled,dbglvl=None,usbstack=tinyusb,boot2=boot2_generic_03h_2_padded_checksum
# Optional extra arduino-cli arguments.
ARDUINO_EXTRA_ARGS ?=

ifeq ($(OS),Windows_NT)
COPY_INO := powershell -NoProfile -Command "Copy-Item 'src/HexBoard.ino' 'build/build.ino' -Force"
else
COPY_INO := cp src/HexBoard.ino build/build.ino
endif

# Copied fqbn from build.options.json
build/build.ino.uf2: build/build.ino
	arduino-cli compile -b $(FQBN) $(ARDUINO_EXTRA_ARGS) --output-dir build build
build/build.ino: src/HexBoard.ino
	$(COPY_INO)

/run/media/*/RPI-RP2/INFO_UF2.TXT:
	echo "Mounting device"
	udisksctl mount -b /dev/disk/by-label/RPI-RP2

install: build/build.ino.uf2 /run/media/*/RPI-RP2/INFO_UF2.TXT
	echo "Trying to copy into mounted device"
	cp build/build.ino.uf2 /run/media/*/RPI-RP2/
	echo "Installed."
	sleep 7
	echo "Rebooted."
