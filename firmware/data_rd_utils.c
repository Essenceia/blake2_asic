#include "data_rd_utils.h"
#include "hardware/dma.h"
#include <string.h> 

/* init dma for hash reads from the RX FIFO to memory 
 * writes using 32b bursts ( size of the PIO RX FIFO )
 */
uint init_rd_dma_channel(PIO pio, uint sm){
	uint dma_chan = dma_claim_unused_channel(true);
	dma_channel_config c = dma_channel_get_default_config(dma_chan);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
	channel_config_set_read_increment(&c, false); // allways read the same FIFO 
	channel_config_set_write_increment(&c, true); // increment write address on each transfer
	channel_config_set_dreq(&c, pio_get_dreq(pio, sm, false)); // trigger dreq when there is an valid entry in the RX FIFO
	dma_channel_set_read_addr(dma_chan, &pio->rxf[sm], false);
	channel_config_set_high_priority(&c, true); // prioritize receiving hash over sending data/config
	channel_config_set_enable(&c, false); 
	dma_channel_set_config(dma_chan, &c, false);
	return dma_chan; 
}

void setup_rd_dma_hash_stream(uint dma_chan, uint nn, uint8_t* buffer, size_t bl){
	size_t tc = (nn + PIO_FIFO_W-1)/ PIO_FIFO_W;	
	hard_assert(tc <= bl*PIO_FIFO_W);
	// clear hash, helps with debug
	memset(buffer, 0, bl);
	hard_assert(!dma_channel_is_busy(dma_chan));
	dma_channel_set_write_addr(dma_chan, buffer, false);
	dma_channel_set_transfer_count(dma_chan, tc, true);
}

void read_hash(uint8_t* hash, uint8_t nn, uint8_t *buffer, size_t bl, uint dma_chan){
	dma_channel_wait_for_finish_blocking(dma_chan);
	hard_assert(nn <= bl);
	memcpy( hash, buffer, nn);
}

