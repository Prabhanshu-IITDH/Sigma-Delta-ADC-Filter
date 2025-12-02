// iz_cic.v
// Parameterized Integrator-Comb (CIC) decimator
// Input: 1-bit sigma-delta bitstream (data_in), data_valid pulses at input rate
// Output: signed multi-bit samples (cic_out_data) with cic_out_valid pulses at decimated rate

`timescale 1ns/1ps
module iz_cic #(
    parameter integer ORDER = 3,       // number of integrator/comb stages
    parameter integer R = 64,          // decimation factor
    parameter integer M = 1,           // differential delay (usually 1)
    parameter integer IN_WIDTH = 1,    // input width (1 for sigma-delta)
    parameter integer SAFETY = 2       // safety margin bits
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  data_in,       // 1-bit bitstream (0 or 1)
    input  wire                  data_valid,    // pulse at input sampling rate
    output reg signed [OUT_WIDTH-1:0] cic_out_data, // signed output (see localparam)
    output reg                  cic_out_valid
);

    // compute bit growth
    localparam integer GROWTH = ORDER * $clog2(R);
    localparam integer IN_EXT = (IN_WIDTH==1) ? 2 : IN_WIDTH; // we'll map 1-bit to signed +/-1
    localparam integer INT_WIDTH = IN_EXT + GROWTH + SAFETY; // width for integrators/combs
    // expose OUT_WIDTH for external modules
    localparam integer OUT_WIDTH = INT_WIDTH; // you may choose to truncate later

    // Input mapping: map 1 -> +1, 0 -> -1 (signed)
    wire signed [IN_EXT-1:0] sd_signed;
    generate
        if (IN_WIDTH == 1) begin
            // represent +1 or -1 with IN_EXT bits
            assign sd_signed = data_in ? $signed({{(IN_EXT-1){1'b0}},1'b1}) 
                                       : $signed({{(IN_EXT-1){1'b1}},1'b1}); // -1
        end else begin
            assign sd_signed = $signed(data_in);
        end
    endgenerate

    // Integrators (operate at input rate)
    reg signed [INT_WIDTH-1:0] integ [0:ORDER-1];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0;i<ORDER;i=i+1) integ[i] <= 0;
        end else begin
            if (data_valid) begin
                // first integrator adds input
                integ[0] <= integ[0] + {{(INT_WIDTH-IN_EXT){sd_signed[IN_EXT-1]}}, sd_signed};
                for (i=1;i<ORDER;i=i+1) begin
                    integ[i] <= integ[i] + integ[i-1];
                end
            end
        end
    end

    // decimation counter
    reg [$clog2(R)-1:0] decim_cnt;
    wire decim_pulse = (decim_cnt == R-1);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) decim_cnt <= 0;
        else if (data_valid) begin
            if (decim_cnt == R-1) decim_cnt <= 0;
            else decim_cnt <= decim_cnt + 1;
        end
    end

    // comb stages (operate at output rate, update on decim_pulse)
    // Use shift-register to implement M delay (M typically = 1)
    reg signed [INT_WIDTH-1:0] comb_delay [0:ORDER-1][0:M];
    reg signed [INT_WIDTH-1:0] comb_in [0:ORDER-1];
    integer j, k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j=0;j<ORDER;j=j+1) begin
                comb_in[j] <= 0;
                for (k=0;k<=M;k=k+1) comb_delay[j][k] <= 0;
            end
            cic_out_data <= 0;
            cic_out_valid <= 1'b0;
        end else begin
            cic_out_valid <= 1'b0;
            if (data_valid && decim_pulse) begin
                // First comb stage input comes from last integrator
                comb_in[0] <= integ[ORDER-1];
                
                // Process all comb stages
                for (j=0;j<ORDER;j=j+1) begin
                    // Shift delay line
                    for (k=M;k>0;k=k-1) begin
                        comb_delay[j][k] <= comb_delay[j][k-1];
                    end
                    // Store current input to delay line
                    comb_delay[j][0] <= comb_in[j];
                    
                    // Compute difference (comb operation)
                    if (j < ORDER-1) begin
                        // Feed to next stage
                        comb_in[j+1] <= comb_in[j] - comb_delay[j][M];
                    end else begin
                        // Final stage output
                        cic_out_data <= comb_in[j] - comb_delay[j][M];
                    end
                end
                
                cic_out_valid <= 1'b1;
            end
        end
    end

endmodule