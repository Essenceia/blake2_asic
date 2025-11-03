#include "pico/stdlib.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pinout.h" 
#include "pinout_pio_match.h" 

#include "hardware/clocks.h"
#include "hardware/pio.h"
#include "hardware/dma.h"

#include "led.pio.h"
#include "bus_clk.pio.h"
#include "sync_sm.pio.h"
#include "data_rd.pio.h"
#include "data_wr.pio.h"
#include "data_wr_utils.h" 
#include "data_rd_utils.h" 
#include "pio_utils.h" 

#include "hardware/structs/dma_debug.h"
#include "hardware/structs/dma.h"
#include "hardware/structs/pio.h"
#include "hardware/structs/sio.h"

#define DELAY_MS 1000

#define PIO_N    5 // number of PIO SM used
#define PIO_LED  0
#define PIO_CLK  1
#define PIO_WR   2
#define PIO_RD   3
#define PIO_SYNC 4
#define macro_str(x) #x

#define PICO_SYS_CLK_HW              200000000   // 200 MHz
#define BUS_PIO_CLK_FREQ_HZ  (float)  80000000.0 //  80 MHz
#define DATA_PIO_CLK_FREQ_HZ (float)  80000000.0 //  80 MHz
#define LED_PIO_CLK_FREQ_HZ  (float)  80000000.0 //  80 MHz

#define _DMA_BASE (uint32_t) 0x50000000
#define TC_OFF   (uint32_t) 0x008
#define TRANSFER_COUNT_ADDR (_DMA_BASE + TC_OFF)

#define MAX_NN 32

#define log_init(PIO_IDX) printf(#PIO_IDX " init sucess %d:{%d:%d}", s, sm[PIO_IDX], offset[PIO_IDX]);
int main() {
	PIO pio[PIO_N];
	uint sm[PIO_N];
	uint offset[PIO_N];
	float clk_div; 
	uint led = 1;
	pinout_t *p;
	bool s = true;
	uint8_t random_data[BLOCK_W];
	size_t pl = BLOCK_W;
	uint8_t hash_buffer[MAX_NN];

	/* debug hw */
	dma_debug_hw_t *debug_dma;
	debug_dma = dma_debug_hw;
	dma_hw_t* hw_dma; 
	hw_dma = dma_hw;
	sio_hw_t *debug_sio;
	debug_sio = sio_hw;


	p = malloc(pl * sizeof(pinout_t));

	memset(random_data,0, BLOCK_W);
	random_data[0] = 'a';
	random_data[1] = 'b';
	random_data[2] = 'c';

	// set system clk
	set_sys_clock_hz(PICO_SYS_CLK_HW, true);
	
	stdio_init_all();
	

	/* data wr */ 
	s &= pio_claim_free_sm_and_add_program(&data_wr_program, &pio[PIO_WR], &sm[PIO_WR], &offset[PIO_WR]);
	log_init(PIO_WR);
	hard_assert(s);
	clk_div = (float)clock_get_hz(clk_sys) / (DATA_PIO_CLK_FREQ_HZ); 
	data_wr_program_init(pio[PIO_WR], sm[PIO_WR], offset[PIO_WR], clk_div);

	/* data rd */ 
	s &= pio_claim_free_sm_and_add_program(&data_rd_program, &pio[PIO_RD], &sm[PIO_RD], &offset[PIO_RD]);
	log_init(PIO_RD);
	hard_assert(s);
	data_rd_program_init(pio[PIO_RD], sm[PIO_RD], offset[PIO_RD], clk_div);

	/* bus clk */
	s &= pio_claim_free_sm_and_add_program_for_gpio_range(
		&bus_clk_program, 
		&pio[PIO_CLK], &sm[PIO_CLK], &offset[PIO_CLK],
		BUS_CLK_PIN, 1, true);
	log_init(PIO_CLK);
	hard_assert(s);
	clk_div = (float)clock_get_hz(clk_sys) / (BUS_PIO_CLK_FREQ_HZ); 
	bus_clk_program_init(pio[PIO_CLK], sm[PIO_CLK], offset[PIO_CLK], BUS_CLK_PIN, clk_div);

	/* sync program */
	s &= pio_claim_free_sm_and_add_program(&sync_sm_program, &pio[PIO_SYNC], &sm[PIO_SYNC], &offset[PIO_SYNC]);
	log_init(PIO_SYNC);
	hard_assert(s);
	sync_sm_program_init(pio[PIO_SYNC], sm[PIO_SYNC], offset[PIO_SYNC], clk_div);

	/* led - explicitlt place on PIO0 to prevent overwritting of GPIO25 by `pull noblock` on data_wr*/
	s = allocate_prog_pio(0, &pio[PIO_LED], &sm[PIO_LED], &offset[PIO_LED], &led_program);
	log_init(PIO_LED);
	hard_assert(s);
	led_program_init(pio[PIO_LED], sm[PIO_LED], offset[PIO_LED], PICO_DEFAULT_LED_PIN, clk_div);	
	
	hard_assert(pio[PIO_CLK] == pio[PIO_WR]);
	hard_assert(pio[PIO_CLK] == pio[PIO_SYNC]);
	hard_assert(pio[PIO_WR] == pio[PIO_RD]);
	uint32_t sm_mask = 1u << sm[PIO_CLK] | 1u << sm[PIO_WR] | 1u << sm[PIO_SYNC] | 1u << sm[PIO_RD];
	pio_enable_sm_mask_in_sync(pio[PIO_CLK], sm_mask);

	/* data wr */ 
	uint wr_dma_chan = init_wr_dma_channel(pio[PIO_WR], sm[PIO_WR]);
	/* data rd */
	uint rd_dma_chan = init_rd_dma_channel(pio[PIO_RD], sm[PIO_RD]);

	uint32_t tc; 
	uint tx_fifo_lvl, rx_fifo_lvl;
	bool stalled;
	uint8_t pio_pc;
	uint64_t it_cnt = 0;
	pio_hw_t *debug_pio;
	debug_pio = PIO_INSTANCE(1);
	const uint nn = MAX_NN;
	uint8_t hash[MAX_NN];

    while (true) {
		/* debug */
		tx_fifo_lvl = pio_sm_get_tx_fifo_level(pio[PIO_WR], sm[PIO_WR]); 
		rx_fifo_lvl = pio_sm_get_rx_fifo_level(pio[PIO_RD], sm[PIO_RD]); 
		stalled = pio_sm_is_exec_stalled(pio[PIO_WR], sm[PIO_WR]);
		pio_pc = pio_sm_get_pc(pio[PIO_WR], sm[PIO_WR]);
		tc = dma_hw->ch[rd_dma_chan].transfer_count; 
	
		/* config */
		send_config(0, nn, 3, wr_dma_chan, p, pl, pio[PIO_WR], sm[PIO_WR]);

		/* setup dma hash read stream */
		setup_rd_dma_hash_stream(rd_dma_chan, nn, hash_buffer, MAX_NN, pio[PIO_RD], sm[PIO_RD]);

		/* send data */
		send_data(random_data, BLOCK_W, p, pl, wr_dma_chan, pio[PIO_WR], sm[PIO_WR]);

		/* get hash from memory, writen over dma */
		read_hash(hash, nn, hash_buffer, MAX_NN, rd_dma_chan);
		
		pio_sm_put_blocking(pio[PIO_LED], sm[PIO_LED], led);
		led = led ? 0:1;
#ifdef DEBUG_LOG
		printf("DMA channel busy %d wr PIO TX FIFO lvl %d trans count %d\n",
			dma_channel_is_busy(wr_dma_chan),
			pio_sm_get_tx_fifo_level(pio[PIO_WR], sm[PIO_WR]), 
			*tc);
		printf("PIO0 ctrl 0x%08x\n", debug_pio->ctrl);
		sleep_ms(DELAY_MS);
#endif
		
    }
}
