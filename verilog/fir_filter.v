module fir_filter #(
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

    // Debug file
    integer debug_f;
    initial begin
        debug_f = $fopen("debug_fir.txt", "w");
        if (!debug_f) begin
            $display("ERROR: Could not open debug_fir.txt");
            $finish;
        end
    end

    // Load FIR coefficients
    initial begin
        $readmemh("fir_coeffs.mem", coeffs);
    end

    //----------------------------------------------------------------------
    // Parallel Multiplication & Summation (Combinational)
    //----------------------------------------------------------------------
    reg signed [ACC_WIDTH-1:0] sum_of_products;
    integer k;

    always @(*) begin
        sum_of_products = 0;
        for (k = 0; k < NUM_TAPS; k = k + 1) begin
            sum_of_products = sum_of_products + (delay_line[k] * coeffs[k]);
        end
    end

    //----------------------------------------------------------------------
    // FIR Core Logic
    //----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_TAPS; i = i + 1) begin
                delay_line[i] <= 0;
            end
            decim_counter <= 0;
            out_valid <= 0;
            out_data <= 0;
        end else begin
            out_valid <= 0;

            if (in_valid) begin

                //--------------------------------------------------------------
                // 1. Shift Delay Line
                //--------------------------------------------------------------
                delay_line[0] <= in_data;
                for (i = 1; i < NUM_TAPS; i = i + 1) begin
                    delay_line[i] <= delay_line[i-1];
                end

                //--------------------------------------------------------------
                // DEBUG: Dump delay_line values to debug_fir.txt
                //--------------------------------------------------------------
                $fwrite(debug_f, "Time %0t : delay_line = ", $time);
                for (i = 0; i < NUM_TAPS; i = i + 1) begin
                    $fwrite(debug_f, "%0d ", delay_line[i]);
                end
                $fwrite(debug_f, "\n");

                //--------------------------------------------------------------
                // 2. Decimation logic
                //--------------------------------------------------------------
                if (decim_counter == R - 1) begin
                    decim_counter <= 0;

                    // Take MSBs of accumulator
                    out_data <= sum_of_products[ACC_WIDTH-1 -: OUTPUT_WIDTH];
                    out_valid <= 1;
                end else begin
                    decim_counter <= decim_counter + 1;
                end
            end
        end
    end

endmodule
