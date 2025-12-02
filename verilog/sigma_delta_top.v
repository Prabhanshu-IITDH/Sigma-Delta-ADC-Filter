// sigma_delta_top.v
// Top-level connecting iz_cic -> fir_comb -> halfband_poly
`timescale 1ns/1ps
module sigma_delta_top #(
    // CIC params
    parameter integer CIC_ORDER = 3,
    parameter integer CIC_R     = 64,
    parameter integer CIC_M     = 1,
    // FIR comp params
    parameter integer FIR_NTAPS     = 63,
    parameter integer FIR_DATA_W    = 32,
    parameter integer FIR_COEF_W    = 24,
    parameter integer FIR_COEF_FRAC = 23,
    parameter integer FIR_OUT_W     = 24,
    // Half-band params
    parameter integer HB_TAPS       = 31,
    parameter integer HB_DATA_W     = 24,
    parameter integer HB_COEF_W     = 24,
    parameter integer HB_COEF_FRAC  = 23,
    parameter integer OUT_WIDTH     = 24
)(
    input  wire clk,
    input  wire rst_n,
    input  wire data_in,      // 1-bit sigma-delta stream
    input  wire data_valid,   // pulse at input sampling rate
    output wire signed [OUT_WIDTH-1:0] pcm_out,
    output wire out_valid
);

    // compute CIC output width (match iz_cic internal formula)
    localparam integer CIC_GROWTH = CIC_ORDER * $clog2(CIC_R);
    localparam integer CIC_IN_EXT = 2;
    localparam integer CIC_OUTW    = CIC_IN_EXT + CIC_GROWTH + 2;

    // wires between modules
    wire signed [CIC_OUTW-1:0] cic_out_data;
    wire cic_out_valid;

    // Instantiate CIC (make sure iz_cic.v is in project)
    iz_cic #(
        .ORDER(CIC_ORDER),
        .R(CIC_R),
        .M(CIC_M),
        .IN_WIDTH(1),
        .SAFETY(2)
    ) u_cic (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_valid(data_valid),
        .cic_out_data(cic_out_data),
        .cic_out_valid(cic_out_valid)
    );

    // FIR compensation wires
    wire signed [FIR_OUT_W-1:0] fir_out_data;
    wire fir_out_valid;

    // FIR compensation instance (loads fir_comp.mem)
    fir_comb1 #(
        .NTAPS(FIR_NTAPS),
        .DATA_WIDTH(CIC_OUTW),
        .COEF_WIDTH(FIR_COEF_W),
        .COEF_FRAC(FIR_COEF_FRAC),
        .OUT_WIDTH(FIR_OUT_W)
    ) u_fir (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(cic_out_data),
        .in_valid(cic_out_valid),
        .data_out(fir_out_data),
        .out_valid(fir_out_valid)
    );

    // Half-band instance
    halfband_poly #(
        .HB_TAPS(HB_TAPS),
        .DATA_WIDTH(FIR_OUT_W),
        .COEF_WIDTH(HB_COEF_W),
        .COEF_FRAC(HB_COEF_FRAC),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_hb (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(fir_out_data),
        .in_valid(fir_out_valid),
        .data_out(pcm_out),
        .out_valid(out_valid)
    );

endmodule
