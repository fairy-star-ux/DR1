/************************************************************\
**	Copyright (c) 2012-2024 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Dec 03 2024 09:25:08
**	TD version	:	5.9.135718
************************************************************/
`timescale 1ns/1ps
module system_ARM_Processor_System_0
(
  output                        p2f_clk0
);

  ARM_Processor_System_cb19c917a74f
  #(
      .p2f_clk0_1st_Divisor(8)
  )ARM_Processor_System_cb19c917a74f_Inst
  (
      .p2f_clk0(p2f_clk0)
  );
endmodule
