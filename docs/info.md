<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
# Blake2s

This is a hashing accelerator for the Blake2 cryptographic hash function (RFC 7693).

This is a fully featured Blake2s implementation supporting both block streaming and using a secret key.

## Background 

blake2s short presentation 

what is the configuration 

## Usage

The typical sequence to offload the hashing operation to the accelerator would go as follows:
1. Reset the accelerator (necessary on init)
2. Configure the hash parameters $kk$, $nn$, $ll$ (can be reused once configured)
3. Stream the input data by blocks of 64 bytes
4. Read the hash result

All data exchanges with the accelerator are in little endian, and when sending multiple-byte-long arrays, the lower indexes are sent first.

Notes:
- Empty cycles, as in one or more cycles where `data_v_i` would go low in the middle of the transfer of both the input data and the configuration, are supported.
### Reset

In order to reset this accelerator to its default uninitialized state, deassert the `rst_n` signal for at least 5 clock cycles. During normal operations, `rst_n` should be set to `1`.

During at least 5 cycles:
- `rst_n` is set to `0`

#### Example

Typical reset sequence:

![rst waves](rst_waves.png)

### Sending the Configuration

The configuration packet is 10 bytes long and has the following format:
```
 Byte:   0        1        2        3        4        5        6        7        8        9
         +--------+--------+---------------------------------------------------------------+
         |   kk   |   nn   |                          ll                                   |
         +--------+--------+---------------------------------------------------------------+
```

$kk$ and $nn$ are both 8 bits wide, and $ll$ is 64 bits wide, and all use little endian.

Sending the configuration takes 10 data transfer cycles, during which:
- `valid_i` is set to `1`
- `mode_i[1:0]` is set to `0`, indicating we are sending the configuration packet
- `data_i[7:0]` sends the next byte of the configuration packet

#### Example

In this example we are sending the following configuration:
- $kk = 1$
- $nn = 32$
- $ll = 67$

![config waves](config_waves.png)

#### Software

In the firmware, the `send_config` function defined in `data_wr_utils.h` is used to send a configuration to the accelerator.
```C
void send_config(uint8_t kk, uint8_t nn, uint64_t ll, uint dma_chan, pinout_t *p, size_t pl, PIO pio, uint sm);
```

### Sending Data

Just like in the original hashing algorithm, the stream of data to be hashed must first be padded with `0x00` to a multiple of 64 bytes, then starting from the lowest indexes first, blocks are sent one by one, one byte at a time.

The sequence to send a block is as follows:
- Wait for ASIC to set `ready_v_o` to `1`

Then, start the 64 data transfer cycles during which:
- `valid_i` is set to `1`
- `mode_i[1:0]` is set to `1` if this is the first data transfer cycle of the first block, `3` if this is the last data transfer cycle of the last block, else it is set to `2`
- `data_i[7:0]` contains the current data byte

The `ready_v_o` signal indicates the accelerator is ready to receive data. In order to improve performance, users can skip waiting for this signal to be re-asserted between each byte transfer and can safely proceed with sending the entire block as soon as the `ready_v_o` signal is observed at `1`.

This optimization has a limitation: since it takes 2 clock cycles for the new value of `ready_v_o` to be written on the output pin, users employing this optimization must guarantee at least a 30ns gap (for 66MHz) between the end of the previous block write and the evaluation of the next `ready_v_o` signal. The current firmware guarantees such a gap.

#### Single Block Example

This is an example of a simple data transfer sequence where the entirety of the data fits within a single block.

Given there is a single block, meaning it is both the first and last block, the `mode_i` control bits are set to `1` on the first cycle and `3` on the last cycle.

![single block data transfer example](wr_data_waves.png)

#### Multi-Block Example

In this example we are sending two blocks of data.

This example shows the data transfer associated with the configuration waves used as an example above ($kk = 1, nn = 32, ll = 67$).

The first block contains the key of size $kk = 1$ byte, the key's contents are 'a' and padded with `0x00` up to 64 bytes.

After the first block has finished sending, we wait until the accelerator asserts the `ready_v_o` signal before starting the second transfer.

The second block contains the $ll - (kk>0?64:0)$, here 3, bytes of data "abc", again padded with `0x00` until 64 bytes.

![multi block data transfer example](double_wr_data_waves.png)

