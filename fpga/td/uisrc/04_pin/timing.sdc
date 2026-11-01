create_clock -name {sys_clk} -period 10.000 -waveform {0.000 5.000} [get_ports {I_sysclk}]
derive_clocks
rename_clock -name {clk0} [get_clocks {u_PLLF9F0D0P0_0/dr1_phy_pll_Inst/u_DR1_PHY_PLL.clkc[0]}]
