module key_filter #(
    parameter integer DEBOUNCE_CYCLES = 2_000_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire key_n,
    output reg  pressed
);

    reg key_meta;
    reg key_sync;
    reg stable_key;
    reg candidate_key;
    reg [31:0] debounce_count;

    always @(posedge clk) begin
        if (!rst_n) begin
            key_meta       <= 1'b1;
            key_sync       <= 1'b1;
            stable_key     <= 1'b1;
            candidate_key  <= 1'b1;
            debounce_count <= 32'd0;
            pressed        <= 1'b0;
        end else begin
            key_meta <= key_n;
            key_sync <= key_meta;

            if (key_sync != candidate_key) begin
                candidate_key  <= key_sync;
                debounce_count <= 32'd0;
            end else if (debounce_count < DEBOUNCE_CYCLES) begin
                debounce_count <= debounce_count + 1'b1;
            end else begin
                stable_key <= candidate_key;
            end

            pressed <= ~stable_key;
        end
    end

endmodule
