module reset_sync #(
    parameter integer HOLD_CYCLES = 500_000
) (
    input  wire clk,
    input  wire pll_lock,
    output reg  rst_n
);

    reg [31:0] hold_count;

    always @(posedge clk) begin
        if (!pll_lock) begin
            hold_count <= 32'd0;
            rst_n      <= 1'b0;
        end else if (hold_count < HOLD_CYCLES) begin
            hold_count <= hold_count + 1'b1;
            rst_n      <= 1'b0;
        end else begin
            rst_n      <= 1'b1;
        end
    end

endmodule
