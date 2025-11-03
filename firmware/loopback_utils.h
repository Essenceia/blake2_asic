#ifndef _LOOPBACK_UTILS_H
#define _LOOPBACK_UTILS_H
#include "pico/stdlib.h" 

/* GPIO control of loopback pins, used for experimentations */

/* init loopback ctrl pins */
void init_loopback_ctrl();

/* set loopback modes */
void set_loopback_none();
void set_loopback_data();
void set_loopback_ctrl();

/* data in/out gpio controls
 * this should not be called when data is expected to be driven over pio !
 * used for bus bringup only */
void init_loopback_data_hash_bus();

void test_data_loopback(uint32_t loops, uint32_t delay);

#endif // _LOOPBACK_UTILS_H
