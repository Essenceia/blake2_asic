/*
 * plle2_adv.v: Simulates the PLLE2_ADV pll of the xilinx 7 series. This is
 * just a wrapper around the actual logic found in pll.v
 * author: Till Mahlburg
 * year: 2020
 * organization: Universität Leipzig
 * license: ISC
 *
 */

`timescale 1 ns / 1 ps

/* A reference for the interface can be found in Xilinx UG953 page 503ff */
module PLLE2_ADV #(
	/* not implemented */
	parameter BANDWIDTH 			= "OPTIMIZED",

	parameter CLKFBOUT_MULT 		= 5,
	parameter CLKFBOUT_PHASE 		= 0.0,

	/* are ignored, but need to be set */
	parameter CLKIN1_PERIOD			= 0.0,
	parameter CLKIN2_PERIOD			= 0.0,

	parameter CLKOUT0_DIVIDE		= 1,
	parameter CLKOUT1_DIVIDE		= 1,
	parameter CLKOUT2_DIVIDE		= 1,
	parameter CLKOUT3_DIVIDE		= 1,
	parameter CLKOUT4_DIVIDE		= 1,
	parameter CLKOUT5_DIVIDE		= 1,

	parameter CLKOUT0_DUTY_CYCLE	= 0.5,
	parameter CLKOUT1_DUTY_CYCLE	= 0.5,
	parameter CLKOUT2_DUTY_CYCLE	= 0.5,
	parameter CLKOUT3_DUTY_CYCLE	= 0.5,
	parameter CLKOUT4_DUTY_CYCLE	= 0.5,
	parameter CLKOUT5_DUTY_CYCLE	= 0.5,

	parameter CLKOUT0_PHASE			= 0.0,
	parameter CLKOUT1_PHASE			= 0.0,
	parameter CLKOUT2_PHASE			= 0.0,
	parameter CLKOUT3_PHASE			= 0.0,
	parameter CLKOUT4_PHASE			= 0.0,
	parameter CLKOUT5_PHASE			= 0.0,

	parameter DIVCLK_DIVIDE			= 1,

	/* not implemented */
	parameter REF_JITTER1			= 0.010,
	parameter REF_JITTER2			= 0.010,
	parameter STARTUP_WAIT			= "FALSE",
	parameter COMPENSATION			= "ZHOLD",

	/* Setting the FPGA model and speed grade allows a more realistic
	 * simulation. Default values are the most restrictive */
	parameter FPGA_TYPE				= "ARTIX",
	parameter SPEED_GRADE 			= "-1")(
	output 	CLKOUT0,
	output 	CLKOUT1,
	output 	CLKOUT2,
	output 	CLKOUT3,
	output 	CLKOUT4,
	output 	CLKOUT5,
	/* PLL feedback output. */
	output 	CLKFBOUT,

	output	LOCKED,

	input 	CLKIN1,
	input 	CLKIN2,
	/* Select input clk. 1 for CLKIN1, 0 for CLKIN2 */
	input 	CLKINSEL,
	/* PLL feedback input. Is ignored in this implementation, but should be connected to CLKFBOUT for internal feedback. */
	input 	CLKFBIN,

	/* Used to power down instatiated but unused PLLs */
	input	PWRDWN,
	input	RST,

	/* Dynamic reconfiguration ports */
	/* Address to write/read reconfiguration data to/from */
	input 	[6:0] DADDR,
	/* CLK to drive the reconfiguration */
	input 	DCLK,
	/* ENable the reconfiguration functionality */
	input 	DEN,
	/* Enable Write access on the given address */
	input	DWE,
	/* What to write in the given ADDR */
	input 	[15:0] DI,

	/* Content of the given address */
	output	[15:0] DO,
	/* Tells you, when the reconfiguration is done and ready for new inputs */
	output	DRDY);

	pll #(
 		.BANDWIDTH(BANDWIDTH),
 		.CLKFBOUT_MULT_F(CLKFBOUT_MULT),
		.CLKFBOUT_PHASE(CLKFBOUT_PHASE),
		.CLKIN1_PERIOD(CLKIN1_PERIOD),
		.CLKIN2_PERIOD(CLKIN2_PERIOD),

		.CLKOUT0_DIVIDE_F(CLKOUT0_DIVIDE),
		.CLKOUT1_DIVIDE(CLKOUT1_DIVIDE),
		.CLKOUT2_DIVIDE(CLKOUT2_DIVIDE),
		.CLKOUT3_DIVIDE(CLKOUT3_DIVIDE),
		.CLKOUT4_DIVIDE(CLKOUT4_DIVIDE),
		.CLKOUT5_DIVIDE(CLKOUT5_DIVIDE),

		.CLKOUT0_DUTY_CYCLE(CLKOUT0_DUTY_CYCLE),
		.CLKOUT1_DUTY_CYCLE(CLKOUT1_DUTY_CYCLE),
		.CLKOUT2_DUTY_CYCLE(CLKOUT2_DUTY_CYCLE),
		.CLKOUT3_DUTY_CYCLE(CLKOUT3_DUTY_CYCLE),
		.CLKOUT4_DUTY_CYCLE(CLKOUT4_DUTY_CYCLE),
		.CLKOUT5_DUTY_CYCLE(CLKOUT5_DUTY_CYCLE),

		.CLKOUT0_PHASE(CLKOUT0_PHASE),
		.CLKOUT1_PHASE(CLKOUT1_PHASE),
		.CLKOUT2_PHASE(CLKOUT2_PHASE),
		.CLKOUT3_PHASE(CLKOUT3_PHASE),
		.CLKOUT4_PHASE(CLKOUT4_PHASE),
		.CLKOUT5_PHASE(CLKOUT5_PHASE),

		.DIVCLK_DIVIDE(DIVCLK_DIVIDE),
		.REF_JITTER1(REF_JITTER1),
		.REF_JITTER2(REF_JITTER2),
		.STARTUP_WAIT(STARTUP_WAIT),
		.COMPENSATION(COMPENSATION),

		.MODULE_TYPE("PLLE2_ADV"),

		.FPGA_TYPE(FPGA_TYPE),
		.SPEED_GRADE(SPEED_GRADE))
	plle2_adv (
		.CLKOUT0(CLKOUT0),
		.CLKOUT1(CLKOUT1),
		.CLKOUT2(CLKOUT2),
		.CLKOUT3(CLKOUT3),
		.CLKOUT4(CLKOUT4),
		.CLKOUT5(CLKOUT5),

		.CLKFBOUT(CLKFBOUT),
		.LOCKED(LOCKED),

		.CLKIN1(CLKIN1),
		.CLKIN2(CLKIN2),
		.CLKINSEL(CLKINSEL),

		.PWRDWN(PWRDWN),
		.RST(RST),
		.CLKFBIN(CLKFBIN),

		.DADDR(DADDR),
		.DCLK(DCLK),
		.DEN(DEN),
		.DWE(DWE),
		.DI(DI),

		.DO(DO),
		.DRDY(DRDY)
	);

endmodule
