import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import logging
import math 
import hashlib
import random 

BB=64


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
    
async def generate_clock(dut):
    while(1):
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")

# dissable data transfert for "cycles" cycles
async def invalid_data(dut, cycles):
    for i in range(0, cycles):
        dut.uio_in.value = 0
        await Timer(2, unit="ns")

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
        await Timer(2, unit="ns")
    dut.uio_in.value = 0

async def write_data_in(dut, block=b'', start=False, last=False):
    assert(len(block) == BB )
    cocotb.log.debug("block %s", block)
    dut.uio_in.value = 0
    cocotb.log.debug("ready %s",dut.m_io.ready_v_o)
    if(int(dut.m_io.ready_v_o.value) == 0):
        await RisingEdge(dut.m_io.ready_v_o)
    await FallingEdge(dut.clk)
    assert(int(dut.m_io.ready_v_o.value) == 1)
 
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
        await Timer(2, unit="ns")
    dut.uio_in.value = 0

# lengths are in bytes
async def send_data_to_hash(dut, key=b'', data=b''):
    cocotb.log.info("write_data key(%s) data(%s)", len(key), len(data))
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

async def test_hash(dut, kk, nn, ll, key, data):
    h = hashlib.blake2s(data, digest_size=nn, key=key)
    assert(kk == len(key))
    assert(ll == len(data))
    cocotb.log.info("data[0:%s-1]: 0x%s", ll, data.hex())
    cocotb.log.info("key [0:%s-1]: 0x%s", kk, key.hex())
    cocotb.log.info("hash[0:%s-1]: 0x%s", nn, h.hexdigest())
    await write_config(dut, kk, nn , ll)
    await Timer(2, unit="ns")
    await send_data_to_hash(dut, key, data)
    cocotb.log.debug("waiting for hash v to rise")
    await RisingEdge(dut.m_io.hash_v_o) 
    await FallingEdge(dut.clk) 
    # one empty cycle, used for PIO wait instruction
    await Timer(2, unit="ns")
    res = b''
    while (dut.m_io.hash_v_o.value == 1):
        x = dut.uo_out.value.to_unsigned()
        res = res + bytes([x])
        await Timer(2, unit="ns")
    cocotb.log.info("res 0x%s'", res.hex())
    cocotb.log.debug("%s %s",len(res.hex()),len(h.hexdigest()))
    assert(len(res.hex()) == len(h.hexdigest())) 
    assert(res.hex() == h.hexdigest() ) 

async def test_random_hash(dut):
    ll = random.randrange(1,2500)
    nn = random.randrange(1,33)
    kk = random.randrange(1,33)
    key = random.randbytes(kk)
    data = random.randbytes(ll)
    await test_hash(dut, kk, nn, ll, key, data)

async def rst(dut, ena=1):
    dut.rst_n.value = 0
    cocotb.start_soon(generate_clock(dut))  # run the clock "in the background" 
    await Timer(4, unit="ns")
    # set default io
    dut.uio_in.value = 0
    dut.ena.value = 0
    await Timer(random.randrange(1,10), unit="ns")
    await FallingEdge(dut.clk)  
    dut.rst_n.value = 1
    dut.ena.value = ena
    await Timer(random.randrange(1,10), unit="ns")
    await FallingEdge(dut.clk)



# check internal signals are not toogling when slice is dissabled
# used to reduce dynamic power usage
@cocotb.test()
async def dissable_test(dut):
    await rst(dut, ena=0)
    uo_out = dut.uo_out.value # stable check, doesn't matter if it is X
    # c = random.randrange(10, 50)
    c = 10
    for i in range(0, c):
        assert(dut.uo_out.value == uo_out)
        # mask ready
        assert(int(dut.uio_out.value) & 0xF7 == 0)
        Timer(2, unit="ns")
   
# blake2 spec, appandix C blake2s test vector
@cocotb.test()
async def hash_spec_test(dut):
    await rst(dut)
    # single block
    await test_hash(dut, 0, 32, 3, b'', b"abc")
    # stream mode, multiblock
    await test_hash(dut, 0, 32, 67, b'', b"abc0000000000000000000000000000000000000000000000000000000000000000")
    # single block with key
    await test_hash(dut, 1, 32, 3, b"a", b"abc")

@cocotb.test()
async def hash_test(dut):
    await rst(dut)
    await Timer(4, unit="ns")
    for _ in range(0, 50):
        await test_random_hash(dut)
