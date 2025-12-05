//==============================================================================
// Half-Band Decimation Filter
// Parameters from MATLAB: order 6, R=2
// Half-band filters have symmetric coefficients with every other coefficient = 0
// Coefficients loaded from external .mem file
//==============================================================================

module halfband_filter #(
    parameter INPUT_WIDTH  = 50,          // Input data width
    parameter COEFF_WIDTH  = 18,          // Coefficient width
    parameter NUM_TAPS     = 7,           // Number of filter taps (order + 1)
    parameter OUTPUT_WIDTH = 50,          // Output data width
    parameter COEFF_FILE   = "hb1_coeffs.mem"  // Coefficient file name
)(
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           in_valid,
    input  wire signed [INPUT_WIDTH-1:0]  in_data,
    output reg                            out_valid,
    output reg  signed [OUTPUT_WIDTH-1:0] out_data
);

    // Decimation factor is always 2 for half-band
    localparam R = 2;
    
    // Accumulator width: INPUT_WIDTH + COEFF_WIDTH + log2(NUM_TAPS)
    localparam ACC_WIDTH = INPUT_WIDTH + COEFF_WIDTH + $clog2(NUM_TAPS);
    
    // Coefficient memory
    reg signed [COEFF_WIDTH-1:0] coeffs [0:NUM_TAPS-1];
    
    // Delay line for input samples
    reg signed [INPUT_WIDTH-1:0] delay_line [0:NUM_TAPS-1];
    
    // Decimation counter
    reg decim_counter;
    
    // Accumulator
    reg signed [ACC_WIDTH-1:0] acc;
    
    // Processing state machine
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam OUTPUT = 2'd2;
    
    reg [$clog2(NUM_TAPS):0] tap_counter;
    
    integer i;
    
    // Load coefficients from memory file
    initial begin
        $readmemh(COEFF_FILE, coeffs);
    end
    
    //--------------------------------------------------------------------------
    // Half-Band Filter with Decimation by 2
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_TAPS; i = i + 1) begin
                delay_line[i] <= 0;
            end
            decim_counter <= 0;
            acc <= 0;
            out_valid <= 0;
            out_data <= 0;
            state <= IDLE;
            tap_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 0;
                    if (in_valid) begin
                        // Shift delay line
                        for (i = NUM_TAPS-1; i > 0; i = i - 1) begin
                            delay_line[i] <= delay_line[i-1];
                        end
                        delay_line[0] <= in_data;
                        
                        // Check decimation (output every other sample)
                        if (decim_counter == 1) begin
                            decim_counter <= 0;
                            acc <= 0;
                            tap_counter <= 0;
                            state <= COMPUTE;
                        end else begin
                            decim_counter <= 1;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (tap_counter < NUM_TAPS) begin
                        // Half-band optimization: skip zero coefficients
                        // In half-band filters, every other coefficient (except center) is 0
                        acc <= acc + delay_line[tap_counter] * coeffs[tap_counter];
                        tap_counter <= tap_counter + 1;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    // Scale output
                    out_data <= acc[ACC_WIDTH-1 -: OUTPUT_WIDTH];
                    out_valid <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
