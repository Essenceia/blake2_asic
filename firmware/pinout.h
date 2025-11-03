#ifndef _PINNOUT_H
#define _PINNOUT_H

/* define pinnout to FPGA emulation */ 
#define BUS_CLK_PIN 28

#define DATA_W        8
#define DATA_BASE_PIN 0 
#define HASH_BASE_PIN 8
#define CTRL_BASE_PIN 16

typedef struct __attribute__((packed)) {
	uint8_t data_i;
	uint8_t hash_o;
	uint8_t valid_i : 1;
	uint8_t data_cmd_i : 2;
	uint8_t ready_o : 1;
	uint8_t loopback_mode_i : 2; 
	uint8_t unusued : 1;
	uint8_t padding : 3; /* rpi-pico doesn't expose pins in order, after gpio 22 the next pin is gpio 26 */ 
	uint8_t hash_valid_o : 1;
	uint8_t padding1 : 5;	
} pinout_t;

_Static_assert(sizeof(pinout_t) == (32/8));

/* data */ 
#define DATA_MASK (uint32_t) 0xFF

/* data ctrl */
#define CTRL_DATA_W 3
#define CTRL_DATA_MASK (uint32_t) 0x7
#define CTRL_DATA_BASE_PIN CTRL_BASE_PIN
#define CTRL_VALID_PIN CTRL_DATA_BASE_PIN 
#define CTRL_MODE0_PIN CTRL_DATA_BASE_PIN+1
#define CTRL_MODE1_PIN CTRL_DATA_BASE_PIN+2

#define CTRL_READY_PIN      (CTRL_BASE_PIN+3)
#define CTRL_HASH_VALID_PIN 26

#define CTRL_DATA_CMD_CTRL  0x0
#define CTRL_DATA_CMD_START 0x1
#define CTRL_DATA_CMD_DATA  0x2
#define CTRL_DATA_CMD_LAST  0x3

/* loopback mode ctrl */ 
#define CTRL_LOOPBACK_DATA (uint32_t) 0x10 
#define CTRL_LOOPBACK_CTRL (uint32_t) 0x20 
#define CTRL_LOOPBACK_MASK (uint32_t) 0x30 // bits [5:4] 8'b0011_0000

/* PIO defines */ 
// side of data to write OUT, also used as autopull threshold
#define DATA_WR_W CTRL_MODE1_PIN

#endif //_PINNOUT_H
