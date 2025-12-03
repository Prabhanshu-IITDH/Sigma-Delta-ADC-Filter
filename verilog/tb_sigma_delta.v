//Top Testbench
`timescale 1ns/1ps

module tb_sigma_delta;

    // 1. Inputs and Outputs for the DUT
    reg clk;
    reg rst_n;
    reg data_in;
    reg data_valid;
    wire signed [23:0] pcm_out; // 24-bit output
    wire out_valid;

    // 2. Parameters (Must match sigma_delta_top.v)
    localparam CLK_PERIOD = 10; // 100 MHz clock
    localparam SIM_SAMPLES = 4194304; // Number of input bits to simulate

    // 3. Instantiate the Device Under Test (DUT)
    sigma_delta_top u_top (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_valid(data_valid),
        .pcm_out(pcm_out),
        .out_valid(out_valid)
    );

    // 4. File Handlers
    integer infile, outfile, code, i;
    reg [0:0] mem_in [0:SIM_SAMPLES-1]; // Array to hold input file

    // 5. Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- ADD THIS BLOCK FOR WAVEFORMS ---
    // initial begin
    //     $dumpfile("waveform.vcd"); // Create the waveform file
    //     $dumpvars(0, tb_sigma_delta); // Dump all variables in this testbench
    // end

    // 6. Main Stimulus Process
    initial begin
        // Open files
        // NOTE: You must generate this file in MATLAB first!
        // It should contain one '0' or '1' per line.
        $readmemb("input_stream.txt", mem_in); 
        
        // --- DEBUG: CHECK IF FILE LOADED ---
        // if (mem_in[0] === 1'bx) begin
        //     $display("CRITICAL ERROR: input_stream.txt NOT LOADED! mem_in[0] is X");
        //     $finish;
        // end else begin
        //     $display("SUCCESS: Input file loaded. Bit 0 = %b", mem_in[0]);
        // end
        // -----------------------------------

        outfile = $fopen("output_capture.txt", "w");

        // Initialize
        rst_n = 0;
        data_in = 0;
        data_valid = 0;
        
        // Reset Pulse
        #100;
        rst_n = 1;
        #100;

        // Drive Data
        $display("Starting Simulation...");
        
        for (i = 0; i < SIM_SAMPLES; i = i + 1) begin
            @(posedge clk);
            data_in <= mem_in[i]; 
            data_valid <= 1'b1; // Pulse valid every clock (for simple testing)
        end
        
        @(posedge clk);
        data_valid <= 0;
        
        // Wait for pipeline to drain
        #5000; 
        
        $display("Simulation Complete. Output written to output_capture.txt");
        $fclose(outfile);
        $finish;
    end

    // 7. Capture Output Process
    always @(posedge clk) begin
        if (out_valid) begin
            // Write signed decimal to file for easy MATLAB reading
            $fdisplay(outfile, "%d", pcm_out); 
        end
    end

endmodule
