//==============================================================================
// FIR Compensation Filter with Decimation (PARALLEL VERSION)
// Parameters from MATLAB: 26 taps (order 25), R=2
// Compensates for CIC droop
// Coefficients loaded from external .mem file
//==============================================================================

module fir_comb1 #(
    parameter INPUT_WIDTH  = 50,          // Input data width (from CIC)
    parameter COEFF_WIDTH  = 18,          // Coefficient width
    parameter NUM_TAPS     = 26,          // Number of filter taps (order + 1)
    parameter R            = 2,           // Decimation factor
    parameter OUTPUT_WIDTH = 50           // Output data width
)(
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           in_valid,
    input  wire signed [INPUT_WIDTH-1:0]  in_data,
    output reg                            out_valid,
    output reg  signed [OUTPUT_WIDTH-1:0] out_data
);

    // Accumulator width: INPUT_WIDTH + COEFF_WIDTH + log2(NUM_TAPS)
    localparam ACC_WIDTH = INPUT_WIDTH + COEFF_WIDTH + $clog2(NUM_TAPS);
    
    // Coefficient memory
    reg signed [COEFF_WIDTH-1:0] coeffs [0:NUM_TAPS-1];
    
    // Delay line for input samples
    reg signed [INPUT_WIDTH-1:0] delay_line [0:NUM_TAPS-1];
    
    // Decimation counter
    reg [$clog2(R)-1:0] decim_counter;
    
    integer i;

    // Load coefficients from memory file
    initial begin
        $readmemh("fir_coeffs.mem", coeffs);
    end

    //--------------------------------------------------------------------------
    // Parallel Multiplication & Summation
    //--------------------------------------------------------------------------
    // We compute the sum of products purely combinationaly (or you could pipeline this)
    reg signed [ACC_WIDTH-1:0] sum_of_products;
    integer k;
    
    always @(*) begin
        sum_of_products = 0;
        for (k = 0; k < NUM_TAPS; k = k + 1) begin
            sum_of_products = sum_of_products + (delay_line[k] * coeffs[k]);
        end
    end

    //--------------------------------------------------------------------------
    // FIR Logic
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_TAPS; i = i + 1) begin
                delay_line[i] <= 0;
            end
            decim_counter <= 0;
            out_valid <= 0;
            out_data <= 0;
        end else begin
            out_valid <= 0; // Default

            if (in_valid) begin
                // 1. Shift Delay Line (Always happens when input is valid)
                delay_line[0] <= in_data;
                for (i = 1; i < NUM_TAPS; i = i + 1) begin
                    delay_line[i] <= delay_line[i-1];
                end

                // 2. Handle Decimation
                if (decim_counter == R - 1) begin
                    decim_counter <= 0;
                    
                    // 3. Register the parallel result
                    // Note: This result is based on the delay line state BEFORE the shift above
                    // because non-blocking assignments (<=) resolve at end of cycle.
                    // Ideally, standard FIR equation uses current inputs. 
                    // For R=2, slight timing shift is usually acceptable, 
                    // but to be precise with the previous serial logic:
                    // The serial logic latched input, THEN computed.
                    // Here, we calculate based on the *current* delay line values + new input.
                    
                    // Optimization: We can just register the combinatorial sum calculated above
                    // The 'sum_of_products' typically uses the values *currently* in delay_line.
                    // On the clock edge, we capture that sum.
                    out_data <= sum_of_products[ACC_WIDTH-1 -: OUTPUT_WIDTH];
                    out_valid <= 1;
                end else begin
                    decim_counter <= decim_counter + 1;
                end
            end
        end
    end

endmodule
