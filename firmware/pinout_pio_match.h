#ifdef  _PINOUT_PIO_MATCH_H
#define _PINOUT_PIO_MATCH_H

#include "pinout.h" 
#include "data_wr.pio.h"

/* checking PIO defines and pinout values match */
_Static_assert(data_wr_CTRL_READY_PIN == CTRL_READY_PIN)
_Static_assert(data_wr_BUS_CLK_PIN == BUS_CLK_PIN)

#endif // _PINOUT_PIO_MATCH_H
