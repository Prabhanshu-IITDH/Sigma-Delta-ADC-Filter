//==============================================================================
// Top Module: Multi-Stage Decimation Filter
// Total Decimation: 64 (8 x 2 x 2 x 2)
// 
// Stage 1: CIC Filter (R=8, N=15 stages)
// Stage 2: FIR Compensation Filter (R=2, 26 taps)
// Stage 3: Half-Band Filter 1 (R=2, order 6)
// Stage 4: Half-Band Filter 2 (R=2, order 6)
//
// Input: 5-bit signed @ 128 kHz
// Output: Decimated stream @ 2 kHz
//==============================================================================

module decimation_filter_top #(
    parameter INPUT_WIDTH    = 5,         // Input: 5-bit signed
    parameter CIC_STAGES     = 15,        // CIC: 15 stages
    parameter CIC_R          = 8,         // CIC decimation factor
    parameter FIR_TAPS       = 26,        // FIR: 26 taps
    parameter FIR_R          = 2,         // FIR decimation factor
    parameter HB_ORDER       = 6,         // Half-band order
    parameter HB_TAPS        = 7,         // Half-band taps (order + 1)
    parameter COEFF_WIDTH    = 18,        // Coefficient bit width
    parameter OUTPUT_WIDTH   = 32         // Final output width
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          in_valid,
    input  wire signed [INPUT_WIDTH-1:0] in_data,
    output wire                          out_valid,
    output wire signed [OUTPUT_WIDTH-1:0] out_data
);

    //--------------------------------------------------------------------------
    // Internal width calculations
    // CIC bit growth = N * log2(R*M) = 15 * 3 = 45
    // CIC output width = 5 + 45 = 50 bits
    //--------------------------------------------------------------------------
    localparam CIC_OUTPUT_WIDTH = INPUT_WIDTH + CIC_STAGES * $clog2(CIC_R);
    localparam FIR_OUTPUT_WIDTH = CIC_OUTPUT_WIDTH;
    localparam HB1_OUTPUT_WIDTH = FIR_OUTPUT_WIDTH;
    localparam HB2_OUTPUT_WIDTH = HB1_OUTPUT_WIDTH;
    
    //--------------------------------------------------------------------------
    // Inter-stage connections
    //--------------------------------------------------------------------------
    // CIC output
    wire                              cic_valid;
    wire signed [CIC_OUTPUT_WIDTH-1:0] cic_data;
    
    // FIR output
    wire                              fir_valid;
    wire signed [FIR_OUTPUT_WIDTH-1:0] fir_data;
    
    // HB1 output
    wire                              hb1_valid;
    wire signed [HB1_OUTPUT_WIDTH-1:0] hb1_data;
    
    // HB2 output
    wire                              hb2_valid;
    wire signed [HB2_OUTPUT_WIDTH-1:0] hb2_data;
    
    //--------------------------------------------------------------------------
    // Stage 1: CIC Decimation Filter (R=8)
    //--------------------------------------------------------------------------
    cic_filter #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .R(CIC_R),
        .N(CIC_STAGES),
        .M(1)
    ) u_cic (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(cic_valid),
        .out_data(cic_data)
    );
    
    //--------------------------------------------------------------------------
    // Stage 2: FIR Compensation Filter (R=2)
    //--------------------------------------------------------------------------
    fir_filter #(
        .INPUT_WIDTH(CIC_OUTPUT_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .NUM_TAPS(FIR_TAPS),
        .R(FIR_R),
        .OUTPUT_WIDTH(FIR_OUTPUT_WIDTH)
    ) u_fir (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(cic_valid),
        .in_data(cic_data),
        .out_valid(fir_valid),
        .out_data(fir_data)
    );
    
    //--------------------------------------------------------------------------
    // Stage 3: Half-Band Filter 1 (R=2)
    //--------------------------------------------------------------------------
    halfband_filter #(
        .INPUT_WIDTH(FIR_OUTPUT_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .NUM_TAPS(HB_TAPS),
        .OUTPUT_WIDTH(HB1_OUTPUT_WIDTH),
        .COEFF_FILE("hb1_coeffs.mem")
    ) u_hb1 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(fir_valid),
        .in_data(fir_data),
        .out_valid(hb1_valid),
        .out_data(hb1_data)
    );
    
    //--------------------------------------------------------------------------
    // Stage 4: Half-Band Filter 2 (R=2)
    //--------------------------------------------------------------------------
    halfband_filter #(
        .INPUT_WIDTH(HB1_OUTPUT_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .NUM_TAPS(HB_TAPS),
        .OUTPUT_WIDTH(HB2_OUTPUT_WIDTH),
        .COEFF_FILE("hb2_coeffs.mem")
    ) u_hb2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(hb1_valid),
        .in_data(hb1_data),
        .out_valid(hb2_valid),
        .out_data(hb2_data)
    );
    
    //--------------------------------------------------------------------------
    // Output assignment with bit truncation to final output width
    //--------------------------------------------------------------------------
    assign out_valid = hb2_valid;
    assign out_data = hb2_data[HB2_OUTPUT_WIDTH-1 -: OUTPUT_WIDTH];

endmodule
