FQBN := rp2040:rp2040:generic:flash=16777216_0,freq=133,opt=Small,rtti=Disabled,stackprotect=Disabled,exceptions=Disabled,dbgport=Disabled,dbglvl=None,usbstack=tinyusb,boot2=boot2_generic_03h_2_padded_checksum
# Optional extra arduino-cli arguments.
ARDUINO_EXTRA_ARGS ?=
# Enable built-in Phase 0 compile flags via:
# make HEX_PHASE0=1
HEX_PHASE0 ?= 0
HEX_PHASE0_DUMP_ON_BOOT ?= 1
HEX_PHASE0_APPLY_BASELINE_PRESET ?= 1

ifeq ($(HEX_PHASE0),1)
PHASE0_EXTRA_FLAGS := --build-property compiler.cpp.extra_flags="-DHEX_PHASE0_ENABLE=1 -DHEX_PHASE0_DUMP_ON_BOOT=$(HEX_PHASE0_DUMP_ON_BOOT) -DHEX_PHASE0_APPLY_BASELINE_PRESET=$(HEX_PHASE0_APPLY_BASELINE_PRESET)"
else
PHASE0_EXTRA_FLAGS :=
endif

ifeq ($(OS),Windows_NT)
COPY_INO := powershell -NoProfile -Command "Copy-Item 'src/HexBoard.ino' 'build/build.ino' -Force"
else
COPY_INO := cp src/HexBoard.ino build/build.ino
endif

# Copied fqbn from build.options.json
build/build.ino.uf2: build/build.ino
	arduino-cli compile -b $(FQBN) $(PHASE0_EXTRA_FLAGS) $(ARDUINO_EXTRA_ARGS) --output-dir build build
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
