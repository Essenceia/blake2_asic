# Blake2s RTL implementation

Implementation of the Blake2s cryptographic hash function (RFC7693)targeting
tapout on the SKY130A node.

It is a fully featured Blake2s implementation supporting both block streaming and using a secret key, with a maximum hash rate of 41.42 MB/s and a target operating frequency of 66 MHz.

**The full documentation on this accelerator can be found:** [here](docs/info.md)

![asic floorplan](/docs/layout.png)

## ASIC 

This accelerator was designed for the SKY130A node, for a target operating frequency of 66.66 MHz 
and a typical operating volate of 3.3V at 25°C.

It occupies 682 x 225 µm area envelop, making it one of the largest Tiny Tapeout blocks, with a staggering
22% of the total area dedicated to flip-flops, mainly for 
storing the hash intermediary values. 

There are currently no major manufacturing issues, with only the following minor antenna violations of P/R: 2.65, 1.26, 1.02.

Current status: **Taped-in**, in fabrication, part of the Tiny Tapeout `sky25b` shuttle. 

## Verification 

This design was verified using both simulation and emulation. 

### Simulation 

This design was initally verified through RTL simulation using a Cocotb-based testbench running Iverilog alongside an instrumented golden model (see `/tv`) for debugging intermediate states. Gate-level simulation with SDF timing back-annotation was performed using the CVC simulator. 
Linting was done with Verilator, with waivers documented in `conf/waiver.vlt`.

### Emulation

The design was emulated on a Basys3 FPGA connected to an RP2040 (Raspberry Pi Pico) to co-bringup both the custom firmware and hardware. 
The FPGA build flow includes automated insertion and connection of Xilinx ILA debug cores to signals marked for debug. 
Firmware was debugged using OpenOCD + GDB with remote server support.

## Using this codebase 

For getting started with using this codebase, documentation on the build flows can be found: [here](usage.md)

## License 

This project is licensed under the Apache License 2.0, see the [LICENSE](LICENSE.md) file for details.

## Credits

Thanks to the Tiny Tapeout project, its contributors, and all the community working on open source silicon tools for making this possible.

## Future improvements

Although I currently have no plans of building a newer version of this accelerator, here are the 
improvements I would make if I were to iterate on this version : 
- Add a JTAG TAP to help probe the accelerator internals and debug accelerator usage.
- DFT: a scan chain throughout all the logic and generate a test vector to help identify manufacturing defects. 
- Use SRAM macros to help reduce area usage ( there where no proven SRAM macros as of the inital implementation ). 

