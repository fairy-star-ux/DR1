module servo_scan #(
    parameter integer CLK_HZ     = 100_000_000,
    parameter integer STEP_MS     = 20,
    parameter integer ANGLE_MIN   = 30,
    parameter integer ANGLE_MAX   = 150,
    parameter integer ANGLE_STEP  = 2
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg [8:0] angle_deg
);

    localparam integer STEP_CYCLES = (CLK_HZ / 1000) * STEP_MS;

    reg [31:0] step_count;
    reg        increasing;

    always @(posedge clk) begin
        if (!rst_n) begin
            step_count <= 32'd0;
            angle_deg  <= 9'd90;
            increasing <= 1'b1;
        end else if (step_count < STEP_CYCLES - 1) begin
            step_count <= step_count + 1'b1;
        end else begin
            step_count <= 32'd0;

            if (increasing) begin
                if (angle_deg + ANGLE_STEP >= ANGLE_MAX) begin
                    angle_deg  <= ANGLE_MAX;
                    increasing <= 1'b0;
                end else begin
                    angle_deg <= angle_deg + ANGLE_STEP;
                end
            end else begin
                if (angle_deg <= ANGLE_MIN + ANGLE_STEP) begin
                    angle_deg  <= ANGLE_MIN;
                    increasing <= 1'b1;
                end else begin
                    angle_deg <= angle_deg - ANGLE_STEP;
                end
            end
        end
    end

endmodule
