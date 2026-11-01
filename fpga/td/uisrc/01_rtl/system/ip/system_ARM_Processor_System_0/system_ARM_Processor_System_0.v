/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 31 2026 13:46:58
**	IpTool version	:	2026.03(193873 2026/03/31)
**	App version	:	Release_2026.1_SP2
**	Ip Version	:	1.0
\************************************************************/
`timescale 1ns/1ps
module system_ARM_Processor_System_0
(
  input                         master_gp0_axi_aclk,
  output  [32:0]                master_gp0_axi_araddr,
  output  [1:0]                 master_gp0_axi_arburst,
  output  [3:0]                 master_gp0_axi_arcache,
  output  [11:0]                master_gp0_axi_arid,
  output  [3:0]                 master_gp0_axi_arlen,
  output                        master_gp0_axi_arlock,
  output  [2:0]                 master_gp0_axi_arprot,
  input                         master_gp0_axi_arready,
  output  [1:0]                 master_gp0_axi_arsize,
  output                        master_gp0_axi_arvalid,
  output  [32:0]                master_gp0_axi_awaddr,
  output  [1:0]                 master_gp0_axi_awburst,
  output  [3:0]                 master_gp0_axi_awcache,
  output  [11:0]                master_gp0_axi_awid,
  output  [3:0]                 master_gp0_axi_awlen,
  output                        master_gp0_axi_awlock,
  output  [2:0]                 master_gp0_axi_awprot,
  input                         master_gp0_axi_awready,
  output  [1:0]                 master_gp0_axi_awsize,
  output                        master_gp0_axi_awvalid,
  input   [11:0]                master_gp0_axi_bid,
  output                        master_gp0_axi_bready,
  input   [1:0]                 master_gp0_axi_bresp,
  input                         master_gp0_axi_bvalid,
  input   [31:0]                master_gp0_axi_rdata,
  input   [11:0]                master_gp0_axi_rid,
  input                         master_gp0_axi_rlast,
  output                        master_gp0_axi_rready,
  input   [1:0]                 master_gp0_axi_rresp,
  input                         master_gp0_axi_rvalid,
  output  [31:0]                master_gp0_axi_wdata,
  output                        master_gp0_axi_wlast,
  input                         master_gp0_axi_wready,
  output  [3:0]                 master_gp0_axi_wstrb,
  output                        master_gp0_axi_wvalid,
  output                        p2f_clk0
);

  ARM_Processor_System_system_ARM_Processor_System_0
  #(
      .GBE0_TXCLK_PHA(0),
      .P2F_CLK0_DIV(8)
  )ARM_Processor_System_Inst
  (
      .master_gp0_axi_aclk(master_gp0_axi_aclk),
      .master_gp0_axi_araddr(master_gp0_axi_araddr),
      .master_gp0_axi_arburst(master_gp0_axi_arburst),
      .master_gp0_axi_arcache(master_gp0_axi_arcache),
      .master_gp0_axi_arid(master_gp0_axi_arid),
      .master_gp0_axi_arlen(master_gp0_axi_arlen),
      .master_gp0_axi_arlock(master_gp0_axi_arlock),
      .master_gp0_axi_arprot(master_gp0_axi_arprot),
      .master_gp0_axi_arready(master_gp0_axi_arready),
      .master_gp0_axi_arsize(master_gp0_axi_arsize),
      .master_gp0_axi_arvalid(master_gp0_axi_arvalid),
      .master_gp0_axi_awaddr(master_gp0_axi_awaddr),
      .master_gp0_axi_awburst(master_gp0_axi_awburst),
      .master_gp0_axi_awcache(master_gp0_axi_awcache),
      .master_gp0_axi_awid(master_gp0_axi_awid),
      .master_gp0_axi_awlen(master_gp0_axi_awlen),
      .master_gp0_axi_awlock(master_gp0_axi_awlock),
      .master_gp0_axi_awprot(master_gp0_axi_awprot),
      .master_gp0_axi_awready(master_gp0_axi_awready),
      .master_gp0_axi_awsize(master_gp0_axi_awsize),
      .master_gp0_axi_awvalid(master_gp0_axi_awvalid),
      .master_gp0_axi_bid(master_gp0_axi_bid),
      .master_gp0_axi_bready(master_gp0_axi_bready),
      .master_gp0_axi_bresp(master_gp0_axi_bresp),
      .master_gp0_axi_bvalid(master_gp0_axi_bvalid),
      .master_gp0_axi_rdata(master_gp0_axi_rdata),
      .master_gp0_axi_rid(master_gp0_axi_rid),
      .master_gp0_axi_rlast(master_gp0_axi_rlast),
      .master_gp0_axi_rready(master_gp0_axi_rready),
      .master_gp0_axi_rresp(master_gp0_axi_rresp),
      .master_gp0_axi_rvalid(master_gp0_axi_rvalid),
      .master_gp0_axi_wdata(master_gp0_axi_wdata),
      .master_gp0_axi_wlast(master_gp0_axi_wlast),
      .master_gp0_axi_wready(master_gp0_axi_wready),
      .master_gp0_axi_wstrb(master_gp0_axi_wstrb),
      .master_gp0_axi_wvalid(master_gp0_axi_wvalid),
      .p2f_clk0(p2f_clk0)
  );
endmodule
