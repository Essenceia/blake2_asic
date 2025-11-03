BUILD_DIR:=artifact
PROJECT_NAME:=blake2s_asic_firmeware
SRC:=$(wildcard *.c) $(wildcard *.h) $(wildcard *.pio)

# GDB server config, if variable is not defined when calling `make gdb` use localhost as default
#ifndef GDB_SERVER_ADDR
GDB_SERVER_ADDR:=localhost
#endif

GDB_SERVER_PORT:=3333

${BUILD_DIR}: CMakeLists.txt
	PROJECT_NAME=${PROJECT_NAME} cmake -S . ${BUILD_DIR}

.PHONY: setup build flash debug gdb

setup: ${BUILD_DIR}

build: setup ${SRC}
	PROJECT_NAME=${PROJECT_NAME} cmake --build ${BUILD_DIR} --target ${PROJECT_NAME}
	
flash:
	sudo cp ${BUILD_DIR}/${PROJECT_NAME}.uf2 /mnt/rpi

# using default baudrate
serial:
	picocom -q /dev/ttyACM0
		
# start openocd, will use openocd.cfg as config
debug:
	openocd

#start gdb, hook up to debug server started by openocd
gdb:
	gdb -ex "target remote ${GDB_SERVER_ADDR}:${GDB_SERVER_PORT}" ${BUILD_DIR}/${PROJECT_NAME}.elf

clean:
	yes | rm -rf ${BUILD_DIR}
