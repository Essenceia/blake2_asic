# Blake2s RTL implementation

Implementation of the Blake2s cryptographic hash function (RFC7693) targetting
tapout on the SKY130A node within a 682 x 225 µm area envelop.
This designed was tapeout out in 2025 as part of the TinyTapout multi wafer program shuttle sky25b.

This is a fully featured Blake2s implementation supporting both block streaming and 
proving the secret key. 

It has been optimized for area usage ahead of an ASIC tapeout, at the 
expense of some performance.  

![asic floorplan](/docs/layout.png)

## Lint

To lint the blake2s hardware design up until the boundaries of the tiny tapeout block: 
```
make lint
```

For linting the FPGA design including the FPGA specific wrapping logic use `lint_fpga`. 

This linting is done independently of any FPGA tooling and requires only `verilator/iverilog`. 
and uses the content of the `lib` as models for the FPGA specific macros such as 
`PLLE_BASE`. 
```
make lint_fpga
```

##### Waiver

By default `verilator` will be using the following waivers for linting, these are provided in `conf/waiver.vlt`. 

```
lint_off -rule UNUSEDSIGNAL -file "*" -match "Signal is not used: 'debug_*"
lint_off -file "lib/*" -match "*
```

##### Switch simulator 

Given it's higher strictness `verilator` is used as the default linter. If you wish to switch you can select `iverilog` using the `SIM` argument : 
```
make lint SIM=iverilog
```

## Testing 

### Simulation 

To run simulations :
```
cd test
make
```
:warning: If you are using cocotb with a python virtual environment make sure if is sourced before running `make`

#### Cocotb 

Given `CVC` is currently the only free-of-charge ( not open source, but free for none commercial applications )
simulator supporting SDF ( Standard Delay Format ), we will be using it for running our testing. 

As such, I will be using `cocotb` to validate this design as it allows to easily 
switch between multiple simulators on the backend and will simplify porting of the
tb to tapeout flows that also used `cocotb`. 

**Note** SVF used for gate-level simulation with timing information.

#### Test vectors 

In order to help debug each step of the blake2s algorithm a more granular insight into the 
values of the intermediary vectors at each step is very handy. 
The test vector `tv` directory contains the `blake2s` implementation, as provided by the original
specification, instrumented with logging of intermediary values. 

To build and run : 
```
make tv
```

### Emulation 

In order to further validate the design, and to most closely resemble an industry grade validation 
process, the design emulated onto an 
FPGA mimicking conditions of the ASIC and connected to an external 
firmware. 

#### FPGA 

For emulating the design, we are using a `basys3` FPGA board because of the
large number of pinnouts provided by it's 4 Pmod connectors and because it
embarks an official Xilinx supported JTAG probe directly on the board. 

The native presence of this probe will make debugging much more convergent as
it will allow us to use the ILA debug cores. 

Scripts are provided to automatically the entire FPGA flow in the `fpga` folder. 
```
cd fpga
```

Create the Vivado project :
```
make setup
```

Run synthesis and PnR :
```
make build
```

Write the bitstream over JTAG to the FPGA ( this doesn't write to the QSPI ):
```
make prog
```

##### Debugging 

Optionally, the flow also includes a debug option that will automatically scan the synthetised
design for all signals with the `mark_debug` property and automatically : 
- create a ILA debug core
- connect all signals marked for debug to it

To invoke this debug mode, call make with the `debug=1` argument : 

```
make build debug=1
```

Or to both build and flash :
```
make prog debug=1
```

See `debug_core.tcl` for more information on this part of the flow.

#### Firmware

For the software part of the emulation we are targeting the RP2040 microcontroller given 
it's PIO hardware allow us to implement support for the custom parallel bus protocols used
to communicate between the firmware and the hardware.

We are using the RaspberryPi PICO board given, again, it's large number of pins, and it's
ease of access ( aka: next day shipping on amazon ). 

Code for this software lives under `firmware`, all future instructions will assume you are
in this folder.

:warning: Building this firmware requires to have a working `gcc` toolchain for the arm M0+
core family and a copy the Raspberry PI PIC SDK. The debugging process will also assume 
you are using gdb, openocd and a jlink probe.

Start by updating the `CMakeLists.txt` sdk include directive to point to your own 
copy of the SDK. 

Generate makefiles from CMakeLists : 
```
make setup
```

Build `.elf` and `.uf2` binaries 
```
make build
```

##### Debugging

For debugging the firmware we are using JLink connected via the SWD interface to the 
PICO board. 
Low level interfacing will be handled by OpenOCD and we will be using GDB for debugging. 

To start OpenOCD and connect to the cores DAP: 
```
make debug
```
If this is successful openOCD will start a GDB server. 
To start a new GDB session connected to this server : 
```
make gdb
```

###### Flash new firmware over gdb

To flash a new version of the firmware using gdb over openocd, first send an indication to 
halt the microcontroller to openocb : 
```
monitor reset halt
```

Then load a new binary, by default `make gdb` will provide the path to the `elf` ( `firmware/artifact/blake2s_asic_firmware.elf` ) when gdb is launched. 
As such, there is no need to respecify the file. 
```
load
```

Then simply resume execution : 
```
c
```

###### Remote GDB server 

This setup doesn't assume the machine connected to the JTAG probe and the machine you will actually doing the debugging
on are the same machines.

In case this is the case of your setup and you are indeed using different machines,
you simply provide the IP address of the machine running your GDB server using the `GDB_SERVER_ADDR=X.X.X.X` when 
starting gdb. 
```
make gdb GDB_SERVER_ADDR=192.168.0.145
```

## Physical implementation 

### Area 

This ASIC was implemented on the SkyWater 130nm A node and was allocated an
area budget with 682.64 x 225.76 µm of die area and a  2.7 x 2.72 679.88 x 223.04 µm core box. 

The final implementation results in the following area allocation with the design elements (buffers, 
clock buffers, inverters, sequential cells, combinational cells) utilising 65.556% of the available area: 


| Cell type                         | Count | Area       |
|-----------------------------------|-------|------------|
| Fill cell                         | 6073  | 30445.45   |
| Tap cell                          | 2158  | 2700.09    |
| Antenna cell                      | 4031  | 10087.17   |
| Buffer                            | 66    | 251.49     |
| Clock buffer                      | 91    | 1238.69    |
| Timing Repair Buffer              | 1892  | 16809.87   |
| Inverter                          | 89    | 380.36     |
| Clock inverter                    | 28    | 341.58     |
| Sequential cell                   | 1657  | 33324.46   |
| Multi-Input combinational cell    | 5638  | 53603.91   |
| **Total**                         | 21723 | 149183.08  |


### Timing 

This design targets a 66MHz ( 15ns per cycle ) internal clock speed with a target operating corner of `nom_tt_025C_1v80`, as you 
can see this gives us a very comfortable `+2.0560 ns` setup slack an `+0.2441 ns` hold slack on our worst corner `max_tt_025C_1v80`.

As initially mentioned, this design is I/O bottlnecked, in parctice this 66MHz target frequency was chosen in accordance with
the maximum supported GPIO input path operating frequency set at 66Mz.  
The bottneck also exists on the output GPIO path, when the output buffer slew rate requires an output target frequency of 33MHz, the 
`slow_output_mode` was added to comphensate for the output paths slower slew rate. 

```
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┓
┃                      ┃ Hold     ┃ Reg to   ┃          ┃          ┃ of which  ┃ Setup    ┃           ┃          ┃           ┃ of which ┃
┃                      ┃ Worst    ┃ Reg      ┃          ┃ Hold Vio ┃ reg to    ┃ Worst    ┃ Reg to    ┃ Setup    ┃ Setup Vio ┃ reg      ┃
┃ Corner/Group         ┃ Slack    ┃ Paths    ┃ Hold TNS ┃ Count    ┃ reg       ┃ Slack    ┃ Reg Paths ┃ TNS      ┃ Count     ┃ reg      ┃
┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━┩
│ Overall              │ 0.0775   │ 0.0775   │ 0.0000   │ 0        │ 0         │ 2.0560   │ 2.0560    │ 0.0000   │ 0         │ 0        │
│ nom_tt_025C_1v80     │ 0.2463   │ 0.2463   │ 0.0000   │ 0        │ 0         │ 2.3932   │ 2.3932    │ 0.0000   │ 0         │ 0        │
│ nom_ff_n40C_1v95     │ 0.0785   │ 0.0785   │ 0.0000   │ 0        │ 0         │ 6.8378   │ 6.8378    │ 0.0000   │ 0         │ 0        │
│ min_tt_025C_1v80     │ 0.2483   │ 0.2483   │ 0.0000   │ 0        │ 0         │ 2.8219   │ 2.8219    │ 0.0000   │ 0         │ 0        │
│ min_ff_n40C_1v95     │ 0.0796   │ 0.0796   │ 0.0000   │ 0        │ 0         │ 7.1220   │ 7.1220    │ 0.0000   │ 0         │ 0        │
│ max_tt_025C_1v80     │ 0.2441   │ 0.2441   │ 0.0000   │ 0        │ 0         │ 2.0560   │ 2.0560    │ 0.0000   │ 0         │ 0        │
│ max_ff_n40C_1v95     │ 0.0775   │ 0.0775   │ 0.0000   │ 0        │ 0         │ 6.6094   │ 6.6094    │ 0.0000   │ 0         │ 0        │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┘
```

### Power 

Power was no a concern in this design, as such, no dynamic power usage analysis where performed. 

#### IR drop

Here is a short summary of the IR drops estimate by openROAD psm's tool, 
reporting only a very minor drop on the `nom_tt_025C_1v80` corner. 

`VPWR`: 

```
Supply voltage   : 1.80e+00 V
Worstcase voltage: 1.80e+00 V
Average voltage  : 1.80e+00 V
Average IR drop  : 1.52e-05 V
Worstcase IR drop: 9.50e-05 V
Percentage drop  : 0.01 %
```

`VGND`:
```
Supply voltage   : 0.00e+00 V
Worstcase voltage: 9.32e-05 V
Average voltage  : 1.63e-05 V
Average IR drop  : 1.63e-05 V
Worstcase IR drop: 9.32e-05 V
Percentage drop  : 0.01 %
```

### Manifacturability 

Due to the size of this design and some of it's longer paths, this design has is know to have the following issues, 
I believe these are minor enoght issues that these are acceptable, should not significantly impact defect rates or 
functionality.

This design has no : 
- DRC violations
  

#### Antenna violations 

Although I belive these to be minor enoght to not cause any concern, due to the size of the desing's occupied area and the length of specific paths 
this hardneing exibits the following minor antenna violations :

```
┏━━━━━━━┳━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━┓
┃ P / R ┃ Partial ┃ Required ┃ Net                                          ┃ Pin                                                                      ┃ Layer ┃
┡━━━━━━━╇━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━┩
│ 1.30  │ 519.81  │ 400.00   │ m_blake2.m_hash256.m_matrix[6\][7\]          │ m_blake2.m_hash256.m_matrix[5\][31\]_sky130_fd_sc_hd__dfxtp_2_Q_D_sky13… │ met3  │
│ 1.27  │ 506.31  │ 400.00   │ m_blake2.m_hash256.block_idx_plus_one_q[51\] │ m_blake2.m_hash256.block_idx_plus_one_q[51\]_sky130_fd_sc_hd__and3_2_B/B │ met1  │
└───────┴─────────┴──────────┴──────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────┴───────┘
```
These paths are quite far from the edge of the block, so if a punch though of the gate oxide does occure, no damage should be done to the neihbouring designs. 

#### Max capactiance violations

This design has two minor max cap violations, neither are on the target corners, are not accompanied with any slew violations are
are small enogth that even though they are on the clk tree I deem them acceptable :  

`max_tt_025C_1v80`: 
```
Pin                                        Limit         Cap       Slack
------------------------------------------------------------------------
clkbuf_0_clk/X                          0.200000    0.203128   -0.003128 (VIOLATED)
```

`max_ff_025C_1v95`:
```
Pin                                        Limit         Cap       Slack
------------------------------------------------------------------------
clkbuf_0_clk/X                          0.200000    0.202537   -0.002537 (VIOLATED)
```

In an ideal world. I would have put a stronger driver, but `clkbuf_0_clk/X` is already the output of a the maxiumum strength clock buffer availble in the PDK, namely 
a `sky130_fd_sc_hd__clkbuf_16`. 

That said, unlike antenna violatoins where most implementation runs will result in a 2 or 3 violations in a ranges of [1:2.7] P/R, these max capactiance violations 
occure only with a subset of implementations, as such, it is quite possible that alternate hardenings might not even encounter any. 

#### Slew rate violations

There are no slew rate violations. 

#### DRC violations

This design has no DRC violations as reported by magic. 

#### 
## Documentation 

- Tiny Tapeout Official site : [https://www.tinytapeout.com/](https://www.tinytapeout.com/)
- Blake2 spec RFC7693 : [docs/rfc7693.md](doc/rfc7693.md)

## Credits

Big thanks to the TinyTapout project contributors, Matt Venn, and all the community working on open source silicon 
tools for making this possible. 
