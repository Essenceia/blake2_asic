import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles
from cocotb.clock import Clock

import logging
import math 
import hashlib
import random 


BB=64 # Number of bytes in a data block, constant set by blake2s spec

# Generate data command configuration, sent allong each valid data
# transfer data cycle to convay metadata about the data. 
#
# value - meaning
#     0 - hash configuration data, setting: kk, nn, ll
#     1 - first/start, part of the first block of the data to be hashed
#     2 - data to be hashed
#     3 - finish/last, part of the last block of data to be hashed
def get_cmd(valid=True, conf=False, start=False, data=False, last=False):
    check = [conf, start, data, last]
    assert(sum(check) == 1) # check one hot 0
    if (conf):
        cmd = 0
    elif (start):
        cmd = 1;
    elif (data):
        cmd = 2
    elif (last):
        cmd = 3
    return valid | cmd << 1
   
 
# Dissable data transfert for "cycles" cycles.
# Used to simulate realistic conditions where the data transfer
# from the master (microcontroller, FPGA) would be done in bursts.
# Using the RP2040 this might occure when the PIO write sequence is
# stalled due to the DMA transfer no keeping up with the PIO write
# rate and the TX FIFO being empty. 
async def invalid_data(dut, cycles):
    for i in range(0, cycles):
        dut.uio_in.value = 0
        dut.ui_in.value = 0
        await ClockCycles(dut.clk,1)


# Send hash configuration values, named as per the spec.
# Lengths are expressed in bytes
# kk - key length
# nn - retured hash length
# ll - data length
#
# In this testing we send the config before each data transfer, in 
# practice this is not necessary and the config can be re-used for
# multiple hashs. 
async def write_config(dut, kk, nn, ll):
    cocotb.log.debug("write config kk: %d, nn:%d , ll: %d",kk, nn, ll)
    if kk > 0: 
        ll = ll + BB
    # kk (8b), nn (8b), ll (64b)
    config_data = bytearray(0)
    config_data.append(kk)
    config_data.append(nn)
    config_data.extend(ll.to_bytes(8, 'little'))
    for i in range(0,10):
        if (random.randrange(0,100) > 75):
            await invalid_data(dut, random.randrange(1,5)) 
        dut.uio_in.value = get_cmd(conf=True)
        dut.ui_in.value = config_data[i]
        await ClockCycles(dut.clk,1)
    dut.uio_in.value = 0


# Send data blocks, blocks are of 64 bytes and must wait for 
# the ready signal before sending. 
# Data command indicates if this is the first/last/neither block
# in a sequence of block transfers. It is only necessary to 
# assert this command one cycle in a block transfer. 
# For data with only 1 block ( data length <= 64B & key lenght == 0) 
# both the first and last command will be set on the block.
# Adding empty transfer cycles to increase verification stress, 
# see above for reasonging.  
async def write_data_in(dut, block=b'', start=False, last=False):
    assert(len(block) == BB )
    cocotb.log.debug("block %s", block)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 1)
    if(int(dut.ready_v.value) == 0):
        await RisingEdge(dut.ready_v)
    assert(int(dut.ready_v.value) == 1)
    cocotb.log.debug("ready %s",dut.ready_v)
 
    for i in range(0,BB):
        if (random.randrange(0,100) > 75):
            await invalid_data(dut, random.randrange(1,5))
        dut.uio_in.value = get_cmd(data=True)
        if (i == 0) and start: 
            dut.uio_in.value = get_cmd(start=True)
        if (i == BB - 1) and last:
            cocotb.log.debug("last") 
            dut.uio_in.value = get_cmd(last=True)
        dut.ui_in.value = block[i]
        await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0

# Intermediary helped function, split up data and keybyte array to 
# blocks to be sent out. 
# If a key is providided it will be 0 extended and it's value
# as the first data block.
async def send_data_to_hash(dut, key=b'', data=b''):
    cocotb.log.debug("write_data key(%s) data(%s)", len(key), len(data))
    start = True
    last = False

    assert(len(data) > 0) 
    if len(key) > 0:
        assert (len(key) <= BB/2)
        tmp = key.ljust(BB, b'\x00')
        cocotb.log.debug("key %s", len(tmp))
        await write_data_in(dut, tmp, start, False) 
        start = False

    block_count = math.ceil(len(data)/BB)
    padded_size = block_count * BB
    padded_data = data.ljust(padded_size, b'\x00')
    for i in range(0, block_count):
        if ( i == block_count - 1): 
            last=True
        await write_data_in(dut, padded_data[i*BB:((i+1)*BB)], start, last)
        start = False

# Main test function, writes out configs, key and data, 
# accumulates result and compares it against libhash's
# blake2s result.
async def test_hash(dut, kk, nn, ll, key, data):
    h = hashlib.blake2s(data, digest_size=nn, key=key)
    assert(kk == len(key))
    assert(ll == len(data))
    cocotb.log.info("key [0:%s-1]: 0x%s", kk, key.hex())
    cocotb.log.info("hash[0:%s-1]: 0x%s", nn, h.hexdigest())
    cocotb.log.info("data[0:%s-1]: 0x%s", ll, data.hex())
    await write_config(dut, kk, nn , ll)
    await ClockCycles(dut.clk, 1)
    await send_data_to_hash(dut, key, data)
    cocotb.log.debug("waiting for hash v to rise")
    await RisingEdge(dut.hash_v) 
    # one empty cycle, used for PIO wait instruction
    await ClockCycles(dut.clk, 2)
    res = b''
    while (dut.hash_v.value == 1):
        x = dut.uo_out.value.to_unsigned()
        res = res + bytes([x])
        await ClockCycles(dut.clk, 1)
    cocotb.log.debug("res 0x%s'", res.hex())
    cocotb.log.debug("h   0x%s'", h.hexdigest())
    cocotb.log.debug("%s %s",len(res.hex()),len(h.hexdigest()))
    assert(len(res.hex()) == len(h.hexdigest())) 
    assert(res.hex() == h.hexdigest() ) 

# Generate random configs, keys and input data for testing. 
# Data max size was reduced from theoretical supported
# maximum of 2^64 for testing feasability. 
async def test_random_hash(dut):
    ll = random.randrange(1,2500)
    nn = random.randrange(1,33)
    kk = random.randrange(1,33)
    key = random.randbytes(kk)
    data = random.randbytes(ll)
    await test_hash(dut, kk, nn, ll, key, data)

# Reset sequence
async def rst(dut, ena=1):
    dut.rst_n.value = 0
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start()) #runs the clock "in the background" 
    await ClockCycles(dut.clk, 2)
    # set default io
    dut.uio_in.value = 0
    dut.ena.value = 0
    await ClockCycles(dut.clk, 10)
    await FallingEdge(dut.clk)  
    dut.rst_n.value = 1
    dut.ena.value = ena
    await ClockCycles(dut.clk,10)
    await FallingEdge(dut.clk)



# Check internal signals are not toogling when slice is dissabled
# used to reduce dynamic power usage ( play nice with other designs ).
@cocotb.test()
async def dissable_test(dut):
    await rst(dut, ena=0)
    uo_out = dut.uo_out.value # stable check, doesn't matter if it is X
    c = random.randrange(10, 50)
    for i in range(0, c):
        assert(dut.uo_out.value == uo_out)
        # mask ready
        assert(int(dut.uio_out.value) & 0xF7 == 0)
        await ClockCycles(dut.clk, 1)
   
# blake2 spec - appandix C blake2s test vector
# Collection of predictable test vectors used to debug hash internal 
# states step by step against the C golden model. 
@cocotb.test()
async def hash_spec_test(dut):
    await rst(dut)
    # single block
    await test_hash(dut, 0, 32, 3, b'', b"abc")
    # stream mode, multiblock
    await test_hash(dut, 0, 32, 67, b'', b"abc0000000000000000000000000000000000000000000000000000000000000000")
    # single block with key
    await test_hash(dut, 1, 32, 3, b"a", b"abc")

# Genereating a collection of random {data, key, hash length} pairs 
# and checking the resuling hash against the hashlib blake2s results.
# Number of iteration lowered to 50 in release, regression done on 5k
# sampled.  
@cocotb.test()
async def hash_test(dut):
    await rst(dut)
    await ClockCycles(dut.clk, 2)
    for _ in range(0, 50):
        await test_random_hash(dut)
