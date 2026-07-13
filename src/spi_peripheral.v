/*
 * Copyright (c) 2024 Eva Siao
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_peripheral(
    input  wire       clk,      // clock
    input  wire       rst_n,     // reset_n - low to reset

    // SPI inputs
    input wire copi, // Controller Out Peripheral In
    input wire ncs, // Chip Select (active low)
    input wire sclk, // Serial Clock

    // Register outputs
    output  reg [7:0] en_reg_out_7_0,
    output  reg [7:0] en_reg_out_15_8,
    output  reg [7:0] en_reg_pwm_7_0,
    output  reg [7:0] en_reg_pwm_15_8,
    output  reg [7:0] pwm_duty_cycle

);

endmodule
