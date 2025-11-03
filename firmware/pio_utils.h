#ifndef _PIO_UTILS_H
#define _PIO_UTILS_H
#include <stdlib.h> 
#include "hardware/pio.h" 

bool allocate_prog_pio(const uint pio_num, PIO *pio, uint *sm, uint *offset, const pio_program_t *program);

#endif // _PIO_UTILS_H
