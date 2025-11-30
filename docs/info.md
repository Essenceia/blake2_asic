<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
# Blake2s RTL implementation

Implementation of the Blake2 cryptographic hash function (RFC7693) in synthesizable RTL.
This is a fully featured blake2s implementation supporting both block streaming and proving the secret key.


## Background 

blake2s short presentation 

what is the configuration 

## Usage

The typical sequence to offload the hashing operation the accelerator would go as follows:

  1. Reset the accelerator (necessary on init)
  2. Configure the hash paramters $kk$, $nn$, $ll$ (can be re-used once configured)
  3. Steam the input data by blocks of 64 Bytes
  4. Read the hash result

All data exchanges with the accelerator are in little endian, and when sending mutilple byte long arrays, the lower indexes are sent first. 

Notes:

- Empty cycles, as in one or more cycles where data_v_i would go low in the middle of the transfer of both the input data and the configuration, are supported.

### Reset

In order to reset this accelerator to it's default uninitalised state deassert the `rst_n` signal for at least `5` clock cycles, during normal operations `rst_n` should be set to `1`. 

- `rst_n` is set to `0`

#### Example

Typical reset sequence : 

![rst waves](rst_waves.png)


### Sending the configuration 

The weight configuration packet is a 10 Bytes long and has the following format : 
```
 Byte:   0        1        2        3        4        5        6        7        8        9
         +--------+--------+---------------------------------------------------------------+
         |   kk   |   nn   |                          ll                                   |
         +--------+--------+---------------------------------------------------------------+
```
$kk$ and $nn$ are both 8 bits wide, and $ll$ is 64bits wide, and are all using little endian. 

Sending the configuration takes 10 data transfer cycles, during which: 
- `ctrl_v_i` is set to `1`.
- `ctrl_mode_i[1:0]` is set to `0`, this indicates we are sending the configuration packet.
- `data_i[7:0]` is sending the next byte of the configuration packet.

#### Example

In this example we sending the following configuration : 
- $kk = 1$
- $nn = 32$
- $ll = 67$

![config waves](config_waves.png)

#### Software

In the firmware `send_config` function defined in `data_wr_utils.h` is used to send a configuration to the accelerator.

```C
void send_config(uint8_t kk, uint8_t nn, uint64_t ll, uint dma_chan, pinout_t *p, size_t pl, PIO pio, uint sm);
```

### Stending data

