module system_top (
    input  wire       I_sysclk,
    output wire [1:0] O_up_led,
    output wire       ultrasonic_servo_pwm,
    output wire       camera_pan_servo_pwm,
    output wire       camera_tilt_servo_pwm,
    output wire       motor_left_pwm,
    output wire       motor_right_pwm,
    output wire       motor_enable
);
    wire fabric_pll_lock;
    wire axi_resetn;
    wire  gp0_arready;
    wire  gp0_awready;
    wire [11:0] gp0_bid;
    wire [1:0] gp0_bresp;
    wire  gp0_bvalid;
    wire [31:0] gp0_rdata;
    wire [11:0] gp0_rid;
    wire  gp0_rlast;
    wire [1:0] gp0_rresp;
    wire  gp0_rvalid;
    wire  gp0_wready;
    wire p2f_clk0;
    wire [32:0] gp0_araddr;
    wire [1:0] gp0_arburst;
    wire [3:0] gp0_arcache;
    wire [11:0] gp0_arid;
    wire [3:0] gp0_arlen;
    wire  gp0_arlock;
    wire [2:0] gp0_arprot;
    wire [1:0] gp0_arsize;
    wire  gp0_arvalid;
    wire [32:0] gp0_awaddr;
    wire [1:0] gp0_awburst;
    wire [3:0] gp0_awcache;
    wire [11:0] gp0_awid;
    wire [3:0] gp0_awlen;
    wire  gp0_awlock;
    wire [2:0] gp0_awprot;
    wire [1:0] gp0_awsize;
    wire  gp0_awvalid;
    wire  gp0_bready;
    wire  gp0_rready;
    wire [31:0] gp0_wdata;
    wire  gp0_wlast;
    wire [3:0] gp0_wstrb;
    wire  gp0_wvalid;

    system system_i (
        .M_AXI_GP0_master_gp0_axi_arready(gp0_arready),
        .M_AXI_GP0_master_gp0_axi_awready(gp0_awready),
        .M_AXI_GP0_master_gp0_axi_bid(gp0_bid),
        .M_AXI_GP0_master_gp0_axi_bresp(gp0_bresp),
        .M_AXI_GP0_master_gp0_axi_bvalid(gp0_bvalid),
        .M_AXI_GP0_master_gp0_axi_rdata(gp0_rdata),
        .M_AXI_GP0_master_gp0_axi_rid(gp0_rid),
        .M_AXI_GP0_master_gp0_axi_rlast(gp0_rlast),
        .M_AXI_GP0_master_gp0_axi_rresp(gp0_rresp),
        .M_AXI_GP0_master_gp0_axi_rvalid(gp0_rvalid),
        .M_AXI_GP0_master_gp0_axi_wready(gp0_wready),
        .p2f_clk0(p2f_clk0),
        .M_AXI_GP0_master_gp0_axi_araddr(gp0_araddr),
        .M_AXI_GP0_master_gp0_axi_arburst(gp0_arburst),
        .M_AXI_GP0_master_gp0_axi_arcache(gp0_arcache),
        .M_AXI_GP0_master_gp0_axi_arid(gp0_arid),
        .M_AXI_GP0_master_gp0_axi_arlen(gp0_arlen),
        .M_AXI_GP0_master_gp0_axi_arlock(gp0_arlock),
        .M_AXI_GP0_master_gp0_axi_arprot(gp0_arprot),
        .M_AXI_GP0_master_gp0_axi_arsize(gp0_arsize),
        .M_AXI_GP0_master_gp0_axi_arvalid(gp0_arvalid),
        .M_AXI_GP0_master_gp0_axi_awaddr(gp0_awaddr),
        .M_AXI_GP0_master_gp0_axi_awburst(gp0_awburst),
        .M_AXI_GP0_master_gp0_axi_awcache(gp0_awcache),
        .M_AXI_GP0_master_gp0_axi_awid(gp0_awid),
        .M_AXI_GP0_master_gp0_axi_awlen(gp0_awlen),
        .M_AXI_GP0_master_gp0_axi_awlock(gp0_awlock),
        .M_AXI_GP0_master_gp0_axi_awprot(gp0_awprot),
        .M_AXI_GP0_master_gp0_axi_awsize(gp0_awsize),
        .M_AXI_GP0_master_gp0_axi_awvalid(gp0_awvalid),
        .M_AXI_GP0_master_gp0_axi_bready(gp0_bready),
        .M_AXI_GP0_master_gp0_axi_rready(gp0_rready),
        .M_AXI_GP0_master_gp0_axi_wdata(gp0_wdata),
        .M_AXI_GP0_master_gp0_axi_wlast(gp0_wlast),
        .M_AXI_GP0_master_gp0_axi_wstrb(gp0_wstrb),
        .M_AXI_GP0_master_gp0_axi_wvalid(gp0_wvalid));

    // Synchronize peripheral reset release to the PS-to-FPGA AXI clock.
    reset_sync #(.HOLD_CYCLES(500_000)) u_axi_reset_sync (
        .clk(p2f_clk0),
        .pll_lock(fabric_pll_lock),
        .rst_n(axi_resetn)
    );

    servo_control_gp0_axi #(
        .CLK_HZ(49_995_000),
        .ADDR_WIDTH(33),
        .ID_WIDTH(12),
        .BASE_ADDR(33'h080010000),
        // Linux controls all three channels through the AXI GP0 register block.
        .SELF_TEST(0)
    ) u_servo_control (
        .S_AXI_ACLK(p2f_clk0),
        .S_AXI_ARESETN(axi_resetn),
        .S_AXI_AWID(gp0_awid),
        .S_AXI_AWADDR(gp0_awaddr),
        .S_AXI_AWLEN(gp0_awlen),
        .S_AXI_AWSIZE(gp0_awsize),
        .S_AXI_AWBURST(gp0_awburst),
        .S_AXI_AWLOCK(gp0_awlock),
        .S_AXI_AWCACHE(gp0_awcache),
        .S_AXI_AWPROT(gp0_awprot),
        .S_AXI_AWVALID(gp0_awvalid),
        .S_AXI_AWREADY(gp0_awready),
        .S_AXI_WDATA(gp0_wdata),
        .S_AXI_WSTRB(gp0_wstrb),
        .S_AXI_WLAST(gp0_wlast),
        .S_AXI_WVALID(gp0_wvalid),
        .S_AXI_WREADY(gp0_wready),
        .S_AXI_BID(gp0_bid),
        .S_AXI_BRESP(gp0_bresp),
        .S_AXI_BVALID(gp0_bvalid),
        .S_AXI_BREADY(gp0_bready),
        .S_AXI_ARID(gp0_arid),
        .S_AXI_ARADDR(gp0_araddr),
        .S_AXI_ARLEN(gp0_arlen),
        .S_AXI_ARSIZE(gp0_arsize),
        .S_AXI_ARBURST(gp0_arburst),
        .S_AXI_ARLOCK(gp0_arlock),
        .S_AXI_ARCACHE(gp0_arcache),
        .S_AXI_ARPROT(gp0_arprot),
        .S_AXI_ARVALID(gp0_arvalid),
        .S_AXI_ARREADY(gp0_arready),
        .S_AXI_RID(gp0_rid),
        .S_AXI_RDATA(gp0_rdata),
        .S_AXI_RRESP(gp0_rresp),
        .S_AXI_RLAST(gp0_rlast),
        .S_AXI_RVALID(gp0_rvalid),
        .S_AXI_RREADY(gp0_rready),
        .ultrasonic_servo_pwm(ultrasonic_servo_pwm),
        .camera_pan_servo_pwm(camera_pan_servo_pwm),
        .camera_tilt_servo_pwm(camera_tilt_servo_pwm));

    boat_top boat_i (
        .I_sysclk(I_sysclk),
        .O_up_led(O_up_led),
        .fabric_pll_lock(fabric_pll_lock),
        .motor_left_pwm(motor_left_pwm),
        .motor_right_pwm(motor_right_pwm),
        .motor_enable(motor_enable)
    );
endmodule


