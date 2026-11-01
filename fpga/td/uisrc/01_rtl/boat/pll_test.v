module pll_test (
    input  wire       I_sysclk,
    output wire [1:0] O_up_led
);

wire       clk0;
wire       pll_lock;
reg [25:0] cnt;

PLLF9F0D0P0_0 u_PLLF9F0D0P0_0 (
    .refclk   (I_sysclk),
    .reset    (1'b0),
    .clk0_out (clk0),
    .lock     (pll_lock)
);

always @(posedge clk0 or negedge pll_lock) begin
    if (!pll_lock)
        cnt <= 26'd0;
    else
        cnt <= cnt + 1'b1;
end

assign O_up_led = cnt[25:24];

endmodule