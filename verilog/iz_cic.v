module iz_cic (
    input wire clk,
    input wire rst,
    input wire signed [4:0] data_in,
    input wire data_valid,
    output reg signed [49:0] data_out,
    output reg out_valid
);

    // Parameters
    parameter DECIMATION = 8;
    parameter ORDER = 15;
    
    // Bit growth calculation: ORDER * log2(DECIMATION) = 15 * 3 = 45 bits
    // With 5-bit input: 5 + 45 = 50 bits required
    
    // Integrator registers (15 stages)
    reg signed [49:0] integrator [0:14];
    
    // Comb registers (15 stages) 
    reg signed [49:0] comb [0:14];
    reg signed [49:0] comb_delay [0:14];
    
    // Decimation counter
    reg [3:0] dec_counter;
    
    // Internal signals
    wire sample_tick;
    integer i;
    
    assign sample_tick = (dec_counter == DECIMATION - 1);
    
    // Integrator section (runs at input rate)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < ORDER; i = i + 1) begin
                integrator[i] <= 50'd0;
            end
        end else if (data_valid) begin
            // First integrator stage
            integrator[0] <= integrator[0] + {{45{data_in[4]}}, data_in};
            
            // Remaining integrator stages
            for (i = 1; i < ORDER; i = i + 1) begin
                integrator[i] <= integrator[i] + integrator[i-1];
            end
        end
    end
    
    // Decimation counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dec_counter <= 4'd0;
        end else if (data_valid) begin
            if (sample_tick) begin
                dec_counter <= 4'd0;
            end else begin
                dec_counter <= dec_counter + 1'b1;
            end
        end
    end
    
    // Comb section (runs at decimated rate) with differential delay = 1
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < ORDER; i = i + 1) begin
                comb[i] <= 50'd0;
                comb_delay[i] <= 50'd0;
            end
            data_out <= 50'd0;
            out_valid <= 1'b0;
        end else if (data_valid && sample_tick) begin
            // First comb stage
            comb[0] <= integrator[ORDER-1] - comb_delay[0];
            comb_delay[0] <= integrator[ORDER-1];
            
            // Remaining comb stages
            for (i = 1; i < ORDER; i = i + 1) begin
                comb[i] <= comb[i-1] - comb_delay[i];
                comb_delay[i] <= comb[i-1];
            end
            
            // Output
            data_out <= comb[ORDER-1];
            out_valid <= 1'b1;
        end else begin
            out_valid <= 1'b0;
        end
    end

endmodule
