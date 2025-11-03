#include "loopback_utils.h" 
#include "pinout.h"
#include "hardware/gpio.h" 
#include "hardware/timer.h"
#include <stdio.h> 

/* ctrl bus */
void init_loopback_ctrl()
{
	for(uint x= CTRL_BASE_PIN; x < CTRL_BASE_PIN+DATA_W; x++) {
		gpio_init(x);
		gpio_set_dir(x, GPIO_OUT);
		gpio_set_drive_strength(x, GPIO_DRIVE_STRENGTH_12MA);
		gpio_pull_down(x);	
	}
	gpio_put_masked(DATA_MASK << CTRL_BASE_PIN, 0);
}

void set_loopback_none() {
	gpio_clr_mask((uint32_t)CTRL_LOOPBACK_MASK << CTRL_BASE_PIN);
}
void set_loopback_data() {
	gpio_put_masked(CTRL_LOOPBACK_MASK << CTRL_BASE_PIN, CTRL_LOOPBACK_DATA << CTRL_BASE_PIN);
}
void set_loopback_ctrl() {
	gpio_put_masked(CTRL_LOOPBACK_MASK << CTRL_BASE_PIN, CTRL_LOOPBACK_CTRL << CTRL_BASE_PIN);
}

/* data and hash ( data out ) bus */ 
void init_loopback_data_hash_bus(){
	uint x;
	for(x= DATA_BASE_PIN; x < DATA_BASE_PIN+DATA_W; x++) {
		gpio_init(x);
		gpio_set_dir(x, GPIO_OUT);
		//gpio_set_drive_strength(x, GPIO_DRIVE_STRENGTH_12MA);	
		gpio_pull_down(x);	
	}
	for(x= HASH_BASE_PIN; x < HASH_BASE_PIN+DATA_W; x++) {
		gpio_init(x);
		gpio_set_dir(x, GPIO_IN);
		gpio_pull_down(x);
	}
}

void test_data_loopback(uint32_t loops, uint32_t delay_ms)
{
	uint32_t rand;
	uint32_t data_wr; 
	uint32_t data_rd_raw, data_rd; 
	/* set ctrl to data loopback */
	set_loopback_data();

	for(uint32_t i=0; i < loops; i++)
	{
	
		_Static_assert(DATA_BASE_PIN == 0);

		/* write data, use current time as pseudo random data */ 
		rand = time_us_32();
		data_wr = DATA_MASK & rand; 

		for (uint i = 0; i < DATA_W; i++)
			gpio_put(i, (data_wr >> i) & 0x1);
		//gpio_put_masked(DATA_MASK, data_wr);
		
		sleep_ms(delay_ms);
		/* read data and compare with written data */
		data_rd_raw = gpio_get_all();
		data_rd = 0;
		for(uint8_t w=0,x=HASH_BASE_PIN; x< HASH_BASE_PIN+DATA_W; x++,w++)
			data_rd |= gpio_get(x) << w;

		if (data_rd == data_wr ) printf("["__FILE__"] data match 0x%02x\n", data_wr);	
		else printf("["__FILE__" data missmatch :) wr:0x%02x, rd:0x%02x (raw:0x%08x)\n", data_wr, data_rd, data_rd_raw);	
	}
}
