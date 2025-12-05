//==============================================================================
// CIC Decimation Filter
// Parameters from MATLAB: R=8, N=15 stages, M=1
// Input: 5-bit signed data at 128 kHz
// Output: Decimated data at 16 kHz
//==============================================================================

module cic_filter #(
    parameter INPUT_WIDTH  = 5,           // Input data width (signed)
    parameter R            = 8,           // Decimation factor
    parameter N            = 15,          // Number of stages
    parameter M            = 1,           // Differential delay
    // Calculated parameters
    // Output bit growth = N * log2(R*M) = 15 * log2(8) = 15 * 3 = 45 bits
    // Total width = INPUT_WIDTH + bit_growth = 5 + 45 = 50 bits
    parameter INTERNAL_WIDTH = INPUT_WIDTH + N * $clog2(R*M)  // 50 bits
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          in_valid,
    input  wire signed [INPUT_WIDTH-1:0] in_data,
    output reg                           out_valid,
    output reg  signed [INTERNAL_WIDTH-1:0] out_data
);

    // Internal signals for integrator stages
    reg signed [INTERNAL_WIDTH-1:0] integrator [0:N-1];
    
    // Internal signals for comb stages (after decimation)
    reg signed [INTERNAL_WIDTH-1:0] comb [0:N-1];
    reg signed [INTERNAL_WIDTH-1:0] comb_delay [0:N-1];
    
    // Decimation counter
    reg [$clog2(R)-1:0] decim_counter;
    
    // Decimated sample
    reg signed [INTERNAL_WIDTH-1:0] decimated_sample;
    reg decimated_valid;
    
    // Sign-extended input
    wire signed [INTERNAL_WIDTH-1:0] in_data_ext;
    assign in_data_ext = {{(INTERNAL_WIDTH-INPUT_WIDTH){in_data[INPUT_WIDTH-1]}}, in_data};
    
    integer i;
    
    //--------------------------------------------------------------------------
    // Integrator Section (runs at input sample rate)
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < N; i = i + 1) begin
                integrator[i] <= 0;
            end
            decim_counter <= 0;
            decimated_sample <= 0;
            decimated_valid <= 0;
        end else if (in_valid) begin
            // First integrator stage
            integrator[0] <= integrator[0] + in_data_ext;
            
            // Subsequent integrator stages
            for (i = 1; i < N; i = i + 1) begin
                integrator[i] <= integrator[i] + integrator[i-1];
            end
            
            // Decimation counter
            if (decim_counter == R - 1) begin
                decim_counter <= 0;
                decimated_sample <= integrator[N-1];
                decimated_valid <= 1;
            end else begin
                decim_counter <= decim_counter + 1;
                decimated_valid <= 0;
            end
        end else begin
            decimated_valid <= 0;
        end
    end
    
    //--------------------------------------------------------------------------
    // Comb Section (runs at decimated sample rate)
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < N; i = i + 1) begin
                comb[i] <= 0;
                comb_delay[i] <= 0;
            end
            out_valid <= 0;
            out_data <= 0;
        end else if (decimated_valid) begin
            // First comb stage
            comb[0] <= decimated_sample - comb_delay[0];
            comb_delay[0] <= decimated_sample;
            
            // Subsequent comb stages
            for (i = 1; i < N; i = i + 1) begin
                comb[i] <= comb[i-1] - comb_delay[i];
                comb_delay[i] <= comb[i-1];
            end
            
            out_data <= comb[N-1];
            out_valid <= 1;
        end else begin
            out_valid <= 0;
        end
    end

endmodule
