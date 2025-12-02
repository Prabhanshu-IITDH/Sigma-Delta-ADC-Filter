// halfband_poly.v
// Polyphase Half-Band FIR (decimate-by-2)
// FIXED FOR VIVADO (no in-block declarations)

`timescale 1ns/1ps
module halfband_poly #(
    parameter integer HB_TAPS   = 31,    // odd
    parameter integer DATA_WIDTH= 24,
    parameter integer COEF_WIDTH= 24,
    parameter integer COEF_FRAC = 23,
    parameter integer OUT_WIDTH = 24
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire signed [DATA_WIDTH-1:0]  data_in,
    input  wire                          in_valid,
    output reg signed [OUT_WIDTH-1:0]    data_out,
    output reg                           out_valid
);

    // L = (HB_TAPS-1)/2
    localparam integer L = (HB_TAPS - 1) / 2;
    localparam integer ACC_WIDTH = DATA_WIDTH + COEF_WIDTH + $clog2(L+2) + 2;

    // Coefficients (ROM)
    reg signed [COEF_WIDTH-1:0] coef_H0 [0:L];
    reg signed [COEF_WIDTH-1:0] coef_H1 [0:L-1];

    // Shift buffer
    reg signed [DATA_WIDTH-1:0] shiftbuf [0:HB_TAPS-1];

    // Phase toggle for decimation-by-2
    reg phase;

    // Declare all accumulator & temporary variables here (NOT inside always blocks)
    integer s, k;
    reg signed [ACC_WIDTH-1:0] acc0;
    reg signed [ACC_WIDTH-1:0] acc1;
    reg signed [ACC_WIDTH-1:0] acc_tot;
    reg signed [ACC_WIDTH-1:0] acc_r;
    reg signed [ACC_WIDTH-COEF_FRAC-1:0] acc_sh;
    reg signed [ACC_WIDTH-COEF_FRAC-1:0] max_pos;
    reg signed [ACC_WIDTH-COEF_FRAC-1:0] min_neg;
    reg signed [OUT_WIDTH-1:0] out_sat;

    initial begin
        $readmemh("hb_h0.mem", coef_H0);
        $readmemh("hb_h1.mem", coef_H1);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 0;
            data_out <= 0;
            out_valid <= 0;

            for (s = 0; s < HB_TAPS; s = s + 1)
                shiftbuf[s] <= 0;

        end else begin
            out_valid <= 0;

            if (in_valid) begin
                // Shift buffer
                for (s = HB_TAPS-1; s > 0; s = s - 1)
                    shiftbuf[s] <= shiftbuf[s-1];
                shiftbuf[0] <= data_in;

                // Toggle phase each input
                phase <= ~phase;

                if (phase) begin
                    // reset accumulators
                    acc0 = 0;
                    acc1 = 0;

                    // Even-phase polyphase branch
                    for (k = 0; k <= L; k = k + 1) begin
                        acc0 = acc0 + shiftbuf[2*k] * coef_H0[k];
                        if (k < L)
                            acc1 = acc1 + shiftbuf[2*k+1] * coef_H1[k];
                    end

                    // combine
                    acc_tot = acc0 + acc1;

                    // rounding
                    acc_r = acc_tot + (1 <<< (COEF_FRAC-1));

                    // shift back
                    acc_sh = acc_r >>> COEF_FRAC;

                    // saturation
                    max_pos = (1 <<< (OUT_WIDTH-1)) - 1;
                    min_neg = -(1 <<< (OUT_WIDTH-1));

                    if (acc_sh > max_pos)
                        out_sat = max_pos;
                    else if (acc_sh < min_neg)
                        out_sat = min_neg;
                    else
                        out_sat = acc_sh[OUT_WIDTH-1:0];

                    data_out <= out_sat;
                    out_valid <= 1;
                end
            end
        end
    end

endmodule
