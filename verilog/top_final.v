//==============================================================================
// TOP MODULE: CIC + FIR + 2x Halfband Decimation Chain
// Overall decimation: R_total = R_cic * R_fir * R_hb1 * R_hb2 = 16 * 2 * 2 * 2 = 128
// Input: 128 kHz -> CIC: 8 kHz -> FIR: 4 kHz -> HB1: 2 kHz -> HB2: 1 kHz
//==============================================================================
module top_final #(
    parameter INPUT_WIDTH = 5,
    parameter CIC_R = 16,
    parameter CIC_N = 15,
    parameter CIC_M = 1,
    parameter CIC_OUTPUT_WIDTH = INPUT_WIDTH + CIC_N * $clog2(CIC_R * CIC_M),
    parameter FIR_COEFF_WIDTH = 18,
    parameter FIR_NUM_TAPS = 26,
    parameter FIR_R = 2,
    parameter FIR_OUTPUT_WIDTH = 50,
    parameter HB_COEFF_WIDTH = 18,
    parameter HB_NUM_TAPS = 7,
    parameter HB_OUTPUT_WIDTH = 50
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          in_valid,
    input  wire signed [INPUT_WIDTH-1:0] in_data,
    output wire                          out_valid,
    output wire signed [HB_OUTPUT_WIDTH-1:0] out_data
);

    // Interconnect signals
    wire cic_out_valid;
    wire signed [CIC_OUTPUT_WIDTH-1:0] cic_out_data;
    
    wire fir_out_valid;
    wire signed [FIR_OUTPUT_WIDTH-1:0] fir_out_data;
    
    wire hb1_out_valid;
    wire signed [HB_OUTPUT_WIDTH-1:0] hb1_out_data;

    //--------------------------------------------------------------------------
    // CIC Decimation Filter Instance (16x decimation)
    //--------------------------------------------------------------------------
    cic_filter #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .R(CIC_R),
        .N(CIC_N),
        .M(CIC_M),
        .INTERNAL_WIDTH(CIC_OUTPUT_WIDTH)
    ) u_cic (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(cic_out_valid),
        .out_data(cic_out_data)
    );

    //--------------------------------------------------------------------------
    // FIR Compensation Filter Instance (2x decimation)
    //--------------------------------------------------------------------------
    fir_filter #(
        .INPUT_WIDTH(CIC_OUTPUT_WIDTH),
        .COEFF_WIDTH(FIR_COEFF_WIDTH),
        .NUM_TAPS(FIR_NUM_TAPS),
        .R(FIR_R),
        .OUTPUT_WIDTH(FIR_OUTPUT_WIDTH)
    ) u_fir (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(cic_out_valid),
        .in_data(cic_out_data),
        .out_valid(fir_out_valid),
        .out_data(fir_out_data)
    );

    //--------------------------------------------------------------------------
    // First Halfband Filter Instance (2x decimation)
    //--------------------------------------------------------------------------
    halfband_filter #(
        .INPUT_WIDTH(FIR_OUTPUT_WIDTH),
        .COEFF_WIDTH(HB_COEFF_WIDTH),
        .NUM_TAPS(HB_NUM_TAPS),
        .OUTPUT_WIDTH(HB_OUTPUT_WIDTH),
        .COEFF_FILE("hb1_coeffs.mem")
    ) u_hb1 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(fir_out_valid),
        .in_data(fir_out_data),
        .out_valid(hb1_out_valid),
        .out_data(hb1_out_data)
    );

    //--------------------------------------------------------------------------
    // Second Halfband Filter Instance (2x decimation)
    //--------------------------------------------------------------------------
    halfband_filter #(
        .INPUT_WIDTH(HB_OUTPUT_WIDTH),
        .COEFF_WIDTH(HB_COEFF_WIDTH),
        .NUM_TAPS(HB_NUM_TAPS),
        .OUTPUT_WIDTH(HB_OUTPUT_WIDTH),
        .COEFF_FILE("hb2_coeffs.mem")  // Using same coefficients
    ) u_hb2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(hb1_out_valid),
        .in_data(hb1_out_data),
        .out_valid(out_valid),
        .out_data(out_data)
    );

endmodule
