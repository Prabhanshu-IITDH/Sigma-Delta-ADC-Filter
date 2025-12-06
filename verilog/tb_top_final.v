//==============================================================================
// TESTBENCH
//==============================================================================
module tb_top_final;

    parameter INPUT_WIDTH = 5;
    parameter FIR_OUTPUT_WIDTH = 50;
    parameter CLK_PERIOD = 10;

    reg                          clk;
    reg                          rst_n;
    reg                          in_valid;
    reg signed [INPUT_WIDTH-1:0] in_data;
    wire                         out_valid;
    wire signed [FIR_OUTPUT_WIDTH-1:0] out_data;

    integer input_file;
    integer output_file;
    integer scan_result;
    integer input_sample;
    integer sample_count;
    integer output_count;

    top_final #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .CIC_R(16),
        .CIC_N(15),
        .CIC_M(1),
        .FIR_COEFF_WIDTH(18),
        .FIR_NUM_TAPS(26),
        .FIR_R(2),
        .FIR_OUTPUT_WIDTH(FIR_OUTPUT_WIDTH),
        .HB_COEFF_WIDTH(18),
        .HB_NUM_TAPS(7),
        .HB_OUTPUT_WIDTH(50)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Output Capture
    always @(posedge clk) begin
        if (out_valid) begin
            $fwrite(output_file, "%d\n", out_data);
            output_count = output_count + 1;
        end
    end

    // Main Test
    initial begin
        rst_n = 0;
        in_valid = 0;
        in_data = 0;
        sample_count = 0;
        output_count = 0;

        input_file = $fopen("input_stream5.txt", "r");
        if (input_file == 0) begin
            $display("ERROR: Could not open input_24.5.txt");
            $finish;
        end

        output_file = $fopen("output_filters.txt", "w");
        if (output_file == 0) begin
            $display("ERROR: Could not open output_fir.txt");
            $fclose(input_file);
            $finish;
        end

        $display("========================================");
        $display("Starting CIC + FIR + 2xHalfband Decimation Test");
        $display("========================================");

        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        while (!$feof(input_file)) begin
            scan_result = $fscanf(input_file, "%d\n", input_sample);
            
            if (scan_result == 1) begin
                @(posedge clk);
                #1;
                in_valid = 1;
                in_data = input_sample;
                sample_count = sample_count + 1;
                
            end
        end

        @(posedge clk);
        #1;
        in_valid = 0;

        $display("========================================");
        $display("Waiting for pipeline to flush...");
        repeat(100) @(posedge clk);

        $fclose(input_file);
        $fclose(output_file);

        $display("========================================");
        $display("Test Complete!");
        $display("Total input samples: %0d", sample_count);
        $display("Total output samples: %0d", output_count);
        $display("Expected decimation: 128 (16*2*2*2)");
        $display("Actual decimation: %0f", sample_count / (output_count * 1.0));
        $display("Output written to: output_fir.txt");
        $display("========================================");

        $finish;
    end

    initial begin
        #(CLK_PERIOD * 1000000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    initial begin
        $dumpfile("decimation_chain.vcd");
        $dumpvars(0, tb_top_final);
    end

endmodule
