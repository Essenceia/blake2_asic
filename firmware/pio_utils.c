#include "pio_utils.h"

bool allocate_prog_pio(const uint pio_num, PIO *pio, uint *sm, uint *offset, const pio_program_t *program)
{
	int8_t tmp_sm;
	int tmp_offset;
	hard_assert(pio_num < 2);

	*pio = pio_get_instance(pio_num);
	 
	tmp_sm = pio_claim_unused_sm(*pio, true);
	if (tmp_sm < 0) return false;
		
	tmp_offset = pio_add_program(*pio, program);
	if (tmp_offset < 0) return false; 

	*offset = (uint)tmp_offset; 
	*sm = tmp_sm; 	
	return true; 
}
