module motor_pwm_dual #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer PWM_HZ = 20_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        run,
    input  wire        obstacle,
    input  wire [13:0] duty_left,
    input  wire [13:0] duty_right,
    output reg         pwm_left,
    output reg         pwm_right,
    output wire        enable
);

    localparam integer PWM_PERIOD = CLK_HZ / PWM_HZ;
    reg [15:0] pwm_count;

    assign enable = run && !obstacle;

    always @(posedge clk) begin
        if (!rst_n) begin
            pwm_count <= 16'd0;
            pwm_left  <= 1'b0;
            pwm_right <= 1'b0;
        end else begin
            if (pwm_count >= PWM_PERIOD - 1) begin
                pwm_count <= 16'd0;
            end else begin
                pwm_count <= pwm_count + 1'b1;
            end

            pwm_left  <= enable && (pwm_count < duty_left);
            pwm_right <= enable && (pwm_count < duty_right);
        end
    end

endmodule
