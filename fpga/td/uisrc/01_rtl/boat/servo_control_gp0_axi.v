// Single-beat AXI4 slave for Linux MMIO over DR1 PS Master GP0.
//
// This is intentionally a fabric-side peripheral, not an AXI4-Lite slave:
// DR1 Master GP0 has 33-bit addresses and 12-bit transaction IDs. Linux
// readl()/writel() accesses are single-beat transfers, which this block handles.
// GP0 must be enabled in the FD ARM Processor System IP and routed to this
// peripheral before software can access it.
//
// Register offsets (base + offset):
//   0x00 camera pan angle (0..180 degrees)
//   0x04 camera tilt angle (0..180 degrees)
//   0x08 ultrasonic-servo angle (0..180 degrees)
//   0x0c ultrasonic control: bit 0 enable, bit 1 sweep 0..180
module servo_control_gp0_axi #(
    parameter integer CLK_HZ = 49_995_000,
    parameter integer ADDR_WIDTH = 33,
    parameter integer ID_WIDTH = 12,
    parameter [32:0] BASE_ADDR = 33'h080010000,
    // Set to 1 only for the standalone hardware test bitstream. It makes all
    // three servos sweep without Linux; set to 0 for normal AXI control.
    parameter integer SELF_TEST = 0
) (
    input  wire                     S_AXI_ACLK,
    input  wire                     S_AXI_ARESETN,
    input  wire [ID_WIDTH-1:0]      S_AXI_AWID,
    input  wire [ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    input  wire [3:0]               S_AXI_AWLEN,
    input  wire [2:0]               S_AXI_AWSIZE,
    input  wire [1:0]               S_AXI_AWBURST,
    input  wire                     S_AXI_AWLOCK,
    input  wire [3:0]               S_AXI_AWCACHE,
    input  wire [2:0]               S_AXI_AWPROT,
    input  wire                     S_AXI_AWVALID,
    output wire                     S_AXI_AWREADY,
    input  wire [31:0]              S_AXI_WDATA,
    input  wire [3:0]               S_AXI_WSTRB,
    input  wire                     S_AXI_WLAST,
    input  wire                     S_AXI_WVALID,
    output wire                     S_AXI_WREADY,
    output reg  [ID_WIDTH-1:0]      S_AXI_BID,
    output reg  [1:0]               S_AXI_BRESP,
    output reg                      S_AXI_BVALID,
    input  wire                     S_AXI_BREADY,
    input  wire [ID_WIDTH-1:0]      S_AXI_ARID,
    input  wire [ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    input  wire [3:0]               S_AXI_ARLEN,
    input  wire [2:0]               S_AXI_ARSIZE,
    input  wire [1:0]               S_AXI_ARBURST,
    input  wire                     S_AXI_ARLOCK,
    input  wire [3:0]               S_AXI_ARCACHE,
    input  wire [2:0]               S_AXI_ARPROT,
    input  wire                     S_AXI_ARVALID,
    output wire                     S_AXI_ARREADY,
    output reg  [ID_WIDTH-1:0]      S_AXI_RID,
    output reg  [31:0]              S_AXI_RDATA,
    output reg  [1:0]               S_AXI_RRESP,
    output reg                      S_AXI_RLAST,
    output reg                      S_AXI_RVALID,
    input  wire                     S_AXI_RREADY,
    output wire                     ultrasonic_servo_pwm,
    output wire                     camera_pan_servo_pwm,
    output wire                     camera_tilt_servo_pwm
);

    reg [7:0] pan_angle;
    reg [7:0] tilt_angle;
    reg [7:0] ultrasonic_angle;
    reg [1:0] ultrasonic_control;

    reg aw_saved;
    reg w_saved;
    reg [ID_WIDTH-1:0] awid_saved;
    reg [ADDR_WIDTH-1:0] awaddr_saved;
    reg [3:0] awlen_saved;
    reg [2:0] awsize_saved;
    reg [31:0] wdata_saved;
    reg [3:0] wstrb_saved;
    reg wlast_saved;

    wire [8:0] sweep_angle;
    wire [8:0] pan_test_angle;
    wire [8:0] tilt_test_angle;
    wire [8:0] ultrasonic_target;
    wire pan_pwm_enable;
    wire tilt_pwm_enable;
    wire ultrasonic_pwm_enable;
    wire [8:0] pan_pwm_angle;
    wire [8:0] tilt_pwm_angle;

    generate
        if (SELF_TEST != 0) begin : g_servo_self_test
            // Keep away from mechanical end stops during first wiring check.
            servo_scan #(.CLK_HZ(CLK_HZ), .STEP_MS(30),
                         .ANGLE_MIN(45), .ANGLE_MAX(135), .ANGLE_STEP(2)) u_pan_scan (
                .clk(S_AXI_ACLK), .rst_n(S_AXI_ARESETN), .angle_deg(pan_test_angle)
            );
            servo_scan #(.CLK_HZ(CLK_HZ), .STEP_MS(40),
                         .ANGLE_MIN(60), .ANGLE_MAX(120), .ANGLE_STEP(2)) u_tilt_scan (
                .clk(S_AXI_ACLK), .rst_n(S_AXI_ARESETN), .angle_deg(tilt_test_angle)
            );
            servo_scan #(.CLK_HZ(CLK_HZ), .STEP_MS(25),
                         .ANGLE_MIN(30), .ANGLE_MAX(150), .ANGLE_STEP(2)) u_ultrasonic_test_scan (
                .clk(S_AXI_ACLK), .rst_n(S_AXI_ARESETN), .angle_deg(sweep_angle)
            );
            assign pan_pwm_enable = S_AXI_ARESETN;
            assign tilt_pwm_enable = S_AXI_ARESETN;
            assign ultrasonic_pwm_enable = S_AXI_ARESETN;
            assign pan_pwm_angle = pan_test_angle;
            assign tilt_pwm_angle = tilt_test_angle;
            assign ultrasonic_target = sweep_angle;
        end else begin : g_linux_servo_control
            servo_scan #(.CLK_HZ(CLK_HZ), .STEP_MS(20),
                         .ANGLE_MIN(0), .ANGLE_MAX(180), .ANGLE_STEP(2)) u_ultrasonic_scan (
                .clk(S_AXI_ACLK), .rst_n(S_AXI_ARESETN), .angle_deg(sweep_angle)
            );
            assign pan_pwm_enable = S_AXI_ARESETN;
            assign tilt_pwm_enable = S_AXI_ARESETN;
            assign ultrasonic_pwm_enable = ultrasonic_control[0];
            assign pan_pwm_angle = {1'b0, pan_angle};
            assign tilt_pwm_angle = {1'b0, tilt_angle};
            assign ultrasonic_target = ultrasonic_control[1]
                                     ? sweep_angle : {1'b0, ultrasonic_angle};
        end
    endgenerate

    function [7:0] clamp_angle;
        input [7:0] value;
        begin
            clamp_angle = (value > 8'd180) ? 8'd180 : value;
        end
    endfunction

    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_saved && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_saved  && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            pan_angle         <= 8'd90;
            tilt_angle        <= 8'd90;
            ultrasonic_angle  <= 8'd90;
            ultrasonic_control<= 2'b00;
            aw_saved          <= 1'b0;
            w_saved           <= 1'b0;
            awid_saved        <= {ID_WIDTH{1'b0}};
            awaddr_saved      <= {ADDR_WIDTH{1'b0}};
            awlen_saved       <= 4'd0;
            awsize_saved      <= 3'd0;
            wdata_saved       <= 32'd0;
            wstrb_saved       <= 4'd0;
            wlast_saved       <= 1'b0;
            S_AXI_BID         <= {ID_WIDTH{1'b0}};
            S_AXI_BRESP       <= 2'b00;
            S_AXI_BVALID      <= 1'b0;
            S_AXI_RID         <= {ID_WIDTH{1'b0}};
            S_AXI_RDATA       <= 32'd0;
            S_AXI_RRESP       <= 2'b00;
            S_AXI_RLAST       <= 1'b0;
            S_AXI_RVALID      <= 1'b0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                aw_saved     <= 1'b1;
                awid_saved   <= S_AXI_AWID;
                awaddr_saved <= S_AXI_AWADDR;
                awlen_saved  <= S_AXI_AWLEN;
                awsize_saved <= S_AXI_AWSIZE;
            end
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                w_saved     <= 1'b1;
                wdata_saved  <= S_AXI_WDATA;
                wstrb_saved  <= S_AXI_WSTRB;
                wlast_saved  <= S_AXI_WLAST;
            end

            if (aw_saved && w_saved && !S_AXI_BVALID) begin
                // The Linux MMIO API generates one aligned 32-bit beat. Reject
                // other burst shapes instead of silently corrupting registers.
                if ((awlen_saved == 4'd0) && wlast_saved &&
                    (awsize_saved == 3'd2) &&
                    (awaddr_saved[1:0] == 2'b00) &&
                    (awaddr_saved[32:12] == BASE_ADDR[32:12]) &&
                    (awaddr_saved[11:4] == 8'd0)) begin
                    case (awaddr_saved[5:2])
                        4'h0: if (wstrb_saved[0]) pan_angle <= clamp_angle(wdata_saved[7:0]);
                        4'h1: if (wstrb_saved[0]) tilt_angle <= clamp_angle(wdata_saved[7:0]);
                        4'h2: if (wstrb_saved[0]) ultrasonic_angle <= clamp_angle(wdata_saved[7:0]);
                        4'h3: if (wstrb_saved[0]) ultrasonic_control <= wdata_saved[1:0];
                        default: S_AXI_BRESP <= 2'b10;
                    endcase
                end else begin
                    S_AXI_BRESP <= 2'b10; // SLVERR: unsupported burst/alignment
                end
                if ((awlen_saved == 4'd0) && wlast_saved &&
                    (awsize_saved == 3'd2) &&
                    (awaddr_saved[1:0] == 2'b00) &&
                    (awaddr_saved[32:12] == BASE_ADDR[32:12]) &&
                    (awaddr_saved[11:4] == 8'd0) &&
                    (awaddr_saved[5:2] <= 4'h3))
                    S_AXI_BRESP <= 2'b00;
                S_AXI_BID    <= awid_saved;
                S_AXI_BVALID <= 1'b1;
                aw_saved     <= 1'b0;
                w_saved      <= 1'b0;
            end
            if (S_AXI_BVALID && S_AXI_BREADY)
                S_AXI_BVALID <= 1'b0;

            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RID   <= S_AXI_ARID;
                S_AXI_RLAST <= 1'b1;
                if ((S_AXI_ARLEN == 4'd0) && (S_AXI_ARSIZE == 2'd2) &&
                    (S_AXI_ARADDR[1:0] == 2'b00) &&
                    (S_AXI_ARADDR[32:12] == BASE_ADDR[32:12]) &&
                    (S_AXI_ARADDR[11:4] == 8'd0) &&
                    (S_AXI_ARADDR[5:2] <= 4'h3)) begin
                    case (S_AXI_ARADDR[5:2])
                        4'h0: S_AXI_RDATA <= {24'd0, pan_angle};
                        4'h1: S_AXI_RDATA <= {24'd0, tilt_angle};
                        4'h2: S_AXI_RDATA <= {24'd0, ultrasonic_angle};
                        4'h3: S_AXI_RDATA <= {30'd0, ultrasonic_control};
                        default: S_AXI_RDATA <= 32'd0;
                    endcase
                    S_AXI_RRESP <= 2'b00;
                end else begin
                    S_AXI_RDATA <= 32'd0;
                    S_AXI_RRESP <= 2'b10;
                end
                S_AXI_RVALID <= 1'b1;
            end
            if (S_AXI_RVALID && S_AXI_RREADY)
                S_AXI_RVALID <= 1'b0;
        end
    end

    servo_pwm #(.CLK_HZ(CLK_HZ)) u_ultrasonic_pwm (
        .clk(S_AXI_ACLK), .rst_n(S_AXI_ARESETN),
        .enable(ultrasonic_pwm_enable), .angle_deg(ultrasonic_target),
        .pwm(ultrasonic_servo_pwm)
    );
    servo_pwm #(.CLK_HZ(CLK_HZ)) u_camera_pan_pwm (
        .clk(S_AXI_ACLK), .rst_n(S_AXI_ARESETN),
        .enable(pan_pwm_enable), .angle_deg(pan_pwm_angle),
        .pwm(camera_pan_servo_pwm)
    );
    servo_pwm #(.CLK_HZ(CLK_HZ)) u_camera_tilt_pwm (
        .clk(S_AXI_ACLK), .rst_n(S_AXI_ARESETN),
        .enable(tilt_pwm_enable), .angle_deg(tilt_pwm_angle),
        .pwm(camera_tilt_servo_pwm)
    );
endmodule
