#include "data_wr_utils.h" 
#include "hardware/dma.h"
#include <string.h> 
#include <stdlib.h>

void config_to_pinout(config_t *c, pinout_t *p, size_t pl)
{
	uint8_t flat[CONFIG_W]; // flat config
	hard_assert(p);
	hard_assert(pl*CONFIG_W >= sizeof(*c));
	hard_assert(sizeof(flat) == sizeof(*c));
	memcpy(flat, c, sizeof(uint8_t)*CONFIG_W);
	memset(p, 0, sizeof(pinout_t)*pl);
	for(uint i=0; i < CONFIG_W; i++)
	{
		p[i].data_i = flat[i];
		p[i].valid_i = 1; 
		p[i].data_cmd_i = CTRL_DATA_CMD_CTRL;
	}
}

void send_config(uint8_t kk, uint8_t nn, uint64_t ll, uint dma_chan, pinout_t *p, size_t pl)
{
	config_t c; 
	c.kk = kk > 32 ? 32: kk; 
	c.nn = nn > 32 ? 32: nn; 
	c.ll = ll; 
	config_to_pinout(&c, p, pl);
	start_wr_dma_pinout_stream(p, pl ,dma_chan);	
}

// break data into blocks
void data_to_blocs(uint8_t *d, size_t dl, data_blocs_t* b, size_t bl){
	hard_assert(dl <= bl*BLOCK_W);
	memset(b, 0, bl*BLOCK_W);
	memcpy(b, d, dl);
}
// blocs to pinout 
// the start data ctrl mode must be used for at least one transfer system 
// of the first block
// similarly the last must be asserted for at least one cycle of the last
// block
void blocs_to_pinout(data_blocs_t *b, size_t bl, pinout_t *p, size_t pl){
	bool first = true; 
	bool last; 
	hard_assert(bl*BLOCK_W <= pl);
	for(uint i = 0; i < bl; i++){
		for(uint j=0; j < BLOCK_W; j++)
		{
			size_t x = i*BLOCK_W+j;
			last = (i == bl-1) && (j == BLOCK_W-1);
			p[x].valid_i = 1;
			p[x].data_i = b[i].data[j];
			p[x].data_cmd_i = first ? CTRL_DATA_CMD_START : 
				last ? CTRL_DATA_CMD_LAST : CTRL_DATA_CMD_DATA; 
			first = false; 
		}
	}
}

void send_data(uint8_t *data, size_t dl, pinout_t *p, size_t pl, uint dma_chan, PIO pio, uint sm)
{
	size_t bl = (dl+pl-1) / pl; // ceil division, size_t is an unsigned and the c division convention is to round down
	data_blocs_t *blocs = (data_blocs_t*)malloc(bl * sizeof(*blocs));
	hard_assert(blocs);

	data_to_blocs(data, dl, blocs, bl);

	hard_assert(dl <= pl);

	blocs_to_pinout(blocs, bl, p, pl); 

	// stream by block, since we must examine the ready signal between
	// each transfer
	// to guaranty the pio pull is empty 
	dma_channel_wait_for_finish_blocking(dma_chan); // wait for dma channel to be empty, else will overwrite
	for(uint b=0; b < bl; b++){
		start_wr_dma_pinout_stream(&p[b*BLOCK_W], BLOCK_W, dma_chan);
		dma_channel_wait_for_finish_blocking(dma_chan);
		while(pio_sm_get_tx_fifo_level(pio, sm)!=0){}
	} 
	// free
	free(blocs);
}


/* setup dma channel for writing 32b bursts to the PIO TX FIFO 
 * ! not configuring : 
 * - read address 
 * - transder count 
 *   returns : configured dma channel*/
uint init_wr_dma_channel(PIO pio, uint sm)
{
   	uint dma_chan = dma_claim_unused_channel(true);
	dma_channel_config c = dma_channel_get_default_config(dma_chan);
	channel_config_set_read_increment(&c, true); // incremnet the addr we read to on each transfer
	channel_config_set_write_increment(&c, false); // allways write to TX FIFO of the same PIO	
	channel_config_set_dreq(&c, pio_get_dreq(pio, sm, true)); // trigger dreq when there is an empty entry in the TX FIFO
	dma_channel_set_write_addr(dma_chan, &pio->txf[sm], false);
	channel_config_set_enable(&c, false);
	dma_channel_set_config(dma_chan, &c, false);
	return dma_chan; 
}
/* set up dma stream of data to pio
 * assumption: the pinout array is allocated continiously in memory */
void start_wr_dma_pinout_stream(pinout_t *p, size_t pl, uint dma_chan)
{
	// TODO stall until current dma transfer stream is finished
	dma_channel_set_read_addr(dma_chan, p, false);
	dma_channel_set_transfer_count(dma_chan, pl, true);	
}
