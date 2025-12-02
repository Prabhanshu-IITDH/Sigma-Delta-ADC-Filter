// fir_comb.v - Vivado-safe version
// FIR compensation filter (direct-form, fixed-point)
// Loads coefficients from "fir_comp.mem"

`timescale 1ns/1ps
module fir_comb1 #(
    parameter integer NTAPS      = 63,
    parameter integer DATA_WIDTH = 32,
    parameter integer COEF_WIDTH = 24,
    parameter integer COEF_FRAC  = 23,
    parameter integer OUT_WIDTH  = 243
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire signed [DATA_WIDTH-1:0]  data_in,
    input  wire                          in_valid,
    output reg  signed [OUT_WIDTH-1:0]   data_out,
    output reg                           out_valid
);

    localparam integer ACC_WIDTH = DATA_WIDTH + COEF_WIDTH + $clog2(NTAPS) + 2;

    // ---------------------------
    // ROM for coefficients
    // ---------------------------
    reg signed [COEF_WIDTH-1:0] coef_mem [0:NTAPS-1];
    integer i;
    initial begin
        $readmemh("fir_comp.mem", coef_mem);

        // if (coef_mem[0] === 'bx || coef_mem[0] === 0) 
        //     $display("ERROR: fir_comp.mem NOT LOADED! Value is: %h", coef_mem[0]);
        // else 
        //     $display("SUCCESS: fir_comp.mem loaded. Value[0]: %h", coef_mem[0]);
        // // ---------------------
    end

    // ---------------------------
    // Shift register for samples
    // ---------------------------
    reg signed [DATA_WIDTH-1:0] taps [0:NTAPS-1];
    integer t;

    // ---------------------------
    // Declare ALL temporary regs at module scope (Vivado requirement)
    // ---------------------------
    reg signed [ACC_WIDTH-1:0] acc;
    reg signed [ACC_WIDTH-1:0] acc_round;
    reg signed [ACC_WIDTH-COEF_FRAC-1:0] acc_shift;
    reg signed [ACC_WIDTH-COEF_FRAC-1:0] max_pos;
    reg signed [ACC_WIDTH-COEF_FRAC-1:0] min_neg;
    reg signed [OUT_WIDTH-1:0] out_sat;

    // ---------------------------
    // Main always block
    // ---------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (t = 0; t < NTAPS; t = t + 1) taps[t] <= 0;
            data_out <= 0;
            out_valid <= 1'b0;

        end else begin

            if (in_valid) begin
                // shift register
                for (t = NTAPS-1; t > 0; t = t - 1)
                    taps[t] <= taps[t-1];
                taps[0] <= data_in;

                // ---------------------------
                // FIR MAC
                // ---------------------------
                acc = 0;
                for (i = 0; i < NTAPS; i = i + 1)
                    acc = acc + taps[i] * coef_mem[i];

                // rounding
                acc_round = acc + (1 <<< (COEF_FRAC-1));

                // remove fractional bits
                acc_shift = acc_round >>> COEF_FRAC;

                // saturation limits
                max_pos = (1 <<< (OUT_WIDTH-1)) - 1;
                min_neg = -(1 <<< (OUT_WIDTH-1));

                // saturate
                if (acc_shift > max_pos)
                    out_sat = max_pos;
                else if (acc_shift < min_neg)
                    out_sat = min_neg;
                else
                    out_sat = acc_shift[OUT_WIDTH-1:0];

                data_out <= out_sat;
                out_valid <= 1;

            end else begin
                out_valid <= 0;
            end

        end
    end

endmodule
