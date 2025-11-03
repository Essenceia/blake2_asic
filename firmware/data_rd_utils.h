#ifndef _DATA_RD_UTILS
#define _DATA_RD_UTILS

#include "pico/stdlib.h"
#include "hardware/pio.h"

#define PIO_FIFO_W 4 // Bytes

// init dma
uint init_rd_dma_channel(PIO pio, uint sm);

// setup dma stream to capture hash result
void setup_rd_dma_hash_stream(uint dma_chan, uint nn, uint8_t* buffer, size_t bl, PIO pio, uint sm);

// read hash from already setup read stream 
void read_hash(uint8_t* hash, uint8_t nn, uint8_t* buffer, size_t bl, uint dma_chan);

#endif // _DATA_RD_UTILS

