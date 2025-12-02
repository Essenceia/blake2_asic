# Blake2s RTL implementation

Implementation of the Blake2s cryptographic hash function (RFC7693)targetting
tapout on the SKY130A node.

It is a fully featured Blake2s implementation supporting both block streaming and using a secret key, with a maximum hash rate of 41.42 MB/s and a target operating frequency of 66 MHz.

The full documentation on using this accelerator can be found: [here](docs/info.md)

![asic floorplan](/docs/layout.png)

## ASIC 

This accelerator was designed for the SKY130A node, for a target operating frequency of 66.66 MHz 
an a typical operating volate of 3.3V at 25°C.

It occupies 682 x 225 µm an area envelop, making it one of the larget tiny tapeout blocks, with a staggering
22% of the total area dedicated to flip-flops, mainly for 
storing the hash intermediary values. 

There are currently no major manifacturing issues, with only the following minor antenna violations of P/R: 2.65, 1.26, 1.02.

Current status: **Taped-in**, in fabrication, part of the tiny-tapeout `sky25b` shuttle. 

## Using this codebase 

For getting started with using this codebase, documentation on the build flows can found: [here](usage.md)

## License 

This project is licensed under the Apache License 2.0, see the [LICENSE](LICENSE.md) file for details.

## Credits

Thanks to the Tiny Tapeout project, its contributors, and all the community working on open source silicon tools for making this possible.

## Future implovements

Although I currently have no plans of building a newer version of this accelerator, here are the 
improvements I would make if I was to improve on this version : 
- Add a JTAG TAP to help probe the accelerator internals and debug accelerator usage.
- DFT: a scan chain thoughout all the logic and generate a test vector to help identify manifacturing defects. 
- Use SRAM macros to help reduce area usage ( there where no proven SRAM macros as of the inital implementation ). 

