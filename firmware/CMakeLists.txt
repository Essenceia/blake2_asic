cmake_minimum_required(VERSION 3.13...3.27)

# initialise SDK and set PICO_SDK_PATH
include(/home/pitchu/code/pico-sdk/pico_sdk_init.cmake)

set(project_name $ENV{PROJECT_NAME})
project(${project_name})

# initialize the Raspberry Pi Pico SDK
pico_sdk_init()

FILE(GLOB c_code_src *.c *.h)
FILE(GLOB pio_code_src *.pio)

# debug 
set(CMAKE_BUILD_TYPE Debug)
set(PICO_DEOPTIMIZED_DEBUG 1)
set(CMAKE_C_FLAGS_DEBUG "-O0 -g3" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g3" CACHE STRING "" FORCE)

add_executable(${project_name})

pico_generate_pio_header(${project_name} ${pio_code_src})
target_sources(${project_name} PRIVATE ${c_code_src})

target_link_libraries(${project_name}
	pico_stdlib
	hardware_pio
	hardware_clocks
	hardware_timer
	hardware_dma
	pico_base_headers
	)

# enable usb
pico_enable_stdio_usb(${project_name} 1)
pico_enable_stdio_uart(${project_name} 0)

pico_add_extra_outputs(${project_name})
