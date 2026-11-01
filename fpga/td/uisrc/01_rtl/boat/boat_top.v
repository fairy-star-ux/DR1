module boat_top (
    input  wire       I_sysclk,
    output wire [1:0] O_up_led,
    output wire       fabric_pll_lock,
    output wire       motor_left_pwm,
    output wire       motor_right_pwm,
    output wire       motor_enable
);

    wire clk_sys;
    wire pll_lock;
    wire rst_n;
    reg [25:0] led_blink_count;
    reg        led_blink;

    PLLF9F0D0P0_0 u_PLLF9F0D0P0_0 (
        .refclk   (I_sysclk),
        .reset    (1'b0),
        .clk0_out (clk_sys),
        .lock     (pll_lock)
    );

    assign fabric_pll_lock = pll_lock;

    reset_sync #(
        .HOLD_CYCLES(500_000)
    ) u_reset_sync (
        .clk      (clk_sys),
        .pll_lock (pll_lock),
        .rst_n    (rst_n)
    );

    // This build is for servo observation only; keep all motor controls off.
    assign motor_left_pwm  = 1'b0;
    assign motor_right_pwm = 1'b0;
    assign motor_enable    = 1'b0;

    // LED0 indicates that the servo test image is active.
    assign O_up_led[0] = rst_n;

    // Blink LED1 at about 1 Hz (toggle every 0.5 s at 100 MHz).
    always @(posedge clk_sys) begin
        if (!rst_n) begin
            led_blink_count <= 26'd0;
            led_blink       <= 1'b0;
        end else if (led_blink_count >= 26'd49_999_999) begin
            led_blink_count <= 26'd0;
            led_blink       <= ~led_blink;
        end else begin
            led_blink_count <= led_blink_count + 1'b1;
        end
    end

    assign O_up_led[1] = led_blink;

endmodule
