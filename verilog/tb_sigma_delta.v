//==============================================================================
// Testbench for Multi-Stage Decimation Filter
// Reads 5-bit signed input from input_stream5.txt
// Writes output to output_stream.txt
//==============================================================================

`timescale 1ns / 1ps

module tb_sigma_delta;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter INPUT_WIDTH    = 5;
    parameter OUTPUT_WIDTH   = 32;
    parameter CLK_PERIOD     = 7812.5;    // 128 kHz clock period in ns (1/128000 * 1e9)
    
    //--------------------------------------------------------------------------
    // Signals
    //--------------------------------------------------------------------------
    reg                          clk;
    reg                          rst_n;
    reg                          in_valid;
    reg signed [INPUT_WIDTH-1:0] in_data;
    wire                         out_valid;
    wire signed [OUTPUT_WIDTH-1:0] out_data;
    
    //--------------------------------------------------------------------------
    // File handles
    //--------------------------------------------------------------------------
    integer input_file;
    integer output_file;
    integer scan_result;
    integer sample_count;
    integer output_count;
    reg signed [31:0] read_value;
    
    //--------------------------------------------------------------------------
    // DUT Instantiation
    //--------------------------------------------------------------------------
    decimation_filter_top #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data)
    );
    
    //--------------------------------------------------------------------------
    // Clock Generation (128 kHz)
    //--------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //--------------------------------------------------------------------------
    // Output Capture
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (out_valid) begin
            $fwrite(output_file, "%d\n", out_data);
            output_count = output_count + 1;
            if (output_count % 100 == 0) begin
                $display("Output samples written: %d", output_count);
            end
        end
    end
    
    //--------------------------------------------------------------------------
    // Main Test Sequence
    //--------------------------------------------------------------------------
    initial begin
        // Initialize signals
        rst_n = 0;
        in_valid = 0;
        in_data = 0;
        sample_count = 0;
        output_count = 0;
        
        // Open input file
        input_file = $fopen("input_stream5.txt", "r");
        if (input_file == 0) begin
            $display("ERROR: Cannot open input_stream5.txt");
            $finish;
        end
        
        // Open output file
        output_file = $fopen("output_stream.txt", "w");
        if (output_file == 0) begin
            $display("ERROR: Cannot open output_stream.txt for writing");
            $finish;
        end
        
        $display("=== Decimation Filter Testbench ===");
        $display("Starting simulation...");
        
        // Reset sequence
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        // Read and process input samples
        while (!$feof(input_file)) begin
            scan_result = $fscanf(input_file, "%d\n", read_value);
            if (scan_result == 1) begin
                @(posedge clk);
                in_valid = 1;
                in_data = read_value[INPUT_WIDTH-1:0];
                sample_count = sample_count + 1;
                
                if (sample_count % 1000 == 0) begin
                    $display("Input samples processed: %d", sample_count);
                end
            end
        end
        
        // Deassert valid and wait for pipeline to flush
        @(posedge clk);
        in_valid = 0;
        in_data = 0;
        
        // Wait for remaining outputs (enough time for pipeline flush)
        // Pipeline depth consideration: CIC + FIR + HB1 + HB2 processing time
        #(CLK_PERIOD * 1000);
        
        // Close files
        $fclose(input_file);
        $fclose(output_file);
        
        // Display results
        $display("");
        $display("=== Simulation Complete ===");
        $display("Total input samples: %d", sample_count);
        $display("Total output samples: %d", output_count);
        $display("Decimation ratio: %d", sample_count / output_count);
        $display("Output written to: output_stream.txt");
        
        $finish;
    end
    
    //--------------------------------------------------------------------------
    // Timeout watchdog
    //--------------------------------------------------------------------------
    initial begin
        #(CLK_PERIOD * 20000000);  // Adjust based on expected simulation time
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
