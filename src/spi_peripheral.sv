/*
 * Copyright (c) 2024 Eva Siao
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_peripheral(
    input  logic       clk,      // clock
    input  logic       rst_n,     // reset_n - low to reset

    // SPI inputs
    input logic copi, // Controller Out Peripheral In
    input logic ncs, // Chip Select (active low)
    input logic sclk, // Serial Clock

    // Register outputs
    output  logic [7:0] en_reg_out_7_0,
    output  logic [7:0] en_reg_out_15_8,
    output  logic [7:0] en_reg_pwm_7_0,
    output  logic [7:0] en_reg_pwm_15_8,
    output  logic [7:0] pwm_duty_cycle

);

    // 2 stage synchronizer for the SPI signals to avoid metastability
    logic copi_sync_0, copi_sync_1;
    logic ncs_sync_0, ncs_sync_1;
    logic sclk_sync_0, sclk_sync_1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            copi_sync_0 <= 1'b0;
            copi_sync_1 <= 1'b0;
            ncs_sync_0 <= 1'b1; // inactive high
            ncs_sync_1 <= 1'b1; // inactive high
            sclk_sync_0 <= 1'b0;
            sclk_sync_1 <= 1'b0;
        end else begin
            copi_sync_0 <= copi;
            copi_sync_1 <= copi_sync_0;
            ncs_sync_0 <= ncs;
            ncs_sync_1 <= ncs_sync_0;
            sclk_sync_0 <= sclk;
            sclk_sync_1 <= sclk_sync_0;
        end
    end

    // Edge detection for sclk and posedge detection for ncs
    logic sclk_sync_prev;
    logic ncs_sync_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync_prev <= 1'b0;
            ncs_sync_prev <= 1'b1; // inactive high
        end else begin
            sclk_sync_prev <= sclk_sync_1;
            ncs_sync_prev <= ncs_sync_1;
        end
    end
    logic sclk_posedge;
    assign sclk_posedge = sclk_sync_1 & ~sclk_sync_prev;

    logic ncs_posedge; // Detect rising edge of ncs (chip select) (end transaction)
    assign ncs_posedge = ncs_sync_1 & ~ncs_sync_prev;

    //Bit counter for 16 total bits
    logic [4:0] bit_count; // count from 0 to 16
    logic [15:0] shift_reg; // 16-bit shift register
    

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 5'd0;
            shift_reg <= 16'd0;
        end else if (ncs_posedge) begin // Reset on ncs rising edge (when chip select goes inactive)
            bit_count <= 5'd0;
        end else if (sclk_posedge && !ncs_sync_1) begin // Only shift on sclk posedge when ncs is low
    

            shift_reg <= {shift_reg[14:0], copi_sync_1}; // Shift in the new bit
            if (bit_count < 5'd16) begin
                bit_count <= bit_count + 5'd1;
            end
        end
    end


    // Address Validation: Only allow writes to addresses 0x00 to 0x04
    localparam logic [6:0] MAX_ADDRESS = 7'h04;

    // Transaction finalization 
    logic transaction_ready; // Flag to indicate a complete transaction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transaction_ready <= 1'b0;
        end else if (ncs_posedge && bit_count == 5'd16) begin // Transaction complete
            transaction_ready <= 1'b1; 
        end else begin
            transaction_ready <= 1'b0; 
        end
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_reg_out_7_0 <= 8'd0;
            en_reg_out_15_8 <= 8'd0;
            en_reg_pwm_7_0 <= 8'd0; 
            en_reg_pwm_15_8 <= 8'd0;
            pwm_duty_cycle <= 8'd0;
        end else if (shift_reg[15] == 1'b1 && shift_reg[14:8] <= MAX_ADDRESS && transaction_ready == 1'b1) begin // Write if write bit 1, destination addr less than max, transaction ready
            case (shift_reg[14:8]) 
                7'h0: en_reg_out_7_0 <= shift_reg[7:0];
                7'h1: en_reg_out_15_8 <= shift_reg[7:0];
                7'h2: en_reg_pwm_7_0 <= shift_reg[7:0];
                7'h3: en_reg_pwm_15_8 <= shift_reg[7:0];
                7'h4: pwm_duty_cycle <= shift_reg[7:0];
                default: ;
            endcase
        end
    end
endmodule
