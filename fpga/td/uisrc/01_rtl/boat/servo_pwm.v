module servo_pwm #(
    parameter integer CLK_HZ = 100_000_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire [8:0] angle_deg,
    output reg        pwm
);

    localparam integer FRAME_CYCLES = CLK_HZ / 50;
    localparam integer MIN_PULSE    = CLK_HZ / 2000;
    reg [31:0] frame_count;
    reg [8:0]  angle_latched;
    reg [31:0] high_cycles;

    // Approximately 2 ms of travel over 180 degrees.
    localparam integer STEP_PULSE = ((CLK_HZ / 1000) * 2) / 180;

    always @(posedge clk) begin
        if (!rst_n) begin
            frame_count <= 32'd0;
            angle_latched <= 9'd90;
            high_cycles <= MIN_PULSE + (90 * STEP_PULSE);
            pwm         <= 1'b0;
        end else begin
            // The angle changes slowly, so update the pulse register one
            // degree per clock instead of synthesizing a multiplier/divider.
            if (angle_deg > angle_latched) begin
                angle_latched <= angle_latched + 1'b1;
                high_cycles   <= high_cycles + STEP_PULSE;
            end else if (angle_deg < angle_latched) begin
                angle_latched <= angle_latched - 1'b1;
                high_cycles   <= high_cycles - STEP_PULSE;
            end

            if (frame_count >= FRAME_CYCLES - 1) begin
                frame_count <= 32'd0;
                pwm         <= enable;
            end else begin
                frame_count <= frame_count + 1'b1;

                if (!enable) begin
                    pwm <= 1'b0;
                end else if (frame_count >= high_cycles - 1) begin
                    pwm <= 1'b0;
                end
            end
        end
    end

endmodule
