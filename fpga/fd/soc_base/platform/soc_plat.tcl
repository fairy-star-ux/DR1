init
source [find mem_helper.tcl]
proc mask_write {addr mask val } {
	set old_val [mrw $addr]
	set new_val [expr {($val & $mask) | ($old_val & (~$mask))}]
	mww $addr $new_val
}


proc write {addr val } {
	set old_val [mrw $addr]
	set new_val $val
	mww $addr $new_val
}

set POLL_MAX_TIMES 1000
proc mask_poll {addr mask val } {
	set index 0
	set old [mrw $addr]
	set flag [expr {$old & $mask}]
	while { $flag != $val} { 
		if { $index == $::POLL_MAX_TIMES } { 
			puts "Info : mask poll timeout: " $addr
			break 
		}
		set old [mrw $addr]
		set flag [expr {$old & $mask}]
		incr index 1
	}	
}

# config ddr using elf start -->
proc wait_ddr_init {} {
	set t [target current]
	for {set j 0} {$j < 5} {incr j}  {
		halt
		set DFISTAT [expr {[mrw 0xf84211bc] & 0x1}]
		set STAT	[expr {[mrw 0xf8421004] & 0x7}]

		if {($DFISTAT == 1) && ($STAT != 0)} {
			puts "Info : DDR initialization: Completed"
			break
		} else {
			resume
			puts "Info : DDR initialization... "
			sleep 1000
		}
	}
	if {$j > 5} {
		puts "Error : DDR initialization: Failed"
	}
	halt
}

proc DDRC_CONFIG_FULL_READ {ADDR} {
    return [mrw $ADDR]
}

proc DDRC_CONFIG_FULL_WRITE {ADDR VAL} {
    mww $ADDR $VAL
}

proc DDRC_CONFIG_FIELD_READ {ADDR MASK SHIFT} {
    set val [mrw $ADDR] 
    return [expr {($val & $MASK) >> $SHIFT}]
}

proc DDRC_CONFIG_FIELD_SET {VAR_NAME MASK SHIFT VAL} {
    upvar $VAR_NAME var  
    set new_val [expr {($var & ~$MASK) | (($VAL << $SHIFT) & $MASK)}]
    set var $new_val  
}

proc DDRC_CONFIG_FIELD_WRITE {ADDR MASK SHIFT VAL} {
    set current_val [mrw $ADDR]
    set new_val [expr {($current_val & ~$MASK) | (($VAL << $SHIFT) & $MASK)}]
    mww $ADDR $new_val
}

proc DDRC_CONFIG_FIELD_WAIT {ADDR MASK SHIFT EXP_VAL TIMEOUT} {
    for {set timeout_cnt 0} {$timeout_cnt < $TIMEOUT} {incr timeout_cnt} {
        set current_val [DDRC_CONFIG_FIELD_READ $ADDR $MASK $SHIFT]
        if {$current_val == $EXP_VAL} {
            break
        }
    }
}
# enable DDR Init Debug Log
if {![info exists DDRC_DEBUG_LOG_EN]} {
	set DDRC_DEBUG_LOG_EN 1
} 

proc DDRC_CONFIG_REG_INFO {addr} {
	if {$::DDRC_DEBUG_LOG_EN} {
		set val [DDRC_CONFIG_FULL_READ $addr]
		puts [format "\[DDRC\]\[REG\] 0x%08x: 0x%08x" $addr $val]
	}
}

proc DDRC_CONFIG_MRS_INFO {idx val} {
	if {$::DDRC_DEBUG_LOG_EN} {
		puts [format "\[DDRC\]\[MRS\] 0x%08x: 0x%08x" $idx $val]
	}
}

set ROW_COL_BANK                    0
set ROW_BANK_COL                    1
set BANK_ROW_COL                    2

set DDR4                            4
set DDR3                            3

set Internal                        0
set External                        1

set x16                            16
set x8                              8

set DDR3_800D                       0
set DDR3_800E                       1
set DDR3_1066E                      2
set DDR3_1066F                      3
set DDR3_1066G                      4
set DDR3_1333F                      5
set DDR3_1333G                      6
set DDR3_1333H                      7
set DDR3_1333J                      8
set DDR4_1600J                      9
set DDR4_1600K                     10
set DDR4_1600L                     11

set NONE                            0
set WDM                             1
set RDBI                            1

set AARCH64                         0
set RISCV                           1
set p_arch                     $RISCV

set NONE                        0
set SideBand                    1
set Inline                      2

# Use DDR Init V2 function (source code) as default
set DDR_INIT_V2 1 

set DDRC_ADDR_MAP       $ROW_COL_BANK
set DDRC_COMP_DENSITY            4096
set DDRC_SPEED_BIN        $DDR3_1333G
set DDRC_COMP_TYPE               $x16
set DDRC_ECC_EN                 $NONE
set DDRC_IO_VOL            0x3FACCCCD
set DDRC_PZQ_CONF                   0
set DDRC_RDBI                       0
set DDRC_DDR_SPEED               1333
set DDRC_TRAINING_EN                1
set DDRC_DDR_TYPE               $DDR3
set DDRC_VREF               $Internal
set DDRC_WDM_WDBI               $NONE
set DDRC_DQ_WIDTH                  32
set DDRPS_ENABLE                    1
set OSC_CLK                  33333333

set p_osc_clk          33330000
set p_type             3       
set p_speed            1066    
set p_dq_width         32      
set p_io_vol           1    
set p_verf             0       
set p_pzq              0       
set p_dram_width       8       
set p_speed_bin_index  4       
set p_wdbi             1       
set p_rdbi             0       
set p_dram_density     4096    
set p_ecc              0       
set p_addr_map         0       
set p_training         0       
set p_byte0_ac_dely    0     
set p_byte0_dqs_dely   0     
set p_byte1_ac_dely    0     
set p_byte1_dqs_dely   0     
set p_byte2_ac_dely    0     
set p_byte2_dqs_dely   0 
set p_byte3_ac_dely    0
set p_byte3_dqs_dely   0 
set p_ddr_dram_drv    		40
set p_ddr_dram_odt	  		40
set p_ddr_host_drv_for_ac	40
set p_ddr_host_drv_for_dx	40
set p_ddr_host_odt_for_dx	40

# (1)
if {[info exists DDRC_ADDR_MAP]} {
	set p_addr_map $DDRC_ADDR_MAP
} 

# (2)
if {[info exists DDRC_COMP_DENSITY]} {
	set p_dram_density $DDRC_COMP_DENSITY
} 

# (3)
if {[info exists DDRC_SPEED_BIN]} {
	set p_speed_bin_index $DDRC_SPEED_BIN
} 

# (4)
if {[info exists DDRC_COMP_TYPE]} {
	set p_dram_width $DDRC_COMP_TYPE
} 

# (5)
if {[info exists DDRC_IO_VOL]} {
	set p_io_vol $DDRC_IO_VOL
} 

# (6)
if {[info exists DDRC_PZQ_CONF]} {
	set p_pzq $DDRC_PZQ_CONF
} 

# (7)
if {[info exists DDRC_DDR_SPEED]} {
	set p_speed $DDRC_DDR_SPEED
} 

# (8)
if {[info exists DDRC_TRAINING_EN]} {
	set p_training $DDRC_TRAINING_EN
} 

# (9)
if {[info exists DDRC_DELAY_B0_AC]} {
	set p_byte0_ac_dely $DDRC_DELAY_B0_AC
} 

# (10)
if {[info exists DDRC_DELAY_B0_DQ]} {
	set p_byte0_dqs_dely $DDRC_DELAY_B0_DQ
} 

# (11)
if {[info exists DDRC_DELAY_B1_AC]} {
	set p_byte1_ac_dely $DDRC_DELAY_B1_AC
} 

# (12)
if {[info exists DDRC_DELAY_B1_DQ]} {
	set p_byte1_dqs_dely $DDRC_DELAY_B1_DQ
} 

# (13)
if {[info exists DDRC_DELAY_B2_AC]} {
	set p_byte2_ac_dely $DDRC_DELAY_B2_AC
} 

# (14)
if {[info exists DDRC_DELAY_B2_DQ]} {
	set p_byte2_dqs_dely $DDRC_DELAY_B2_DQ
} 

# (15)
if {[info exists DDRC_DELAY_B3_AC]} {
	set p_byte3_ac_dely $DDRC_DELAY_B3_AC
} 

# (16)
if {[info exists DDRC_DELAY_B3_DQ]} {
	set p_byte3_dqs_dely $DDRC_DELAY_B3_DQ
} 

# (17)
if {[info exists DDRC_DDR_TYPE]} {
	set p_type $DDRC_DDR_TYPE
} 

# (18)
if {[info exists DDRC_VREF]} {
	set p_verf $DDRC_VREF
} 

# (19)
if {[info exists DDRC_WDM_WDBI]} {
	set p_wdbi $DDRC_WDM_WDBI
} 

# (20)
if {[info exists DDRC_DQ_WIDTH]} {
	set p_dq_width $DDRC_DQ_WIDTH
} 

# (21)
if {[info exists OSC_CLK]} {
	set p_osc_clk $OSC_CLK
} 

# (22)
if {[info exists DDRC_RDBI]} {
	set p_rdbi $DDRC_RDBI
} 

# (23)
if {[info exists DDRC_ECC_EN]} {
	set p_ecc $DDRC_ECC_EN
} 

# (24)
if {[info exists FD_PARA_DRAM_DRV]} {
	set p_ddr_dram_drv $FD_PARA_DRAM_DRV
} 

# (25)
if {[info exists FD_PARA_DRAM_ODT]} {
	set p_ddr_dram_odt $FD_PARA_DRAM_ODT
} 

# (26)
if {[info exists FD_PARA_HOST_DRV_AC]} {
	set p_ddr_host_drv_for_ac $FD_PARA_HOST_DRV_AC
} 

# (27)
if {[info exists FD_PARA_HOST_DRV_DX]} {
	set p_ddr_host_drv_for_dx $FD_PARA_HOST_DRV_DX
} 

# (28)
if {[info exists FD_PARA_HOST_ODT_DX]} {
	set p_ddr_host_odt_for_dx $FD_PARA_HOST_ODT_DX
} 

# (0) config system
proc config_system { } {
	# Config powerMode, power mode control for sram of rpu_sub
	# register: POWER_MODE.power_mode_rpu = 5
	# 0xF8800030[21:16] = 5
	mask_write 0xF8800030 0x003f0000 0x00050000

	# Config pin, fix to LVCMOS 3.3V
	# register: IO_BANK200_REF.bank200_mc1_force_dtc = 0x3
	# 0xF8803c00[5:4] = 0x3
	mask_write 0xF8803c00 0x00000030 0x00000030

	# Config pin, fix to LVCMOS 1.8V
	# register: IO_BANK201_REF.bank201_mc1_force_dtc = 0x1
	# 0xF8803c04[5:4] = 0x1
	mask_write 0xF8803c04 0x00000030 0x00000010

	# Config NPU, status: Disable
	# register: CFG_CTRL_NPU.ctrl_npu = 0x0
	# 0xF88001B8[1:0] = 0x0
	mask_write 0xF88001B8 0x00000003 0x00000000

}

# (1) config psio
proc config_psio { } {
	# Config USB0_d0, PS IO 32->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_32.mc1_ensrc = 0x15
	# 0xf8803904[15:8] = 0x15
	# Config USB0_d0, PS IO 32->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_32.mc1_ensnk = 0x17
	# 0xf8803904[23:16] = 0x17
	# Config v, PS IO 32->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_32.mc1_i_mode = 0x2
	# 0xf8803904[1:0] = 0x2
	write 0xf8803904 0x00171502
	# Config USB0_d0, PS IO 32->speed: fast
	# register: PARA0_PS_IO_32.speed = 0x7
	# 0xf8803900[2:0] = 0x7
	# Config USB0_d0, PS IO 32->PullType: pulldown 10k
	# register: PARA0_PS_IO_32.PullType = 0x5
	# 0xf8803900[31:28] = 0x5
	write 0xf8803900 0x50000007
	# Config USB0, PS IO 32->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_32.funcsel_PS_IO_32 = 15
	# 0xf8803080[3:0] = 15
	write 0xf8803080 0x0000000f
	# Config USB0_d1, PS IO 33->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_33.mc1_ensrc = 0x15
	# 0xf880390c[15:8] = 0x15
	# Config USB0_d1, PS IO 33->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_33.mc1_ensnk = 0x17
	# 0xf880390c[23:16] = 0x17
	# Config v, PS IO 33->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_33.mc1_i_mode = 0x2
	# 0xf880390c[1:0] = 0x2
	write 0xf880390c 0x00171502
	# Config USB0_d1, PS IO 33->speed: fast
	# register: PARA0_PS_IO_33.speed = 0x7
	# 0xf8803908[2:0] = 0x7
	# Config USB0_d1, PS IO 33->PullType: pulldown 10k
	# register: PARA0_PS_IO_33.PullType = 0x5
	# 0xf8803908[31:28] = 0x5
	write 0xf8803908 0x50000007
	# Config USB0, PS IO 33->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_33.funcsel_PS_IO_33 = 15
	# 0xf8803084[3:0] = 15
	write 0xf8803084 0x0000000f
	# Config USB0_d2, PS IO 34->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_34.mc1_ensrc = 0x15
	# 0xf8803914[15:8] = 0x15
	# Config USB0_d2, PS IO 34->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_34.mc1_ensnk = 0x17
	# 0xf8803914[23:16] = 0x17
	# Config v, PS IO 34->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_34.mc1_i_mode = 0x2
	# 0xf8803914[1:0] = 0x2
	write 0xf8803914 0x00171502
	# Config USB0_d2, PS IO 34->speed: fast
	# register: PARA0_PS_IO_34.speed = 0x7
	# 0xf8803910[2:0] = 0x7
	# Config USB0_d2, PS IO 34->PullType: pulldown 10k
	# register: PARA0_PS_IO_34.PullType = 0x5
	# 0xf8803910[31:28] = 0x5
	write 0xf8803910 0x50000007
	# Config USB0, PS IO 34->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_34.funcsel_PS_IO_34 = 15
	# 0xf8803088[3:0] = 15
	write 0xf8803088 0x0000000f
	# Config USB0_d3, PS IO 35->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_35.mc1_ensrc = 0x15
	# 0xf880391c[15:8] = 0x15
	# Config USB0_d3, PS IO 35->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_35.mc1_ensnk = 0x17
	# 0xf880391c[23:16] = 0x17
	# Config v, PS IO 35->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_35.mc1_i_mode = 0x2
	# 0xf880391c[1:0] = 0x2
	write 0xf880391c 0x00171502
	# Config USB0_d3, PS IO 35->speed: fast
	# register: PARA0_PS_IO_35.speed = 0x7
	# 0xf8803918[2:0] = 0x7
	# Config USB0_d3, PS IO 35->PullType: pulldown 10k
	# register: PARA0_PS_IO_35.PullType = 0x5
	# 0xf8803918[31:28] = 0x5
	write 0xf8803918 0x50000007
	# Config USB0, PS IO 35->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_35.funcsel_PS_IO_35 = 15
	# 0xf880308c[3:0] = 15
	write 0xf880308c 0x0000000f
	# Config USB0_d4, PS IO 28->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_28.mc1_ensrc = 0x15
	# 0xf88038e4[15:8] = 0x15
	# Config USB0_d4, PS IO 28->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_28.mc1_ensnk = 0x17
	# 0xf88038e4[23:16] = 0x17
	# Config v, PS IO 28->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_28.mc1_i_mode = 0x2
	# 0xf88038e4[1:0] = 0x2
	write 0xf88038e4 0x00171502
	# Config USB0_d4, PS IO 28->speed: fast
	# register: PARA0_PS_IO_28.speed = 0x7
	# 0xf88038e0[2:0] = 0x7
	# Config USB0_d4, PS IO 28->PullType: pulldown 10k
	# register: PARA0_PS_IO_28.PullType = 0x5
	# 0xf88038e0[31:28] = 0x5
	write 0xf88038e0 0x50000007
	# Config USB0, PS IO 28->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_28.funcsel_PS_IO_28 = 15
	# 0xf8803070[3:0] = 15
	write 0xf8803070 0x0000000f
	# Config USB0_d5, PS IO 37->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_37.mc1_ensrc = 0x15
	# 0xf880392c[15:8] = 0x15
	# Config USB0_d5, PS IO 37->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_37.mc1_ensnk = 0x17
	# 0xf880392c[23:16] = 0x17
	# Config v, PS IO 37->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_37.mc1_i_mode = 0x2
	# 0xf880392c[1:0] = 0x2
	write 0xf880392c 0x00171502
	# Config USB0_d5, PS IO 37->speed: fast
	# register: PARA0_PS_IO_37.speed = 0x7
	# 0xf8803928[2:0] = 0x7
	# Config USB0_d5, PS IO 37->PullType: pulldown 10k
	# register: PARA0_PS_IO_37.PullType = 0x5
	# 0xf8803928[31:28] = 0x5
	write 0xf8803928 0x50000007
	# Config USB0, PS IO 37->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_37.funcsel_PS_IO_37 = 15
	# 0xf8803094[3:0] = 15
	write 0xf8803094 0x0000000f
	# Config USB0_d6, PS IO 38->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_38.mc1_ensrc = 0x15
	# 0xf8803934[15:8] = 0x15
	# Config USB0_d6, PS IO 38->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_38.mc1_ensnk = 0x17
	# 0xf8803934[23:16] = 0x17
	# Config v, PS IO 38->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_38.mc1_i_mode = 0x2
	# 0xf8803934[1:0] = 0x2
	write 0xf8803934 0x00171502
	# Config USB0_d6, PS IO 38->speed: fast
	# register: PARA0_PS_IO_38.speed = 0x7
	# 0xf8803930[2:0] = 0x7
	# Config USB0_d6, PS IO 38->PullType: pulldown 10k
	# register: PARA0_PS_IO_38.PullType = 0x5
	# 0xf8803930[31:28] = 0x5
	write 0xf8803930 0x50000007
	# Config USB0, PS IO 38->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_38.funcsel_PS_IO_38 = 15
	# 0xf8803098[3:0] = 15
	write 0xf8803098 0x0000000f
	# Config USB0_dir, PS IO 29->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_29.mc1_ensrc = 0x15
	# 0xf88038ec[15:8] = 0x15
	# Config USB0_dir, PS IO 29->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_29.mc1_ensnk = 0x17
	# 0xf88038ec[23:16] = 0x17
	# Config v, PS IO 29->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_29.mc1_i_mode = 0x2
	# 0xf88038ec[1:0] = 0x2
	write 0xf88038ec 0x00171502
	# Config USB0_dir, PS IO 29->speed: fast
	# register: PARA0_PS_IO_29.speed = 0x7
	# 0xf88038e8[2:0] = 0x7
	# Config USB0_dir, PS IO 29->PullType: pullup 10k
	# register: PARA0_PS_IO_29.PullType = 0xA
	# 0xf88038e8[31:28] = 0xA
	write 0xf88038e8 0xa0000007
	# Config USB0, PS IO 29->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_29.funcsel_PS_IO_29 = 15
	# 0xf8803074[3:0] = 15
	write 0xf8803074 0x0000000f
	# Config USB0_stp, PS IO 30->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_30.mc1_ensrc = 0x15
	# 0xf88038f4[15:8] = 0x15
	# Config USB0_stp, PS IO 30->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_30.mc1_ensnk = 0x17
	# 0xf88038f4[23:16] = 0x17
	# Config v, PS IO 30->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_30.mc1_i_mode = 0x2
	# 0xf88038f4[1:0] = 0x2
	write 0xf88038f4 0x00171502
	# Config USB0_stp, PS IO 30->speed: fast
	# register: PARA0_PS_IO_30.speed = 0x7
	# 0xf88038f0[2:0] = 0x7
	# Config USB0_stp, PS IO 30->PullType: pullup 10k
	# register: PARA0_PS_IO_30.PullType = 0xA
	# 0xf88038f0[31:28] = 0xA
	write 0xf88038f0 0xa0000007
	# Config USB0, PS IO 30->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_30.funcsel_PS_IO_30 = 15
	# 0xf8803078[3:0] = 15
	write 0xf8803078 0x0000000f
	# Config USB0_nxt, PS IO 31->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_31.mc1_ensrc = 0x15
	# 0xf88038fc[15:8] = 0x15
	# Config USB0_nxt, PS IO 31->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_31.mc1_ensnk = 0x17
	# 0xf88038fc[23:16] = 0x17
	# Config v, PS IO 31->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_31.mc1_i_mode = 0x2
	# 0xf88038fc[1:0] = 0x2
	write 0xf88038fc 0x00171502
	# Config USB0_nxt, PS IO 31->speed: fast
	# register: PARA0_PS_IO_31.speed = 0x7
	# 0xf88038f8[2:0] = 0x7
	# Config USB0_nxt, PS IO 31->PullType: pullup 10k
	# register: PARA0_PS_IO_31.PullType = 0xA
	# 0xf88038f8[31:28] = 0xA
	write 0xf88038f8 0xa0000007
	# Config USB0, PS IO 31->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_31.funcsel_PS_IO_31 = 15
	# 0xf880307c[3:0] = 15
	write 0xf880307c 0x0000000f
	# Config USB0_clk, PS IO 36->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_36.mc1_ensrc = 0x15
	# 0xf8803924[15:8] = 0x15
	# Config USB0_clk, PS IO 36->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_36.mc1_ensnk = 0x17
	# 0xf8803924[23:16] = 0x17
	# Config v, PS IO 36->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_36.mc1_i_mode = 0x2
	# 0xf8803924[1:0] = 0x2
	write 0xf8803924 0x00171502
	# Config USB0_clk, PS IO 36->speed: fast
	# register: PARA0_PS_IO_36.speed = 0x7
	# 0xf8803920[2:0] = 0x7
	# Config USB0_clk, PS IO 36->PullType: pullup 10k
	# register: PARA0_PS_IO_36.PullType = 0xA
	# 0xf8803920[31:28] = 0xA
	write 0xf8803920 0xa0000007
	# Config USB0, PS IO 36->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_36.funcsel_PS_IO_36 = 15
	# 0xf8803090[3:0] = 15
	write 0xf8803090 0x0000000f
	# Config USB0_d7, PS IO 39->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_39.mc1_ensrc = 0x15
	# 0xf880393c[15:8] = 0x15
	# Config USB0_d7, PS IO 39->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_39.mc1_ensnk = 0x17
	# 0xf880393c[23:16] = 0x17
	# Config v, PS IO 39->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_39.mc1_i_mode = 0x2
	# 0xf880393c[1:0] = 0x2
	write 0xf880393c 0x00171502
	# Config USB0_d7, PS IO 39->speed: fast
	# register: PARA0_PS_IO_39.speed = 0x7
	# 0xf8803938[2:0] = 0x7
	# Config USB0_d7, PS IO 39->PullType: pulldown 10k
	# register: PARA0_PS_IO_39.PullType = 0x5
	# 0xf8803938[31:28] = 0x5
	write 0xf8803938 0x50000007
	# Config USB0, PS IO 39->FUNCSEL: USB0
	# register: FUNCSEL_PS_IO_39.funcsel_PS_IO_39 = 15
	# 0xf880309c[3:0] = 15
	write 0xf880309c 0x0000000f
	# Config ETH0_tx_clk, PS IO 16->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_16.mc1_ensrc = 0x15
	# 0xf8803884[15:8] = 0x15
	# Config ETH0_tx_clk, PS IO 16->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_16.mc1_ensnk = 0x17
	# 0xf8803884[23:16] = 0x17
	# Config v, PS IO 16->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_16.mc1_i_mode = 0x2
	# 0xf8803884[1:0] = 0x2
	write 0xf8803884 0x00171502
	# Config ETH0_tx_ctl, PS IO 21->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_21.mc1_ensrc = 0x15
	# 0xf88038ac[15:8] = 0x15
	# Config ETH0_tx_ctl, PS IO 21->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_21.mc1_ensnk = 0x17
	# 0xf88038ac[23:16] = 0x17
	# Config v, PS IO 21->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_21.mc1_i_mode = 0x2
	# 0xf88038ac[1:0] = 0x2
	write 0xf88038ac 0x00171502
	# Config ETH0_txd3, PS IO 20->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_20.mc1_ensrc = 0x15
	# 0xf88038a4[15:8] = 0x15
	# Config ETH0_txd3, PS IO 20->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_20.mc1_ensnk = 0x17
	# 0xf88038a4[23:16] = 0x17
	# Config v, PS IO 20->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_20.mc1_i_mode = 0x2
	# 0xf88038a4[1:0] = 0x2
	write 0xf88038a4 0x00171502
	# Config ETH0_txd2, PS IO 19->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_19.mc1_ensrc = 0x15
	# 0xf880389c[15:8] = 0x15
	# Config ETH0_txd2, PS IO 19->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_19.mc1_ensnk = 0x17
	# 0xf880389c[23:16] = 0x17
	# Config v, PS IO 19->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_19.mc1_i_mode = 0x2
	# 0xf880389c[1:0] = 0x2
	write 0xf880389c 0x00171502
	# Config ETH0_txd1, PS IO 18->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_18.mc1_ensrc = 0x15
	# 0xf8803894[15:8] = 0x15
	# Config ETH0_txd1, PS IO 18->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_18.mc1_ensnk = 0x17
	# 0xf8803894[23:16] = 0x17
	# Config v, PS IO 18->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_18.mc1_i_mode = 0x2
	# 0xf8803894[1:0] = 0x2
	write 0xf8803894 0x00171502
	# Config ETH0_txd0, PS IO 17->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_17.mc1_ensrc = 0x15
	# 0xf880388c[15:8] = 0x15
	# Config ETH0_txd0, PS IO 17->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_17.mc1_ensnk = 0x17
	# 0xf880388c[23:16] = 0x17
	# Config v, PS IO 17->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_17.mc1_i_mode = 0x2
	# 0xf880388c[1:0] = 0x2
	write 0xf880388c 0x00171502
	# Config ETH0_rx_clk, PS IO 22->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_22.mc1_ensrc = 0x15
	# 0xf88038b4[15:8] = 0x15
	# Config ETH0_rx_clk, PS IO 22->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_22.mc1_ensnk = 0x17
	# 0xf88038b4[23:16] = 0x17
	# Config v, PS IO 22->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_22.mc1_i_mode = 0x2
	# 0xf88038b4[1:0] = 0x2
	write 0xf88038b4 0x00171502
	# Config ETH0_rx_ctl, PS IO 27->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_27.mc1_ensrc = 0x15
	# 0xf88038dc[15:8] = 0x15
	# Config ETH0_rx_ctl, PS IO 27->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_27.mc1_ensnk = 0x17
	# 0xf88038dc[23:16] = 0x17
	# Config v, PS IO 27->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_27.mc1_i_mode = 0x2
	# 0xf88038dc[1:0] = 0x2
	write 0xf88038dc 0x00171502
	# Config ETH0_rxd3, PS IO 26->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_26.mc1_ensrc = 0x15
	# 0xf88038d4[15:8] = 0x15
	# Config ETH0_rxd3, PS IO 26->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_26.mc1_ensnk = 0x17
	# 0xf88038d4[23:16] = 0x17
	# Config v, PS IO 26->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_26.mc1_i_mode = 0x2
	# 0xf88038d4[1:0] = 0x2
	write 0xf88038d4 0x00171502
	# Config ETH0_rxd2, PS IO 25->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_25.mc1_ensrc = 0x15
	# 0xf88038cc[15:8] = 0x15
	# Config ETH0_rxd2, PS IO 25->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_25.mc1_ensnk = 0x17
	# 0xf88038cc[23:16] = 0x17
	# Config v, PS IO 25->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_25.mc1_i_mode = 0x2
	# 0xf88038cc[1:0] = 0x2
	write 0xf88038cc 0x00171502
	# Config ETH0_rxd1, PS IO 24->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_24.mc1_ensrc = 0x15
	# 0xf88038c4[15:8] = 0x15
	# Config ETH0_rxd1, PS IO 24->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_24.mc1_ensnk = 0x17
	# 0xf88038c4[23:16] = 0x17
	# Config v, PS IO 24->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_24.mc1_i_mode = 0x2
	# 0xf88038c4[1:0] = 0x2
	write 0xf88038c4 0x00171502
	# Config ETH0_rxd0, PS IO 23->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_23.mc1_ensrc = 0x15
	# 0xf88038bc[15:8] = 0x15
	# Config ETH0_rxd0, PS IO 23->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_23.mc1_ensnk = 0x17
	# 0xf88038bc[23:16] = 0x17
	# Config v, PS IO 23->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_23.mc1_i_mode = 0x2
	# 0xf88038bc[1:0] = 0x2
	write 0xf88038bc 0x00171502
	# Config ETH0_tx_clk, PS IO 16->speed: fast
	# register: PARA0_PS_IO_16.speed = 0x7
	# 0xf8803880[2:0] = 0x7
	# Config ETH0_tx_clk, PS IO 16->PullType: high Z
	# register: PARA0_PS_IO_16.PullType = 0xC
	# 0xf8803880[31:28] = 0xC
	# Config v, PS IO 16->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_16.inhys = 0x8
	# 0xf8803880[27:24] = 0x8
	write 0xf8803880 0xc8000007
	# Config ETH0_tx_ctl, PS IO 21->speed: fast
	# register: PARA0_PS_IO_21.speed = 0x7
	# 0xf88038a8[2:0] = 0x7
	# Config ETH0_tx_ctl, PS IO 21->PullType: high Z
	# register: PARA0_PS_IO_21.PullType = 0xC
	# 0xf88038a8[31:28] = 0xC
	# Config v, PS IO 21->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_21.inhys = 0x8
	# 0xf88038a8[27:24] = 0x8
	write 0xf88038a8 0xc8000007
	# Config ETH0_txd3, PS IO 20->speed: fast
	# register: PARA0_PS_IO_20.speed = 0x7
	# 0xf88038a0[2:0] = 0x7
	# Config ETH0_txd3, PS IO 20->PullType: high Z
	# register: PARA0_PS_IO_20.PullType = 0xC
	# 0xf88038a0[31:28] = 0xC
	# Config v, PS IO 20->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_20.inhys = 0x8
	# 0xf88038a0[27:24] = 0x8
	write 0xf88038a0 0xc8000007
	# Config ETH0_txd2, PS IO 19->speed: fast
	# register: PARA0_PS_IO_19.speed = 0x7
	# 0xf8803898[2:0] = 0x7
	# Config ETH0_txd2, PS IO 19->PullType: high Z
	# register: PARA0_PS_IO_19.PullType = 0xC
	# 0xf8803898[31:28] = 0xC
	# Config v, PS IO 19->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_19.inhys = 0x8
	# 0xf8803898[27:24] = 0x8
	write 0xf8803898 0xc8000007
	# Config ETH0_txd1, PS IO 18->speed: fast
	# register: PARA0_PS_IO_18.speed = 0x7
	# 0xf8803890[2:0] = 0x7
	# Config ETH0_txd1, PS IO 18->PullType: high Z
	# register: PARA0_PS_IO_18.PullType = 0xC
	# 0xf8803890[31:28] = 0xC
	# Config v, PS IO 18->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_18.inhys = 0x8
	# 0xf8803890[27:24] = 0x8
	write 0xf8803890 0xc8000007
	# Config ETH0_txd0, PS IO 17->speed: fast
	# register: PARA0_PS_IO_17.speed = 0x7
	# 0xf8803888[2:0] = 0x7
	# Config ETH0_txd0, PS IO 17->PullType: high Z
	# register: PARA0_PS_IO_17.PullType = 0xC
	# 0xf8803888[31:28] = 0xC
	# Config v, PS IO 17->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_17.inhys = 0x8
	# 0xf8803888[27:24] = 0x8
	write 0xf8803888 0xc8000007
	# Config ETH0_rx_clk, PS IO 22->speed: fast
	# register: PARA0_PS_IO_22.speed = 0x7
	# 0xf88038b0[2:0] = 0x7
	# Config ETH0_rx_clk, PS IO 22->PullType: pullup 25k
	# register: PARA0_PS_IO_22.PullType = 0x8
	# 0xf88038b0[31:28] = 0x8
	# Config v, PS IO 22->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_22.inhys = 0x8
	# 0xf88038b0[27:24] = 0x8
	# Config v, PS IO 22->slewrate: LVCMOS 1.8V
	# register: PARA0_PS_IO_22.slewrate = 0x0
	# 0xf88038b0[23:4] = 0x0
	write 0xf88038b0 0x88000007
	# Config ETH0_rx_ctl, PS IO 27->speed: fast
	# register: PARA0_PS_IO_27.speed = 0x7
	# 0xf88038d8[2:0] = 0x7
	# Config ETH0_rx_ctl, PS IO 27->PullType: pullup 25k
	# register: PARA0_PS_IO_27.PullType = 0x8
	# 0xf88038d8[31:28] = 0x8
	# Config v, PS IO 27->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_27.inhys = 0x8
	# 0xf88038d8[27:24] = 0x8
	# Config v, PS IO 27->slewrate: LVCMOS 1.8V
	# register: PARA0_PS_IO_27.slewrate = 0x0
	# 0xf88038d8[23:4] = 0x0
	write 0xf88038d8 0x88000007
	# Config ETH0_rxd3, PS IO 26->speed: fast
	# register: PARA0_PS_IO_26.speed = 0x7
	# 0xf88038d0[2:0] = 0x7
	# Config ETH0_rxd3, PS IO 26->PullType: pullup 25k
	# register: PARA0_PS_IO_26.PullType = 0x8
	# 0xf88038d0[31:28] = 0x8
	# Config v, PS IO 26->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_26.inhys = 0x8
	# 0xf88038d0[27:24] = 0x8
	# Config v, PS IO 26->slewrate: LVCMOS 1.8V
	# register: PARA0_PS_IO_26.slewrate = 0x0
	# 0xf88038d0[23:4] = 0x0
	write 0xf88038d0 0x88000007
	# Config ETH0_rxd2, PS IO 25->speed: fast
	# register: PARA0_PS_IO_25.speed = 0x7
	# 0xf88038c8[2:0] = 0x7
	# Config ETH0_rxd2, PS IO 25->PullType: pullup 25k
	# register: PARA0_PS_IO_25.PullType = 0x8
	# 0xf88038c8[31:28] = 0x8
	# Config v, PS IO 25->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_25.inhys = 0x8
	# 0xf88038c8[27:24] = 0x8
	# Config v, PS IO 25->slewrate: LVCMOS 1.8V
	# register: PARA0_PS_IO_25.slewrate = 0x0
	# 0xf88038c8[23:4] = 0x0
	write 0xf88038c8 0x88000007
	# Config ETH0_rxd1, PS IO 24->speed: fast
	# register: PARA0_PS_IO_24.speed = 0x7
	# 0xf88038c0[2:0] = 0x7
	# Config ETH0_rxd1, PS IO 24->PullType: pullup 25k
	# register: PARA0_PS_IO_24.PullType = 0x8
	# 0xf88038c0[31:28] = 0x8
	# Config v, PS IO 24->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_24.inhys = 0x8
	# 0xf88038c0[27:24] = 0x8
	# Config v, PS IO 24->slewrate: LVCMOS 1.8V
	# register: PARA0_PS_IO_24.slewrate = 0x0
	# 0xf88038c0[23:4] = 0x0
	write 0xf88038c0 0x88000007
	# Config ETH0_rxd0, PS IO 23->speed: fast
	# register: PARA0_PS_IO_23.speed = 0x7
	# 0xf88038b8[2:0] = 0x7
	# Config ETH0_rxd0, PS IO 23->PullType: pullup 25k
	# register: PARA0_PS_IO_23.PullType = 0x8
	# 0xf88038b8[31:28] = 0x8
	# Config v, PS IO 23->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_23.inhys = 0x8
	# 0xf88038b8[27:24] = 0x8
	# Config v, PS IO 23->slewrate: LVCMOS 1.8V
	# register: PARA0_PS_IO_23.slewrate = 0x0
	# 0xf88038b8[23:4] = 0x0
	write 0xf88038b8 0x88000007
	# Config ETH0, PS IO 16->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_16.funcsel_PS_IO_16 = 14
	# 0xf8803040[3:0] = 14
	write 0xf8803040 0x0000000e
	# Config ETH0, PS IO 21->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_21.funcsel_PS_IO_21 = 14
	# 0xf8803054[3:0] = 14
	write 0xf8803054 0x0000000e
	# Config ETH0, PS IO 20->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_20.funcsel_PS_IO_20 = 14
	# 0xf8803050[3:0] = 14
	write 0xf8803050 0x0000000e
	# Config ETH0, PS IO 19->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_19.funcsel_PS_IO_19 = 14
	# 0xf880304c[3:0] = 14
	write 0xf880304c 0x0000000e
	# Config ETH0, PS IO 18->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_18.funcsel_PS_IO_18 = 14
	# 0xf8803048[3:0] = 14
	write 0xf8803048 0x0000000e
	# Config ETH0, PS IO 17->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_17.funcsel_PS_IO_17 = 14
	# 0xf8803044[3:0] = 14
	write 0xf8803044 0x0000000e
	# Config ETH0, PS IO 22->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_22.funcsel_PS_IO_22 = 14
	# 0xf8803058[3:0] = 14
	write 0xf8803058 0x0000000e
	# Config ETH0, PS IO 27->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_27.funcsel_PS_IO_27 = 14
	# 0xf880306c[3:0] = 14
	write 0xf880306c 0x0000000e
	# Config ETH0, PS IO 26->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_26.funcsel_PS_IO_26 = 14
	# 0xf8803068[3:0] = 14
	write 0xf8803068 0x0000000e
	# Config ETH0, PS IO 25->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_25.funcsel_PS_IO_25 = 14
	# 0xf8803064[3:0] = 14
	write 0xf8803064 0x0000000e
	# Config ETH0, PS IO 24->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_24.funcsel_PS_IO_24 = 14
	# 0xf8803060[3:0] = 14
	write 0xf8803060 0x0000000e
	# Config ETH0, PS IO 23->FUNCSEL: ETH0
	# register: FUNCSEL_PS_IO_23.funcsel_PS_IO_23 = 14
	# 0xf880305c[3:0] = 14
	write 0xf880305c 0x0000000e
	# Config GPIO_PS_IO0, PS IO 0->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_0.mc1_ensrc = 0x01
	# 0xf8803804[15:8] = 0x01
	# Config GPIO_PS_IO0, PS IO 0->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_0.mc1_ensnk = 0x1E
	# 0xf8803804[23:16] = 0x1E
	# Config v, PS IO 0->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_0.mc1_i_mode = 0x3
	# 0xf8803804[1:0] = 0x3
	write 0xf8803804 0x001e0103
	# Config GPIO_PS_IO7, PS IO 7->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_7.mc1_ensrc = 0x01
	# 0xf880383c[15:8] = 0x01
	# Config GPIO_PS_IO7, PS IO 7->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_7.mc1_ensnk = 0x1E
	# 0xf880383c[23:16] = 0x1E
	# Config v, PS IO 7->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_7.mc1_i_mode = 0x3
	# 0xf880383c[1:0] = 0x3
	write 0xf880383c 0x001e0103
	# Config GPIO_PS_IO8, PS IO 8->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_8.mc1_ensrc = 0x01
	# 0xf8803844[15:8] = 0x01
	# Config GPIO_PS_IO8, PS IO 8->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_8.mc1_ensnk = 0x1E
	# 0xf8803844[23:16] = 0x1E
	# Config v, PS IO 8->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_8.mc1_i_mode = 0x3
	# 0xf8803844[1:0] = 0x3
	write 0xf8803844 0x001e0103
	# Config GPIO_PS_IO9, PS IO 9->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_9.mc1_ensrc = 0x01
	# 0xf880384c[15:8] = 0x01
	# Config GPIO_PS_IO9, PS IO 9->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_9.mc1_ensnk = 0x1E
	# 0xf880384c[23:16] = 0x1E
	# Config v, PS IO 9->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_9.mc1_i_mode = 0x3
	# 0xf880384c[1:0] = 0x3
	write 0xf880384c 0x001e0103
	# Config GPIO_PS_IO46, PS IO 46->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_46.mc1_ensrc = 0x06
	# 0xf8803974[15:8] = 0x06
	# Config GPIO_PS_IO46, PS IO 46->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_46.mc1_ensnk = 0x1E
	# 0xf8803974[23:16] = 0x1E
	# Config v, PS IO 46->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_46.mc1_i_mode = 0x2
	# 0xf8803974[1:0] = 0x2
	write 0xf8803974 0x001e0602
	# Config GPIO_PS_IO50, PS IO 50->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_50.mc1_ensrc = 0x06
	# 0xf8803994[15:8] = 0x06
	# Config GPIO_PS_IO50, PS IO 50->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_50.mc1_ensnk = 0x1E
	# 0xf8803994[23:16] = 0x1E
	# Config v, PS IO 50->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_50.mc1_i_mode = 0x2
	# 0xf8803994[1:0] = 0x2
	write 0xf8803994 0x001e0602
	# Config GPIO_PS_IO51, PS IO 51->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_51.mc1_ensrc = 0x06
	# 0xf880399c[15:8] = 0x06
	# Config GPIO_PS_IO51, PS IO 51->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_51.mc1_ensnk = 0x1E
	# 0xf880399c[23:16] = 0x1E
	# Config v, PS IO 51->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_51.mc1_i_mode = 0x2
	# 0xf880399c[1:0] = 0x2
	write 0xf880399c 0x001e0602
	# Config GPIO_PS_IO0, PS IO 0->speed: slow
	# register: PARA0_PS_IO_0.speed = 0x0
	# 0xf8803800[2:0] = 0x0
	# Config GPIO_PS_IO0, PS IO 0->PullType: pullup 25k
	# register: PARA0_PS_IO_0.PullType = 0x8
	# 0xf8803800[31:28] = 0x8
	write 0xf8803800 0x80000000
	# Config GPIO_PS_IO7, PS IO 7->speed: slow
	# register: PARA0_PS_IO_7.speed = 0x0
	# 0xf8803838[2:0] = 0x0
	# Config GPIO_PS_IO7, PS IO 7->PullType: pullup 25k
	# register: PARA0_PS_IO_7.PullType = 0x8
	# 0xf8803838[31:28] = 0x8
	write 0xf8803838 0x80000000
	# Config GPIO_PS_IO8, PS IO 8->speed: slow
	# register: PARA0_PS_IO_8.speed = 0x0
	# 0xf8803840[2:0] = 0x0
	# Config GPIO_PS_IO8, PS IO 8->PullType: pullup 25k
	# register: PARA0_PS_IO_8.PullType = 0x8
	# 0xf8803840[31:28] = 0x8
	write 0xf8803840 0x80000000
	# Config GPIO_PS_IO9, PS IO 9->speed: slow
	# register: PARA0_PS_IO_9.speed = 0x0
	# 0xf8803848[2:0] = 0x0
	# Config GPIO_PS_IO9, PS IO 9->PullType: pullup 25k
	# register: PARA0_PS_IO_9.PullType = 0x8
	# 0xf8803848[31:28] = 0x8
	write 0xf8803848 0x80000000
	# Config GPIO_PS_IO46, PS IO 46->speed: slow
	# register: PARA0_PS_IO_46.speed = 0x0
	# 0xf8803970[2:0] = 0x0
	# Config GPIO_PS_IO46, PS IO 46->PullType: pullup 25k
	# register: PARA0_PS_IO_46.PullType = 0x8
	# 0xf8803970[31:28] = 0x8
	write 0xf8803970 0x80000000
	# Config GPIO_PS_IO50, PS IO 50->speed: slow
	# register: PARA0_PS_IO_50.speed = 0x0
	# 0xf8803990[2:0] = 0x0
	# Config GPIO_PS_IO50, PS IO 50->PullType: pullup 25k
	# register: PARA0_PS_IO_50.PullType = 0x8
	# 0xf8803990[31:28] = 0x8
	write 0xf8803990 0x80000000
	# Config GPIO_PS_IO51, PS IO 51->speed: slow
	# register: PARA0_PS_IO_51.speed = 0x0
	# 0xf8803998[2:0] = 0x0
	# Config GPIO_PS_IO51, PS IO 51->PullType: pullup 25k
	# register: PARA0_PS_IO_51.PullType = 0x8
	# 0xf8803998[31:28] = 0x8
	write 0xf8803998 0x80000000
	# Config GPIO, PS IO 0->FUNCSEL: GPIO
	# register: FUNCSEL_PS_IO_0.funcsel_PS_IO_0 = 4
	# 0xf8803000[3:0] = 4
	write 0xf8803000 0x00000004
	# Config GPIO, PS IO 7->FUNCSEL: GPIO
	# register: FUNCSEL_PS_IO_7.funcsel_PS_IO_7 = 4
	# 0xf880301c[3:0] = 4
	write 0xf880301c 0x00000004
	# Config GPIO, PS IO 8->FUNCSEL: GPIO
	# register: FUNCSEL_PS_IO_8.funcsel_PS_IO_8 = 4
	# 0xf8803020[3:0] = 4
	write 0xf8803020 0x00000004
	# Config GPIO, PS IO 9->FUNCSEL: GPIO
	# register: FUNCSEL_PS_IO_9.funcsel_PS_IO_9 = 4
	# 0xf8803024[3:0] = 4
	write 0xf8803024 0x00000004
	# Config GPIO, PS IO 46->FUNCSEL: GPIO
	# register: FUNCSEL_PS_IO_46.funcsel_PS_IO_46 = 4
	# 0xf88030b8[3:0] = 4
	write 0xf88030b8 0x00000004
	# Config GPIO, PS IO 50->FUNCSEL: GPIO
	# register: FUNCSEL_PS_IO_50.funcsel_PS_IO_50 = 4
	# 0xf88030c8[3:0] = 4
	write 0xf88030c8 0x00000004
	# Config GPIO, PS IO 51->FUNCSEL: GPIO
	# register: FUNCSEL_PS_IO_51.funcsel_PS_IO_51 = 4
	# 0xf88030cc[3:0] = 4
	write 0xf88030cc 0x00000004
	# Config ETH0_mdc, PS IO 52->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_52.mc1_ensrc = 0x15
	# 0xf88039a4[15:8] = 0x15
	# Config ETH0_mdc, PS IO 52->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_52.mc1_ensnk = 0x17
	# 0xf88039a4[23:16] = 0x17
	# Config v, PS IO 52->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_52.mc1_i_mode = 0x2
	# 0xf88039a4[1:0] = 0x2
	write 0xf88039a4 0x00171502
	# Config ETH0_mdio, PS IO 53->Single-ended pull up Drive Strength: 16
	# register: PARA1_PS_IO_53.mc1_ensrc = 0x15
	# 0xf88039ac[15:8] = 0x15
	# Config ETH0_mdio, PS IO 53->Single-ended pull down Drive Strength: 16
	# register: PARA1_PS_IO_53.mc1_ensnk = 0x17
	# 0xf88039ac[23:16] = 0x17
	# Config v, PS IO 53->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_53.mc1_i_mode = 0x2
	# 0xf88039ac[1:0] = 0x2
	write 0xf88039ac 0x00171502
	# Config ETH0_mdc, PS IO 52->speed: fast
	# register: PARA0_PS_IO_52.speed = 0x7
	# 0xf88039a0[2:0] = 0x7
	# Config ETH0_mdc, PS IO 52->PullType: pullup 25k
	# register: PARA0_PS_IO_52.PullType = 0x8
	# 0xf88039a0[31:28] = 0x8
	# Config v, PS IO 52->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_52.inhys = 0x8
	# 0xf88039a0[27:24] = 0x8
	write 0xf88039a0 0x88000007
	# Config ETH0_mdio, PS IO 53->speed: fast
	# register: PARA0_PS_IO_53.speed = 0x7
	# 0xf88039a8[2:0] = 0x7
	# Config ETH0_mdio, PS IO 53->PullType: pullup 25k
	# register: PARA0_PS_IO_53.PullType = 0x8
	# 0xf88039a8[31:28] = 0x8
	# Config v, PS IO 53->inhys: LVCMOS 1.8V
	# register: PARA0_PS_IO_53.inhys = 0x8
	# 0xf88039a8[27:24] = 0x8
	write 0xf88039a8 0x88000007
	# Config MDIO0, PS IO 52->FUNCSEL: MDIO0
	# register: FUNCSEL_PS_IO_52.funcsel_PS_IO_52 = 14
	# 0xf88030d0[3:0] = 14
	write 0xf88030d0 0x0000000e
	# Config MDIO0, PS IO 53->FUNCSEL: MDIO0
	# register: FUNCSEL_PS_IO_53.funcsel_PS_IO_53 = 14
	# 0xf88030d4[3:0] = 14
	write 0xf88030d4 0x0000000e
	# Config qspi_ss0_n, PS IO 1->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_1.mc1_ensrc = 0x01
	# 0xf880380c[15:8] = 0x01
	# Config qspi_ss0_n, PS IO 1->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_1.mc1_ensnk = 0x1E
	# 0xf880380c[23:16] = 0x1E
	# Config v, PS IO 1->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_1.mc1_i_mode = 0x3
	# 0xf880380c[1:0] = 0x3
	write 0xf880380c 0x001e0103
	# Config qspi_clk, PS IO 6->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_6.mc1_ensrc = 0x01
	# 0xf8803834[15:8] = 0x01
	# Config qspi_clk, PS IO 6->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_6.mc1_ensnk = 0x1E
	# 0xf8803834[23:16] = 0x1E
	# Config v, PS IO 6->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_6.mc1_i_mode = 0x3
	# 0xf8803834[1:0] = 0x3
	write 0xf8803834 0x001e0103
	# Config qspi_dq0, PS IO 2->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_2.mc1_ensrc = 0x01
	# 0xf8803814[15:8] = 0x01
	# Config qspi_dq0, PS IO 2->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_2.mc1_ensnk = 0x1E
	# 0xf8803814[23:16] = 0x1E
	# Config v, PS IO 2->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_2.mc1_i_mode = 0x3
	# 0xf8803814[1:0] = 0x3
	write 0xf8803814 0x001e0103
	# Config qspi_dq1, PS IO 3->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_3.mc1_ensrc = 0x01
	# 0xf880381c[15:8] = 0x01
	# Config qspi_dq1, PS IO 3->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_3.mc1_ensnk = 0x1E
	# 0xf880381c[23:16] = 0x1E
	# Config v, PS IO 3->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_3.mc1_i_mode = 0x3
	# 0xf880381c[1:0] = 0x3
	write 0xf880381c 0x001e0103
	# Config qspi_dq2, PS IO 4->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_4.mc1_ensrc = 0x01
	# 0xf8803824[15:8] = 0x01
	# Config qspi_dq2, PS IO 4->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_4.mc1_ensnk = 0x1E
	# 0xf8803824[23:16] = 0x1E
	# Config v, PS IO 4->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_4.mc1_i_mode = 0x3
	# 0xf8803824[1:0] = 0x3
	write 0xf8803824 0x001e0103
	# Config qspi_dq3, PS IO 5->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_5.mc1_ensrc = 0x01
	# 0xf880382c[15:8] = 0x01
	# Config qspi_dq3, PS IO 5->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_5.mc1_ensnk = 0x1E
	# 0xf880382c[23:16] = 0x1E
	# Config v, PS IO 5->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_5.mc1_i_mode = 0x3
	# 0xf880382c[1:0] = 0x3
	write 0xf880382c 0x001e0103
	# Config qspi_ss0_n, PS IO 1->speed: fast
	# register: PARA0_PS_IO_1.speed = 0x7
	# 0xf8803808[2:0] = 0x7
	# Config qspi_ss0_n, PS IO 1->PullType: pullup 25k
	# register: PARA0_PS_IO_1.PullType = 0x8
	# 0xf8803808[31:28] = 0x8
	write 0xf8803808 0x80000007
	# Config qspi_clk, PS IO 6->speed: fast
	# register: PARA0_PS_IO_6.speed = 0x7
	# 0xf8803830[2:0] = 0x7
	# Config qspi_clk, PS IO 6->PullType: pullup 25k
	# register: PARA0_PS_IO_6.PullType = 0x8
	# 0xf8803830[31:28] = 0x8
	write 0xf8803830 0x80000007
	# Config qspi_dq0, PS IO 2->speed: fast
	# register: PARA0_PS_IO_2.speed = 0x7
	# 0xf8803810[2:0] = 0x7
	# Config qspi_dq0, PS IO 2->PullType: pullup 25k
	# register: PARA0_PS_IO_2.PullType = 0x8
	# 0xf8803810[31:28] = 0x8
	write 0xf8803810 0x80000007
	# Config qspi_dq1, PS IO 3->speed: fast
	# register: PARA0_PS_IO_3.speed = 0x7
	# 0xf8803818[2:0] = 0x7
	# Config qspi_dq1, PS IO 3->PullType: pullup 25k
	# register: PARA0_PS_IO_3.PullType = 0x8
	# 0xf8803818[31:28] = 0x8
	write 0xf8803818 0x80000007
	# Config qspi_dq2, PS IO 4->speed: fast
	# register: PARA0_PS_IO_4.speed = 0x7
	# 0xf8803820[2:0] = 0x7
	# Config qspi_dq2, PS IO 4->PullType: pullup 25k
	# register: PARA0_PS_IO_4.PullType = 0x8
	# 0xf8803820[31:28] = 0x8
	write 0xf8803820 0x80000007
	# Config qspi_dq3, PS IO 5->speed: fast
	# register: PARA0_PS_IO_5.speed = 0x7
	# 0xf8803828[2:0] = 0x7
	# Config qspi_dq3, PS IO 5->PullType: pullup 25k
	# register: PARA0_PS_IO_5.PullType = 0x8
	# 0xf8803828[31:28] = 0x8
	write 0xf8803828 0x80000007
	# Config qspi_ss1_n_Dot_Enable, PS IO 1->FUNCSEL: Quad_SPI_Flash
	# register: FUNCSEL_PS_IO_1.funcsel_PS_IO_1 = 0x0
	# 0xf8803004[3:0] = 0x0
	write 0xf8803004 0x00000000
	# Config qspi_ss1_n_Dot_Enable, PS IO 6->FUNCSEL: Quad_SPI_Flash
	# register: FUNCSEL_PS_IO_6.funcsel_PS_IO_6 = 0x0
	# 0xf8803018[3:0] = 0x0
	write 0xf8803018 0x00000000
	# Config qspi_ss1_n_Dot_Enable, PS IO 2->FUNCSEL: Quad_SPI_Flash
	# register: FUNCSEL_PS_IO_2.funcsel_PS_IO_2 = 0x0
	# 0xf8803008[3:0] = 0x0
	write 0xf8803008 0x00000000
	# Config qspi_ss1_n_Dot_Enable, PS IO 3->FUNCSEL: Quad_SPI_Flash
	# register: FUNCSEL_PS_IO_3.funcsel_PS_IO_3 = 0x0
	# 0xf880300c[3:0] = 0x0
	write 0xf880300c 0x00000000
	# Config qspi_ss1_n_Dot_Enable, PS IO 4->FUNCSEL: Quad_SPI_Flash
	# register: FUNCSEL_PS_IO_4.funcsel_PS_IO_4 = 0x0
	# 0xf8803010[3:0] = 0x0
	write 0xf8803010 0x00000000
	# Config qspi_ss1_n_Dot_Enable, PS IO 5->FUNCSEL: Quad_SPI_Flash
	# register: FUNCSEL_PS_IO_5.funcsel_PS_IO_5 = 0x0
	# 0xf8803014[3:0] = 0x0
	write 0xf8803014 0x00000000
	# Config SD0_clk, PS IO 40->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_40.mc1_ensrc = 0x06
	# 0xf8803944[15:8] = 0x06
	# Config SD0_clk, PS IO 40->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_40.mc1_ensnk = 0x1E
	# 0xf8803944[23:16] = 0x1E
	# Config v, PS IO 40->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_40.mc1_i_mode = 0x2
	# 0xf8803944[1:0] = 0x2
	write 0xf8803944 0x001e0602
	# Config SD0_cmd, PS IO 41->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_41.mc1_ensrc = 0x06
	# 0xf880394c[15:8] = 0x06
	# Config SD0_cmd, PS IO 41->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_41.mc1_ensnk = 0x1E
	# 0xf880394c[23:16] = 0x1E
	# Config v, PS IO 41->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_41.mc1_i_mode = 0x2
	# 0xf880394c[1:0] = 0x2
	write 0xf880394c 0x001e0602
	# Config SD0_d0, PS IO 42->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_42.mc1_ensrc = 0x06
	# 0xf8803954[15:8] = 0x06
	# Config SD0_d0, PS IO 42->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_42.mc1_ensnk = 0x1E
	# 0xf8803954[23:16] = 0x1E
	# Config v, PS IO 42->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_42.mc1_i_mode = 0x2
	# 0xf8803954[1:0] = 0x2
	write 0xf8803954 0x001e0602
	# Config SD0_d1, PS IO 43->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_43.mc1_ensrc = 0x06
	# 0xf880395c[15:8] = 0x06
	# Config SD0_d1, PS IO 43->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_43.mc1_ensnk = 0x1E
	# 0xf880395c[23:16] = 0x1E
	# Config v, PS IO 43->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_43.mc1_i_mode = 0x2
	# 0xf880395c[1:0] = 0x2
	write 0xf880395c 0x001e0602
	# Config SD0_d2, PS IO 44->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_44.mc1_ensrc = 0x06
	# 0xf8803964[15:8] = 0x06
	# Config SD0_d2, PS IO 44->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_44.mc1_ensnk = 0x1E
	# 0xf8803964[23:16] = 0x1E
	# Config v, PS IO 44->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_44.mc1_i_mode = 0x2
	# 0xf8803964[1:0] = 0x2
	write 0xf8803964 0x001e0602
	# Config SD0_d3, PS IO 45->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_45.mc1_ensrc = 0x06
	# 0xf880396c[15:8] = 0x06
	# Config SD0_d3, PS IO 45->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_45.mc1_ensnk = 0x1E
	# 0xf880396c[23:16] = 0x1E
	# Config v, PS IO 45->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_45.mc1_i_mode = 0x2
	# 0xf880396c[1:0] = 0x2
	write 0xf880396c 0x001e0602
	# Config SD0_clk, PS IO 40->speed: fast
	# register: PARA0_PS_IO_40.speed = 0x7
	# 0xf8803940[2:0] = 0x7
	# Config SD0_clk, PS IO 40->PullType: pullup 25k
	# register: PARA0_PS_IO_40.PullType = 0x8
	# 0xf8803940[31:28] = 0x8
	write 0xf8803940 0x80000007
	# Config SD0_cmd, PS IO 41->speed: fast
	# register: PARA0_PS_IO_41.speed = 0x7
	# 0xf8803948[2:0] = 0x7
	# Config SD0_cmd, PS IO 41->PullType: pullup 25k
	# register: PARA0_PS_IO_41.PullType = 0x8
	# 0xf8803948[31:28] = 0x8
	write 0xf8803948 0x80000007
	# Config SD0_d0, PS IO 42->speed: fast
	# register: PARA0_PS_IO_42.speed = 0x7
	# 0xf8803950[2:0] = 0x7
	# Config SD0_d0, PS IO 42->PullType: pullup 25k
	# register: PARA0_PS_IO_42.PullType = 0x8
	# 0xf8803950[31:28] = 0x8
	write 0xf8803950 0x80000007
	# Config SD0_d1, PS IO 43->speed: fast
	# register: PARA0_PS_IO_43.speed = 0x7
	# 0xf8803958[2:0] = 0x7
	# Config SD0_d1, PS IO 43->PullType: pullup 25k
	# register: PARA0_PS_IO_43.PullType = 0x8
	# 0xf8803958[31:28] = 0x8
	write 0xf8803958 0x80000007
	# Config SD0_d2, PS IO 44->speed: fast
	# register: PARA0_PS_IO_44.speed = 0x7
	# 0xf8803960[2:0] = 0x7
	# Config SD0_d2, PS IO 44->PullType: pullup 25k
	# register: PARA0_PS_IO_44.PullType = 0x8
	# 0xf8803960[31:28] = 0x8
	write 0xf8803960 0x80000007
	# Config SD0_d3, PS IO 45->speed: fast
	# register: PARA0_PS_IO_45.speed = 0x7
	# 0xf8803968[2:0] = 0x7
	# Config SD0_d3, PS IO 45->PullType: pullup 25k
	# register: PARA0_PS_IO_45.PullType = 0x8
	# 0xf8803968[31:28] = 0x8
	write 0xf8803968 0x80000007
	# Config SD0, PS IO 40->FUNCSEL: SD0
	# register: FUNCSEL_PS_IO_40.funcsel_PS_IO_40 = 10
	# 0xf88030a0[3:0] = 10
	write 0xf88030a0 0x0000000a
	# Config SD0, PS IO 41->FUNCSEL: SD0
	# register: FUNCSEL_PS_IO_41.funcsel_PS_IO_41 = 10
	# 0xf88030a4[3:0] = 10
	write 0xf88030a4 0x0000000a
	# Config SD0, PS IO 42->FUNCSEL: SD0
	# register: FUNCSEL_PS_IO_42.funcsel_PS_IO_42 = 10
	# 0xf88030a8[3:0] = 10
	write 0xf88030a8 0x0000000a
	# Config SD0, PS IO 43->FUNCSEL: SD0
	# register: FUNCSEL_PS_IO_43.funcsel_PS_IO_43 = 10
	# 0xf88030ac[3:0] = 10
	write 0xf88030ac 0x0000000a
	# Config SD0, PS IO 44->FUNCSEL: SD0
	# register: FUNCSEL_PS_IO_44.funcsel_PS_IO_44 = 10
	# 0xf88030b0[3:0] = 10
	write 0xf88030b0 0x0000000a
	# Config SD0, PS IO 45->FUNCSEL: SD0
	# register: FUNCSEL_PS_IO_45.funcsel_PS_IO_45 = 10
	# 0xf88030b4[3:0] = 10
	write 0xf88030b4 0x0000000a
	# Config SD0_cd, PS IO 47->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_47.mc1_ensrc = 0x06
	# 0xf880397c[15:8] = 0x06
	# Config SD0_cd, PS IO 47->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_47.mc1_ensnk = 0x1E
	# 0xf880397c[23:16] = 0x1E
	# Config v, PS IO 47->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_47.mc1_i_mode = 0x2
	# 0xf880397c[1:0] = 0x2
	write 0xf880397c 0x001e0602
	# Config SD0_cd, PS IO 47->speed: fast
	# register: PARA0_PS_IO_47.speed = 0x7
	# 0xf8803978[2:0] = 0x7
	# Config SD0_cd, PS IO 47->PullType: pullup 25k
	# register: PARA0_PS_IO_47.PullType = 0x8
	# 0xf8803978[31:28] = 0x8
	write 0xf8803978 0x80000007
	# Config SD0_cd_Dot_Type, PS IO 47->FUNCSEL: SD0_cd: GPIO
	# register: FUNCSEL_PS_IO_47.funcsel_PS_IO_47 = 0x4
	# 0xf88030bc[3:0] = 0x4
	write 0xf88030bc 0x00000004
	# Config SD1_clk, PS IO 12->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_12.mc1_ensrc = 0x01
	# 0xf8803864[15:8] = 0x01
	# Config SD1_clk, PS IO 12->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_12.mc1_ensnk = 0x1E
	# 0xf8803864[23:16] = 0x1E
	# Config v, PS IO 12->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_12.mc1_i_mode = 0x3
	# 0xf8803864[1:0] = 0x3
	write 0xf8803864 0x001e0103
	# Config SD1_cmd, PS IO 11->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_11.mc1_ensrc = 0x01
	# 0xf880385c[15:8] = 0x01
	# Config SD1_cmd, PS IO 11->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_11.mc1_ensnk = 0x1E
	# 0xf880385c[23:16] = 0x1E
	# Config v, PS IO 11->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_11.mc1_i_mode = 0x3
	# 0xf880385c[1:0] = 0x3
	write 0xf880385c 0x001e0103
	# Config SD1_d0, PS IO 10->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_10.mc1_ensrc = 0x01
	# 0xf8803854[15:8] = 0x01
	# Config SD1_d0, PS IO 10->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_10.mc1_ensnk = 0x1E
	# 0xf8803854[23:16] = 0x1E
	# Config v, PS IO 10->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_10.mc1_i_mode = 0x3
	# 0xf8803854[1:0] = 0x3
	write 0xf8803854 0x001e0103
	# Config SD1_d1, PS IO 13->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_13.mc1_ensrc = 0x01
	# 0xf880386c[15:8] = 0x01
	# Config SD1_d1, PS IO 13->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_13.mc1_ensnk = 0x1E
	# 0xf880386c[23:16] = 0x1E
	# Config v, PS IO 13->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_13.mc1_i_mode = 0x3
	# 0xf880386c[1:0] = 0x3
	write 0xf880386c 0x001e0103
	# Config SD1_d2, PS IO 14->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_14.mc1_ensrc = 0x01
	# 0xf8803874[15:8] = 0x01
	# Config SD1_d2, PS IO 14->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_14.mc1_ensnk = 0x1E
	# 0xf8803874[23:16] = 0x1E
	# Config v, PS IO 14->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_14.mc1_i_mode = 0x3
	# 0xf8803874[1:0] = 0x3
	write 0xf8803874 0x001e0103
	# Config SD1_d3, PS IO 15->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_15.mc1_ensrc = 0x01
	# 0xf880387c[15:8] = 0x01
	# Config SD1_d3, PS IO 15->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_15.mc1_ensnk = 0x1E
	# 0xf880387c[23:16] = 0x1E
	# Config v, PS IO 15->mc1_i_mode: LVCMOS 3.3V
	# register: PARA1_PS_IO_15.mc1_i_mode = 0x3
	# 0xf880387c[1:0] = 0x3
	write 0xf880387c 0x001e0103
	# Config SD1_clk, PS IO 12->speed: fast
	# register: PARA0_PS_IO_12.speed = 0x7
	# 0xf8803860[2:0] = 0x7
	# Config SD1_clk, PS IO 12->PullType: pullup 25k
	# register: PARA0_PS_IO_12.PullType = 0x8
	# 0xf8803860[31:28] = 0x8
	write 0xf8803860 0x80000007
	# Config SD1_cmd, PS IO 11->speed: fast
	# register: PARA0_PS_IO_11.speed = 0x7
	# 0xf8803858[2:0] = 0x7
	# Config SD1_cmd, PS IO 11->PullType: pullup 25k
	# register: PARA0_PS_IO_11.PullType = 0x8
	# 0xf8803858[31:28] = 0x8
	write 0xf8803858 0x80000007
	# Config SD1_d0, PS IO 10->speed: fast
	# register: PARA0_PS_IO_10.speed = 0x7
	# 0xf8803850[2:0] = 0x7
	# Config SD1_d0, PS IO 10->PullType: pullup 25k
	# register: PARA0_PS_IO_10.PullType = 0x8
	# 0xf8803850[31:28] = 0x8
	write 0xf8803850 0x80000007
	# Config SD1_d1, PS IO 13->speed: fast
	# register: PARA0_PS_IO_13.speed = 0x7
	# 0xf8803868[2:0] = 0x7
	# Config SD1_d1, PS IO 13->PullType: pullup 25k
	# register: PARA0_PS_IO_13.PullType = 0x8
	# 0xf8803868[31:28] = 0x8
	write 0xf8803868 0x80000007
	# Config SD1_d2, PS IO 14->speed: fast
	# register: PARA0_PS_IO_14.speed = 0x7
	# 0xf8803870[2:0] = 0x7
	# Config SD1_d2, PS IO 14->PullType: pullup 25k
	# register: PARA0_PS_IO_14.PullType = 0x8
	# 0xf8803870[31:28] = 0x8
	write 0xf8803870 0x80000007
	# Config SD1_d3, PS IO 15->speed: fast
	# register: PARA0_PS_IO_15.speed = 0x7
	# 0xf8803878[2:0] = 0x7
	# Config SD1_d3, PS IO 15->PullType: pullup 25k
	# register: PARA0_PS_IO_15.PullType = 0x8
	# 0xf8803878[31:28] = 0x8
	write 0xf8803878 0x80000007
	# Config SD1, PS IO 12->FUNCSEL: SD1
	# register: FUNCSEL_PS_IO_12.funcsel_PS_IO_12 = 10
	# 0xf8803030[3:0] = 10
	write 0xf8803030 0x0000000a
	# Config SD1, PS IO 11->FUNCSEL: SD1
	# register: FUNCSEL_PS_IO_11.funcsel_PS_IO_11 = 10
	# 0xf880302c[3:0] = 10
	write 0xf880302c 0x0000000a
	# Config SD1, PS IO 10->FUNCSEL: SD1
	# register: FUNCSEL_PS_IO_10.funcsel_PS_IO_10 = 10
	# 0xf8803028[3:0] = 10
	write 0xf8803028 0x0000000a
	# Config SD1, PS IO 13->FUNCSEL: SD1
	# register: FUNCSEL_PS_IO_13.funcsel_PS_IO_13 = 10
	# 0xf8803034[3:0] = 10
	write 0xf8803034 0x0000000a
	# Config SD1, PS IO 14->FUNCSEL: SD1
	# register: FUNCSEL_PS_IO_14.funcsel_PS_IO_14 = 10
	# 0xf8803038[3:0] = 10
	write 0xf8803038 0x0000000a
	# Config SD1, PS IO 15->FUNCSEL: SD1
	# register: FUNCSEL_PS_IO_15.funcsel_PS_IO_15 = 10
	# 0xf880303c[3:0] = 10
	write 0xf880303c 0x0000000a
	# Config UART1_tx, PS IO 48->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_48.mc1_ensrc = 0x06
	# 0xf8803984[15:8] = 0x06
	# Config UART1_tx, PS IO 48->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_48.mc1_ensnk = 0x1E
	# 0xf8803984[23:16] = 0x1E
	# Config v, PS IO 48->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_48.mc1_i_mode = 0x2
	# 0xf8803984[1:0] = 0x2
	write 0xf8803984 0x001e0602
	# Config UART1_rx, PS IO 49->Single-ended pull up Drive Strength: 8
	# register: PARA1_PS_IO_49.mc1_ensrc = 0x06
	# 0xf880398c[15:8] = 0x06
	# Config UART1_rx, PS IO 49->Single-ended pull down Drive Strength: 8
	# register: PARA1_PS_IO_49.mc1_ensnk = 0x1E
	# 0xf880398c[23:16] = 0x1E
	# Config v, PS IO 49->mc1_i_mode: LVCMOS 1.8V
	# register: PARA1_PS_IO_49.mc1_i_mode = 0x2
	# 0xf880398c[1:0] = 0x2
	write 0xf880398c 0x001e0602
	# Config UART1_tx, PS IO 48->speed: slow
	# register: PARA0_PS_IO_48.speed = 0x0
	# 0xf8803980[2:0] = 0x0
	# Config UART1_tx, PS IO 48->PullType: pullup 25k
	# register: PARA0_PS_IO_48.PullType = 0x8
	# 0xf8803980[31:28] = 0x8
	write 0xf8803980 0x80000000
	# Config UART1_rx, PS IO 49->speed: slow
	# register: PARA0_PS_IO_49.speed = 0x0
	# 0xf8803988[2:0] = 0x0
	# Config UART1_rx, PS IO 49->PullType: pullup 25k
	# register: PARA0_PS_IO_49.PullType = 0x8
	# 0xf8803988[31:28] = 0x8
	write 0xf8803988 0x80000000
	# Config UART1, PS IO 48->FUNCSEL: UART1
	# register: FUNCSEL_PS_IO_48.funcsel_PS_IO_48 = 3
	# 0xf88030c0[3:0] = 3
	write 0xf88030c0 0x00000003
	# Config UART1, PS IO 49->FUNCSEL: UART1
	# register: FUNCSEL_PS_IO_49.funcsel_PS_IO_49 = 3
	# 0xf88030c4[3:0] = 3
	write 0xf88030c4 0x00000003
	# Config MDIO0, Select IO: PS IO 52...53, IO selection: PS IO, as a default value
	# register: PL_IOSEL_13.PL_IOsel_13 = 1
	# 0xF8803434[0:0] = 1
	mask_write 0xF8803434 0x00000001 0x00000001

	# Config SD0, Select IO: PS IO 40...45, IO selection: PS IO, as a default value
	# register: PL_IOSEL_11.PL_IOsel_11 = 1
	# 0xF880342C[0:0] = 1
	mask_write 0xF880342C 0x00000001 0x00000001

	# Config SD1, Select IO: PS IO 10...15, IO selection: PS IO, as a default value
	# register: PL_IOSEL_12.PL_IOsel_12 = 1
	# 0xF8803430[0:0] = 1
	mask_write 0xF8803430 0x00000001 0x00000001

	# Config UART1, Select IO: PS IO 48...49, IO selection: PS IO, as a default value
	# register: PL_IOSEL_5.PL_IOsel_5 = 1
	# 0xF8803414[0:0] = 1
	mask_write 0xF8803414 0x00000001 0x00000001

}

# (2) config clock
proc config_clock { } {
	# Config clock source, cpu clock source :  cpu PLL
	# register: CLK_SEL.slow_sel = 1
	# 0xF8801040[4:4] = 1
	mask_write 0xF8801040 0x00000010 0x00000010

	# Config CRG_EN, cpu 4x div1: 4:2:1
	# register: CPU4X_DIV1_PARA.cpu4x_div1_para = 0xffffff
	# 0xF8801010[23:0] = 0xffffff
	mask_write 0xF8801010 0x00ffffff 0x00ffffff

	# Config CRG_EN, cpu 4x div2: 4:2:1
	# register: CPU4X_DIV2_PARA.cpu4x_div2_para = 0x555555
	# 0xF8801014[23:0] = 0x555555
	mask_write 0xF8801014 0x00ffffff 0x00555555

	# Config CRG_EN, cpu 4x div4: 4:2:1
	# register: CPU4X_DIV4_PARA.cpu4x_div4_para = 0x111111
	# 0xF8801018[23:0] = 0x111111
	mask_write 0xF8801018 0x00ffffff 0x00111111

	# Config clock source, cpu clock ratio, 0:421; 1:621
	# register: CLK_SEL.cpu6x4x_sel = 0x0
	# 0xF8801040[0:0] = 0x0
	mask_write 0xF8801040 0x00000001 0x00000000

	# Config clock source, rpu core clock source, 0: cpu4x, 1:cpu2x
	# register: CLK_SEL.rpu4x2x_sel = 0x0
	# 0xF8801040[5:5] = 0x0
	mask_write 0xF8801040 0x00000020 0x00000000

	# Config CPUPLL, cpu pll reset
	# register: CPUPLL_CTRL1.ctrl1_cpupll = 1
	# 0xF8801104[9:9] = 1
	mask_write 0xF8801104 0x00000200 0x00000200

	# Config CPUPLL, CPU N: 120, mc1_fbk_div: 119
	# register: CPUPLL_CTRL9.ctrl9_cpupll = 0x00000077
	# 0xF8801124[6:0] = 0x00000077
	mask_write 0xF8801124 0x0000007f 0x00000077

	# Config CPUPLL, mc1_kvco_sel: 0
	# register: CPUPLL_CTRL9.ctrl9_cpupll = 0x00000000
	# 0xF8801124[13:12] = 0x00000000
	mask_write 0xF8801124 0x00003000 0x00000000

	# Config CPUPLL, mc1_gm_prog: 1
	# register: CPUPLL_CTRL9.ctrl9_cpupll = 0x00000001
	# 0xF8801124[26:24] = 0x00000001
	mask_write 0xF8801124 0x07000000 0x01000000

	# Config CPUPLL, CPU M: 2, mc1_ref_div: 1
	# register: CPUPLL_CTRL8.ctrl8_cpupll = 0x00000001
	# 0xF8801120[6:0] = 0x00000001
	mask_write 0xF8801120 0x0000007f 0x00000001

	# Config CPUPLL, mc1_icp_sel: 10
	# register: CPUPLL_CTRL8.ctrl8_cpupll = 0x0000000a
	# 0xF8801120[20:16] = 0x0000000a
	mask_write 0xF8801120 0x001f0000 0x000a0000

	# Config CPUPLL, mc1_lpf_cap: 2
	# register: CPUPLL_CTRL8.ctrl8_cpupll = 0x00000002
	# 0xF8801120[27:26] = 0x00000002
	mask_write 0xF8801120 0x0c000000 0x08000000

	# Config CPUPLL, mc1_lpf_res: 4
	# register: CPUPLL_CTRL8.ctrl8_cpupll = 0x00000004
	# 0xF8801120[30:28] = 0x00000004
	mask_write 0xF8801120 0x70000000 0x40000000

	# Config CPUPLL, CPU C: 2, mc1_divc1: 1
	# register: CPUPLL_CTRL19.ctrl19_cpupll = 0x00000001
	# 0xF880114C[30:24] = 0x00000001
	mask_write 0xF880114C 0x7f000000 0x01000000

	# Config CPUPLL, CPU C: 2, mc1_duty1: 1
	# register: CPUPLL_CTRL19.ctrl19_cpupll = 0x00000001
	# 0xF880114C[6:0] = 0x00000001
	mask_write 0xF880114C 0x0000007f 0x00000001

	# Config CPUPLL, CPU C: 2, mc1_divc0: 1
	# register: CPUPLL_CTRL18.ctrl18_cpupll = 0x00000001
	# 0xF8801148[30:24] = 0x00000001
	mask_write 0xF8801148 0x7f000000 0x01000000

	# Config CPUPLL, CPU C: 2, mc1_duty0: 1
	# register: CPUPLL_CTRL18.ctrl18_cpupll = 0x00000001
	# 0xF8801148[6:0] = 0x00000001
	mask_write 0xF8801148 0x0000007f 0x00000001

	# Config CPUPLL, cpu pll release
	# register: CPUPLL_CTRL1.ctrl1_cpupll = 0
	# 0xF8801104[9:9] = 0
	mask_write 0xF8801104 0x00000200 0x00000000

	# Config IOPLL, io pll reset
	# register: IOPLL_CTRL1.ctrl1_iopll = 1
	# 0xF8801204[9:9] = 1
	mask_write 0xF8801204 0x00000200 0x00000200

	# Config IOPLL, IO N: 120, mc1_fbk_div: 119
	# register: IOPLL_CTRL9.ctrl9_iopll = 0x00000077
	# 0xF8801224[6:0] = 0x00000077
	mask_write 0xF8801224 0x0000007f 0x00000077

	# Config IOPLL, mc1_kvco_sel: 0
	# register: IOPLL_CTRL9.ctrl9_iopll = 0x00000000
	# 0xF8801224[13:12] = 0x00000000
	mask_write 0xF8801224 0x00003000 0x00000000

	# Config IOPLL, mc1_gm_prog: 1
	# register: IOPLL_CTRL9.ctrl9_iopll = 0x00000001
	# 0xF8801224[26:24] = 0x00000001
	mask_write 0xF8801224 0x07000000 0x01000000

	# Config IOPLL, IO M: 2, mc1_ref_div: 1
	# register: IOPLL_CTRL8.ctrl8_iopll = 0x00000001
	# 0xF8801220[6:0] = 0x00000001
	mask_write 0xF8801220 0x0000007f 0x00000001

	# Config IOPLL, mc1_icp_sel: 10
	# register: IOPLL_CTRL8.ctrl8_iopll = 0x0000000a
	# 0xF8801220[20:16] = 0x0000000a
	mask_write 0xF8801220 0x001f0000 0x000a0000

	# Config IOPLL, mc1_lpf_cap: 2
	# register: IOPLL_CTRL8.ctrl8_iopll = 0x00000002
	# 0xF8801220[27:26] = 0x00000002
	mask_write 0xF8801220 0x0c000000 0x08000000

	# Config IOPLL, mc1_lpf_res: 4
	# register: IOPLL_CTRL8.ctrl8_iopll = 0x00000004
	# 0xF8801220[30:28] = 0x00000004
	mask_write 0xF8801220 0x70000000 0x40000000

	# Config IOPLL, IO1000 C: 2, mc1_divc0: 1
	# register: IOPLL_CTRL18.ctrl18_iopll = 0x00000001
	# 0xF8801248[30:24] = 0x00000001
	mask_write 0xF8801248 0x7f000000 0x01000000

	# Config IOPLL, IO1000 C: 2, mc1_duty0: 1
	# register: IOPLL_CTRL18.ctrl18_iopll = 0x00000001
	# 0xF8801248[6:0] = 0x00000001
	mask_write 0xF8801248 0x0000007f 0x00000001

	# Config IOPLL, IO400 C: 5, mc1_divc1: 4
	# register: IOPLL_CTRL19.ctrl19_iopll = 0x00000004
	# 0xF880124c[30:24] = 0x00000004
	mask_write 0xF880124c 0x7f000000 0x04000000

	# Config IOPLL, IO400 C: 5, mc1_duty1: 3
	# register: IOPLL_CTRL19.ctrl19_iopll = 0x00000003
	# 0xF880124c[6:0] = 0x00000003
	mask_write 0xF880124c 0x0000007f 0x00000003

	# Config IOPLL, IO25 C: 80, mc1_divc2: 79
	# register: IOPLL_CTRL20.ctrl20_iopll = 0x0000004f
	# 0xF8801250[30:24] = 0x0000004f
	mask_write 0xF8801250 0x7f000000 0x4f000000

	# Config IOPLL, IO25 C: 80, mc1_duty2: 40
	# register: IOPLL_CTRL20.ctrl20_iopll = 0x00000028
	# 0xF8801250[6:0] = 0x00000028
	mask_write 0xF8801250 0x0000007f 0x00000028

	# Config IOPLL, IO80 C: 25, mc1_divc3: 24
	# register: IOPLL_CTRL21.ctrl21_iopll = 0x00000018
	# 0xF8801254[30:24] = 0x00000018
	mask_write 0xF8801254 0x7f000000 0x18000000

	# Config IOPLL, IO80 C: 25, mc1_duty3: 13
	# register: IOPLL_CTRL21.ctrl21_iopll = 0x0000000d
	# 0xF8801254[6:0] = 0x0000000d
	mask_write 0xF8801254 0x0000007f 0x0000000d

	# Config p2f_clk0, system div para for fclk0: 8, based on IO400
	# register: FCLK_CNT_DIV.div_fclk0 = 0x00000007
	# 0xF880103C[5:0] = 0x00000007
	mask_write 0xF880103C 0x0000003f 0x00000007

	# Config QSPI IP Clock, system div para for qspi:50,Clock source IO_1000
	# register: IO1000_CNT_DIV.div_qspi = 0x00000031
	# 0xF8801030[5:0] = 0x00000031
	mask_write 0xF8801030 0x0000003f 0x00000031

	# Config SDIO IP Clock, system div para for sdio:1, clock source: IO_400
	# register: IO1000_CNT_DIV.div_sdio = 0x00000000
	# 0xF8801030[29:24] = 0x00000000
	mask_write 0xF8801030 0x3f000000 0x00000000

	# Config UART IP clock, set uart clock divider. Clock source IO_400
	# register: IO400_DIV8_PARA.io400_div8_para = 0xffffffff
	# 0xF8801028[31:0] = 0xffffffff
	mask_write 0xF8801028 0xffffffff 0xffffffff

	# Config IOPLL, io pll release
	# register: IOPLL_CTRL1.ctrl1_iopll = 0
	# 0xF8801204[9:9] = 0
	mask_write 0xF8801204 0x00000200 0x00000000

	# Config CPUPLL, CPU PLL WaitLock
	# register: CPUPLL_STATE0.state0_cpupll = 1
	# 0xF8801180[0:0] = 1
	mask_poll 0xF8801180 0x00000001 0x00000001

	# Config IOPLL, IO PLL WaitLock
	# register: IOPLL_STATE0.state0_iopll = 1
	# 0xF8801280[0:0] = 1
	mask_poll 0xF8801280 0x00000001 0x00000001

	# Config clock source, cpu clock source : PLL CLK, pll enable
	# register: CLK_SEL.slow_sel = 0
	# 0xF8801040[4:4] = 0
	mask_write 0xF8801040 0x00000010 0x00000000

}

# (3) config ps_pl
proc config_ps_pl { } {
	# Config PLS_PROT, gp normal acess to pl
	# register: PLS_PROT.gp_proten = 0x0
	# 0xF8800080[1:1] = 0x0
	mask_write 0xF8800080 0x00000002 0x00000000

}

# (5) config peripheral
proc config_peripheral { } {
	# Config ETH0, select ptp clk source: 0:internal 100M clk; 1:external PL_IO clk
	# register: CFG_CTRL_GBE0.ctrl_gbe0 = 0x0
	# 0xf8800140[15:15] = 0x0
	mask_write 0xf8800140 0x00008000 0x00000000

	# Config ETH0, select MII  clock: 0:internal tx clk; 1:external PL_IO clk
	# register: CFG_CTRL_GBE0.ctrl_gbe0 = 0x0
	# 0xf8800140[14:14] = 0x0
	mask_write 0xf8800140 0x00004000 0x00000000

	# Config ETH0, selects the tx phase: 2'b00: 0 phase; 2'b01:90 phase; 2'b10:180 phase; 2'b11:270 phase
	# register: CFG_CTRL_GBE0.ctrl_gbe0 = 0x0
	# 0xf8800140[7:6] = 0x0
	mask_write 0xf8800140 0x000000c0 0x00000000

	# Config ETH0, set gbe0：[5:4]: 01,plio;10,psio. [3:3]: 0:little endian; 1:big endian; default: 0. [2:0]: 000:GMII/MII; 001:RGMII; 100: RMII
	# register: CFG_CTRL_GBE0.ctrl_gbe0 = 0x21
	# 0xf8800140[5:0] = 0x21
	mask_write 0xf8800140 0x0000003f 0x00000021

}

# (6) config debug
proc config_debug { } {
}

proc ddr_init { } {
	set DFISTAT [expr {[mrw 0xf84211bc] & 0x1}]
	set STAT	[expr {[mrw 0xf8421004] & 0x7}]

	if {($DFISTAT == 1) && ($STAT != 0)} {
		puts "info : Config DDR, Skip, DDR is ready."
	} else {
		puts "info : Config DDR register"
		if {[file exists  $::env(IDE_ROOT_PATH)/tools/data/dr1m90_ddr_init.elf]} {
			load_image $::env(IDE_ROOT_PATH)/tools/data/dr1m90_ddr_init.elf
		} elseif {[file exists  $::env(IDE_ROOT_PATH)/tools/data/soc_aarch64_90_ddr_init.elf]} {
			load_image $::env(IDE_ROOT_PATH)/tools/data/soc_aarch64_90_ddr_init.elf
		} else {
			puts "Error : cannot find ddr_init.elf file"
			return
		}
		mww 0x61030000 $::p_osc_clk
		mww 0x61030004 $::p_type
		mww 0x61030008 $::p_speed
		mww 0x6103000c $::p_dq_width 
		mww 0x61030010 $::p_io_vol  
		mww 0x61030014 $::p_verf
		mww 0x61030018 $::p_pzq
		mww 0x6103001c $::p_dram_width
		mww 0x61030020 $::p_speed_bin_index
		mww 0x61030024 $::p_wdbi
		mww 0x61030028 $::p_rdbi
		mww 0x6103002c $::p_dram_density
		mww 0x61030030 $::p_ecc
		mww 0x61030034 $::p_addr_map
		mww 0x61030038 $::p_training
		mww 0x6103003c $::p_byte0_ac_dely
		mww 0x61030040 $::p_byte0_dqs_dely
		mww 0x61030044 $::p_byte1_ac_dely
		mww 0x61030048 $::p_byte1_dqs_dely
		mww 0x6103004c $::p_byte2_ac_dely
		mww 0x61030050 $::p_byte2_dqs_dely
		mww 0x61030054 $::p_byte3_ac_dely
		mww 0x61030058 $::p_byte3_dqs_dely
		mww 0x6103005c $::p_ddr_dram_drv
		mww 0x61030060 $::p_ddr_dram_odt
		mww 0x61030064 $::p_ddr_host_drv_for_ac
		mww 0x61030068 $::p_ddr_host_drv_for_dx
		mww 0x6103006c $::p_ddr_host_odt_for_dx
		mww 0x61030070 $::p_arch

		resume 0x61000000
		wait_ddr_init
	}
}
# config ddr using elf end <--

proc ddr_init_v2 { } {
    DDRC_CONFIG_FIELD_WRITE 0xf8420004 0x00000001 0 0x0
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8420120]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x7C1F0000 16 0x480A
    DDRC_CONFIG_FULL_WRITE 0xf8420120 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8420124]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07003000 12 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8420124 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8420104 0x00000200 9 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8420120 0x0000007f 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8420124 0x0000007f 0 0x4f
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8420148]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x7F00007F 0 0x1000001
    DDRC_CONFIG_FULL_WRITE 0xf8420148 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf842014c]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x7F00007F 0 0x3000002
    DDRC_CONFIG_FULL_WRITE 0xf842014c $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8420150]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x7F00007F 0 0x1000001
    DDRC_CONFIG_FULL_WRITE 0xf8420150 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8420154]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x7F00007F 0 0x3000002
    DDRC_CONFIG_FULL_WRITE 0xf8420154 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8420104 0x00000200 9 0x0
    DDRC_CONFIG_FIELD_WAIT 0xf8420180 0x00000001 0 0x1 -1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf842080c]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00003FC2 1 0x13E0
    DDRC_CONFIG_FULL_WRITE 0xf842080c $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf842083c]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00003FC2 1 0x13E0
    DDRC_CONFIG_FULL_WRITE 0xf842083c $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf842080c 0x00000001 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf842083c 0x00000001 0 0x0
    DDRC_CONFIG_FIELD_WAIT 0xf8420810 0x00000001 0 0x1 -1
    DDRC_CONFIG_FIELD_WAIT 0xf8420840 0x00000001 0 0x1 -1
    DDRC_CONFIG_FIELD_WRITE 0xf8420004 0x00000001 0 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf84230a4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf84238a4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf84230a8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf84238a8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423898 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423094]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf8423094 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423894]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423894 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf84230f4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf84238f4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf84230f8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf84238f8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf84238e8 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84230e4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf84230e4 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84238e4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf84238e4 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423144 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423944 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423148 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423948 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423938 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423134]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf8423134 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423934]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423934 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423194 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423994 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423198 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423998 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423988 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423184]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf8423184 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423984]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423984 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf84231e4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf84239e4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf84231e8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf84239e8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf84239d8 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84231d4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf84231d4 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84239d4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf84239d4 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423234 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423a34 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423238 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423a38 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423a28 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423224]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf8423224 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423a24]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423a24 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423284 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423a84 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423288 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423a88 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423a78 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423274]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf8423274 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423a74]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423a74 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf84232d4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423ad4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf84232d8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423ad8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423ac8 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84232c4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf84232c4 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423ac4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423ac4 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423324 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423b24 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423328 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423b28 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423b18 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423314]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf8423314 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423b14]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423b14 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423374 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423b74 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423378 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423b78 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423b68 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423364]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf8423364 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423b64]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423b64 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf84233c4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423bc4 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf84233c8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423bc8 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423bb8 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84233b4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf84233b4 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423bb4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423bb4 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423414 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423c14 0x00000fff 0 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423418 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423c18 0x0000ff00 8 0xff
    DDRC_CONFIG_FIELD_WRITE 0xf8423c08 0x0000ff00 8 0x55
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423404]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55FF
    DDRC_CONFIG_FULL_WRITE 0xf8423404 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423c04]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF0000 16 0x55AA
    DDRC_CONFIG_FULL_WRITE 0xf8423c04 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf84238d0 0x00000fff 0 0xc80
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84238e4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFF00FFFF 0 0xEE009100
    DDRC_CONFIG_FULL_WRITE 0xf84238e4 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423c88 0x0000000f 0 0xc
    DDRC_CONFIG_FIELD_WRITE 0xf84239c0 0x00000fff 0 0xc80
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84239d4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFF00FFFF 0 0xEE009100
    DDRC_CONFIG_FULL_WRITE 0xf84239d4 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423c94 0x0000000f 0 0xc
    DDRC_CONFIG_FIELD_WRITE 0xf8423ab0 0x00000fff 0 0xc80
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423ac4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFF00FFFF 0 0xEE009100
    DDRC_CONFIG_FULL_WRITE 0xf8423ac4 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423ca0 0x0000000f 0 0xc
    DDRC_CONFIG_FIELD_WRITE 0xf8423ba0 0x00000fff 0 0xc80
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423bb4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFF00FFFF 0 0xEE009100
    DDRC_CONFIG_FULL_WRITE 0xf8423bb4 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8423cac 0x0000000f 0 0xc
    DDRC_CONFIG_FIELD_WRITE 0xf8423348 0xf0000000 28 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8423850 0x00008000 15 0x0
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423854]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x03800003 0 0x2000000
    DDRC_CONFIG_FULL_WRITE 0xf8423854 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf842b01c 0x00000007 0 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842b024 0x00000007 0 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842b02c 0x00000007 0 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842c020 0x00007000 12 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842c028 0x00007000 12 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842c030 0x00007000 12 0x2
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423000]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0003FFFF 0 0x25555
    DDRC_CONFIG_FULL_WRITE 0xf8423000 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8423800 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFFFFFF 0 0x10101010
    DDRC_CONFIG_FULL_WRITE 0xf8423004 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8423010 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8423480 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8423804 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8423810 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8423c80 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423820]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x20200000 21 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8423820 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423828]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x20200000 21 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8423828 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423830]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x20200000 21 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8423830 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423838]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x20200000 21 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8423838 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf842b01c 0x00000007 0 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842b024 0x00000007 0 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842b02c 0x00000007 0 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842c020 0x00007000 12 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842c028 0x00007000 12 0x2
    DDRC_CONFIG_FIELD_WRITE 0xf842c030 0x00007000 12 0x2
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84238c4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFFFFFF 0 0x88998899
    DDRC_CONFIG_FULL_WRITE 0xf84238c4 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84239b4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFFFFFF 0 0x88998899
    DDRC_CONFIG_FULL_WRITE 0xf84239b4 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423aa4]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFFFFFF 0 0x88998899
    DDRC_CONFIG_FULL_WRITE 0xf8423aa4 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8423b94]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFFFFFF 0 0x88998899
    DDRC_CONFIG_FULL_WRITE 0xf8423b94 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421320 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf8421328 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf84211b0 0x00000051
    DDRC_CONFIG_FULL_WRITE 0xf8421304 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf8421030 0x00000001
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8421000]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xC0003411 0 0x80000401
    DDRC_CONFIG_FULL_WRITE 0xf8421000 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421010 0x40001010
    DDRC_CONFIG_FULL_WRITE 0xf8421014 0x00018954
    DDRC_CONFIG_FULL_WRITE 0xf842101c 0xcb918919
    DDRC_CONFIG_FULL_WRITE 0xf8421030 0x00000088
    DDRC_CONFIG_FULL_WRITE 0xf8421034 0x00080001
    DDRC_CONFIG_FULL_WRITE 0xf8421038 0x00410002
    DDRC_CONFIG_FULL_WRITE 0xf8421050 0x00c17020
    DDRC_CONFIG_FULL_WRITE 0xf8421060 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf8421064 0x00610068
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000006 1 0x3
    DDRC_CONFIG_FULL_WRITE 0xf84210c0 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0000000F 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8420008 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf842107c 0x00000300
    DDRC_CONFIG_FULL_WRITE 0xf84210b8 0x00000bd3
    DDRC_CONFIG_FULL_WRITE 0xf84210bc 0x0003ffff
    DDRC_CONFIG_FULL_WRITE 0xf8421374 0x0000010d
    DDRC_CONFIG_FULL_WRITE 0xf842137c 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf8421384 0x00000000
    set InstRegVal 0x40020003
    DDRC_CONFIG_FIELD_SET InstRegVal 0xC3FF0FFF 0 0x400F01F4
    DDRC_CONFIG_FULL_WRITE 0xf84210d0 $InstRegVal
    set InstRegVal 0x00030009
    DDRC_CONFIG_FIELD_SET InstRegVal 0x01FF0000 16 0xC8
    DDRC_CONFIG_FULL_WRITE 0xf84210d4 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84210dc]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFFFFFF 0 0xB400004
    DDRC_CONFIG_FULL_WRITE 0xf84210dc $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84210e0]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFFFFFF 0 0x100000
    DDRC_CONFIG_FULL_WRITE 0xf84210e0 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf84210e4 0x00110000
    DDRC_CONFIG_FULL_WRITE 0xf84210f0 0x00000010
    DDRC_CONFIG_FULL_WRITE 0xf8421180 0x01000040
    DDRC_CONFIG_FULL_WRITE 0xf8421184 0x00000070
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x7F3F7F3F 0 0xA0F160C
    DDRC_CONFIG_FULL_WRITE 0xf8421100 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x001F3F7F 0 0x30210
    DDRC_CONFIG_FULL_WRITE 0xf8421104 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x3F3F3F3F 0 0x4040408
    DDRC_CONFIG_FULL_WRITE 0xf8421108 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf842110c 0x0000400c
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x1F0F0F1F 0 0x4020305
    DDRC_CONFIG_FULL_WRITE 0xf8421110 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421114 0x05e20302
    DDRC_CONFIG_FULL_WRITE 0xf8421120 0x05050b0b
    DDRC_CONFIG_FULL_WRITE 0xf8421128 0x000f0e0d
    DDRC_CONFIG_FULL_WRITE 0xf842112c 0x0e060119
    DDRC_CONFIG_FULL_WRITE 0xf8421130 0x0c000008
    DDRC_CONFIG_FULL_WRITE 0xf842113c 0x00000000
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0FFF03FF 0 0x510057
    DDRC_CONFIG_FULL_WRITE 0xf8421064 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x1FFFBF3F 0 0x2848205
    DDRC_CONFIG_FULL_WRITE 0xf8421190 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421194 0x03070101
    DDRC_CONFIG_FULL_WRITE 0xf8421198 0x07007031
    DDRC_CONFIG_FULL_WRITE 0xf842119c 0x000000f1
    DDRC_CONFIG_FULL_WRITE 0xf84211a0 0x40400002
    DDRC_CONFIG_FULL_WRITE 0xf84211a4 0x003300e6
    DDRC_CONFIG_FULL_WRITE 0xf84211a8 0x80000000
    DDRC_CONFIG_FULL_WRITE 0xf84211b8 0x0000001e
    DDRC_CONFIG_FULL_WRITE 0xf84211c0 0x00000005
    DDRC_CONFIG_FULL_WRITE 0xf84211c4 0x2a000000
    DDRC_CONFIG_FIELD_WRITE 0xf8421060 0x00000002 1 0x1
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x003F3F3F 0 0x20202
    DDRC_CONFIG_FULL_WRITE 0xf8421204 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0F0F1F0F 0 0x3030000
    DDRC_CONFIG_FULL_WRITE 0xf8421208 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x1F1F1F1F 0 0x3030303
    DDRC_CONFIG_FULL_WRITE 0xf842120c $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00001F1F 0 0x1F1F
    DDRC_CONFIG_FULL_WRITE 0xf8421210 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0F0F0F0F 0 0x7070707
    DDRC_CONFIG_FULL_WRITE 0xf8421214 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0F0F0F0F 0 0xF070707
    DDRC_CONFIG_FULL_WRITE 0xf8421218 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000F0F 0 0xF0F
    DDRC_CONFIG_FULL_WRITE 0xf842121c $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00003F3F 0 0x3F3F
    DDRC_CONFIG_FULL_WRITE 0xf8421220 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421240 0x06000608
    DDRC_CONFIG_FULL_WRITE 0xf8421244 0x00000001
    set InstRegVal 0x00000001
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00001F00 8 0x1F
    DDRC_CONFIG_FULL_WRITE 0xf8421250 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421254 0x00000000
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFF00FFFF 0 0x8000040
    DDRC_CONFIG_FULL_WRITE 0xf842125c $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFF00FFFF 0 0x10000040
    DDRC_CONFIG_FULL_WRITE 0xf8421264 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFF00FFFF 0 0x10000040
    DDRC_CONFIG_FULL_WRITE 0xf842126c $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000111 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8421400 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x000073FF 0 0x70C8
    DDRC_CONFIG_FULL_WRITE 0xf8421404 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x000073FF 0 0x70C8
    DDRC_CONFIG_FULL_WRITE 0xf8421408 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421490 0x00000001
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0033000F 0 0x100007
    DDRC_CONFIG_FULL_WRITE 0xf8421494 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07FF07FF 0 0x640064
    DDRC_CONFIG_FULL_WRITE 0xf8421498 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x03330F0F 0 0x1100A05
    DDRC_CONFIG_FULL_WRITE 0xf842149c $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07FF07FF 0 0x640064
    DDRC_CONFIG_FULL_WRITE 0xf84214a0 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00006000 13 0x3
    DDRC_CONFIG_FULL_WRITE 0xf84214b4 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00006000 13 0x3
    DDRC_CONFIG_FULL_WRITE 0xf84214b8 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421540 0x00000001
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0033000F 0 0x100007
    DDRC_CONFIG_FULL_WRITE 0xf8421544 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07FF07FF 0 0x640064
    DDRC_CONFIG_FULL_WRITE 0xf8421548 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x03330F0F 0 0x1100A05
    DDRC_CONFIG_FULL_WRITE 0xf842154c $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07FF07FF 0 0x640064
    DDRC_CONFIG_FULL_WRITE 0xf8421550 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x000073FF 0 0x71F4
    DDRC_CONFIG_FULL_WRITE 0xf8421564 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x000073FF 0 0x71F4
    DDRC_CONFIG_FULL_WRITE 0xf8421568 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf84215f0 0x00000001
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0033000F 0 0x100007
    DDRC_CONFIG_FULL_WRITE 0xf84215f4 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07FF07FF 0 0x640064
    DDRC_CONFIG_FULL_WRITE 0xf84215f8 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x03330F0F 0 0x1100A05
    DDRC_CONFIG_FULL_WRITE 0xf84215fc $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07FF07FF 0 0x640064
    DDRC_CONFIG_FULL_WRITE 0xf8421600 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x000073FF 0 0x71F4
    DDRC_CONFIG_FULL_WRITE 0xf8421614 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x000073FF 0 0x71F4
    DDRC_CONFIG_FULL_WRITE 0xf8421618 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf84216a0 0x00000001
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0033000F 0 0x100007
    DDRC_CONFIG_FULL_WRITE 0xf84216a4 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07FF07FF 0 0x640064
    DDRC_CONFIG_FULL_WRITE 0xf84216a8 $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x03330F0F 0 0x1100A05
    DDRC_CONFIG_FULL_WRITE 0xf84216ac $InstRegVal
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x07FF07FF 0 0x640064
    DDRC_CONFIG_FULL_WRITE 0xf84216b0 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8421300 0x00000010
    DDRC_CONFIG_FULL_WRITE 0xf8421304 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf842130c 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf8421320 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf8421328 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf842136c 0x00110001
    set InstRegVal 0x00000000
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000051 0 0x50
    DDRC_CONFIG_FULL_WRITE 0xf84211b0 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8420804 0x00000001 0 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8420188 0x0000003f 0 0x16
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8420198]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0003FFFF 0 0x24655
    DDRC_CONFIG_FULL_WRITE 0xf8420198 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf842019c 0x0000003f 0 0x21
    DDRC_CONFIG_FIELD_WRITE 0xf84201a4 0x00000fc0 6 0x1a
    DDRC_CONFIG_FIELD_WRITE 0xf8422004 0x40000000 30 0x1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422014]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00008040 6 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8422014 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf842201c 0x01000000 24 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf842201c 0x00000018 3 0x0
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422090]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x02440F20 5 0x22079
    DDRC_CONFIG_FULL_WRITE 0xf8422090 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422100]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x18000007 0 0x8000003
    DDRC_CONFIG_FULL_WRITE 0xf8422100 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf842202c 0x80000000 31 0x1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422700]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x40000001
    DDRC_CONFIG_FULL_WRITE 0xf8422700 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422800]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x40000001
    DDRC_CONFIG_FULL_WRITE 0xf8422800 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422900]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x40000001
    DDRC_CONFIG_FULL_WRITE 0xf8422900 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422a00]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x40000001
    DDRC_CONFIG_FULL_WRITE 0xf8422a00 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422b00]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8422b00 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422c00]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8422c00 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422d00]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8422d00 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422e00]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8422e00 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422f00]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x40000001 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8422f00 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422724]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422724 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422824]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422824 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422924]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422924 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422a24]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422a24 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422b24]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422b24 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422c24]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422c24 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422d24]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422d24 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422e24]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422e24 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422f24]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000738 3 0x42
    DDRC_CONFIG_FULL_WRITE 0xf8422f24 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422204]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x1F7F0000 16 0xF31
    DDRC_CONFIG_FULL_WRITE 0xf8422204 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422014]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x0000E180 7 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8422014 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf842202c]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x02000020 5 0x0
    DDRC_CONFIG_FULL_WRITE 0xf842202c $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422024]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000CF0 4 0xC0
    DDRC_CONFIG_FULL_WRITE 0xf8422024 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422020]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00600000 21 0x3
    DDRC_CONFIG_FULL_WRITE 0xf8422020 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422028]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFF000000 24 0x14
    DDRC_CONFIG_FULL_WRITE 0xf8422028 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422030]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00E3FC00 10 0x8B5
    DDRC_CONFIG_FULL_WRITE 0xf8422030 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422048]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00007FFF 0 0x4E7F
    DDRC_CONFIG_FULL_WRITE 0xf8422048 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422080]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000031 0 0x31
    DDRC_CONFIG_FULL_WRITE 0xf8422080 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf842201c]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x06000000 25 0x0
    DDRC_CONFIG_FULL_WRITE 0xf842201c $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8422010 0x00002000 13 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8422090 0x00000008 3 0x0
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000061 0 0x61
    DDRC_CONFIG_FULL_WRITE 0xf8422004 $InstRegVal
    DDRC_CONFIG_FIELD_WAIT 0xf8422034 0x00000004 2 0x1 -1
    DDRC_CONFIG_FIELD_WAIT 0xf8422004 0x00000001 0 0x0 -1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84227a0]
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84228a0]
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf84229a0]
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422aa0]
    DDRC_CONFIG_REG_INFO 0xf8421000
    DDRC_CONFIG_REG_INFO 0xf8421064
    DDRC_CONFIG_REG_INFO 0xf8420120
    DDRC_CONFIG_REG_INFO 0xf8420124
    DDRC_CONFIG_REG_INFO 0xf8420148
    DDRC_CONFIG_REG_INFO 0xf84227a0
    DDRC_CONFIG_REG_INFO 0xf84228a0
    DDRC_CONFIG_REG_INFO 0xf84229a0
    DDRC_CONFIG_REG_INFO 0xf8422aa0
    DDRC_CONFIG_FIELD_WRITE 0xf8424040 0x00000001 0 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8424058 0x00000080 7 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8424008 0x17173232
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8424000]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x08010700 8 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8424000 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8424004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xC0000000 30 0x3
    DDRC_CONFIG_FULL_WRITE 0xf8424004 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8424018 0x17173232
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8424010]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x08010700 8 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8424010 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8424014]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xC0000000 30 0x3
    DDRC_CONFIG_FULL_WRITE 0xf8424014 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8424000 0x08000000 27 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8424010 0x08000000 27 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8426040 0x00000001 0 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8426058 0x00000080 7 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8426008 0x17173232
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8426000]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x08010700 8 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8426000 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8426004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xC0000000 30 0x3
    DDRC_CONFIG_FULL_WRITE 0xf8426004 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8426018 0x17173232
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8426010]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x08010700 8 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8426010 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8426014]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xC0000000 30 0x3
    DDRC_CONFIG_FULL_WRITE 0xf8426014 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8426000 0x08000000 27 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8426010 0x08000000 27 0x1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422040]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFFFFFF 0 0x2000410
    DDRC_CONFIG_FULL_WRITE 0xf8422040 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422044]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFFFF9FFF 0 0x8010
    DDRC_CONFIG_FULL_WRITE 0xf8422044 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422048]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xDFFFFFFF 0 0x84E7F
    DDRC_CONFIG_FULL_WRITE 0xf8422048 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf842204c]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x3FFFFFFF 0 0x18060000
    DDRC_CONFIG_FULL_WRITE 0xf842204c $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422050]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x1FFFFFFF 0 0x3230000
    DDRC_CONFIG_FULL_WRITE 0xf8422050 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422054]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xFCFFCFFF 0 0x206AC356
    DDRC_CONFIG_FULL_WRITE 0xf8422054 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422058]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00003FFF 0 0x14D8
    DDRC_CONFIG_FULL_WRITE 0xf8422058 $InstRegVal
    DDRC_CONFIG_FULL_WRITE 0xf8422180 0x00000b40
    DDRC_CONFIG_FULL_WRITE 0xf8422184 0x00000004
    DDRC_CONFIG_FULL_WRITE 0xf8422188 0x00000010
    DDRC_CONFIG_FULL_WRITE 0xf842218c 0x00000000
    DDRC_CONFIG_MRS_INFO 0x00000000 0x00000b40
    DDRC_CONFIG_MRS_INFO 0x00000001 0x00000004
    DDRC_CONFIG_MRS_INFO 0x00000002 0x00000010
    DDRC_CONFIG_MRS_INFO 0x00000003 0x00000000
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000181 0 0x181
    DDRC_CONFIG_FULL_WRITE 0xf8422004 $InstRegVal
    DDRC_CONFIG_FIELD_WAIT 0xf8422034 0x00000010 4 0x1 -1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422200]
    DDRC_CONFIG_FIELD_SET InstRegVal 0xF000F040 6 0x20000C1
    DDRC_CONFIG_FULL_WRITE 0xf8422200 $InstRegVal
    DDRC_CONFIG_FIELD_WRITE 0xf8422204 0x00000004 2 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8422088 0x00400000 22 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8422644 0x000e0000 17 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8422644 0x00000800 11 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8422658 0x00000002 1 0x1
    DDRC_CONFIG_FIELD_WRITE 0xf8422204 0x00000800 11 0x0
    DDRC_CONFIG_FIELD_WRITE 0xf8422014 0x00000004 2 0x0
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000201 0 0x201
    DDRC_CONFIG_FULL_WRITE 0xf8422004 $InstRegVal
    DDRC_CONFIG_FIELD_WAIT 0xf8422034 0x00000020 5 0x1 -1
    DDRC_CONFIG_FIELD_WAIT 0xf8422004 0x00000001 0 0x0 -1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422200]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x000000CF 0 0xCF
    DDRC_CONFIG_FULL_WRITE 0xf8422200 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422204]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000773 0 0x213
    DDRC_CONFIG_FULL_WRITE 0xf8422204 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000401 0 0x401
    DDRC_CONFIG_FULL_WRITE 0xf8422004 $InstRegVal
    DDRC_CONFIG_FIELD_WAIT 0xf8422034 0x00000040 6 0x1 -1
    DDRC_CONFIG_FIELD_WAIT 0xf8422004 0x00000001 0 0x0 -1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000801 0 0x801
    DDRC_CONFIG_FULL_WRITE 0xf8422004 $InstRegVal
    DDRC_CONFIG_FIELD_WAIT 0xf8422034 0x00000080 7 0x1 -1
    DDRC_CONFIG_FIELD_WAIT 0xf8422004 0x00000001 0 0x0 -1
    set InstRegVal [DDRC_CONFIG_FIELD_READ 0xf84227e0 0x0000ff80 7]
    set TempData0 [expr {$InstRegVal * 3 / 4}]
    set TempData1 [DDRC_CONFIG_FIELD_READ 0xf8422780 0x000001ff 0]
    if {$TempData1 > $TempData0} {
    set TempData1 [DDRC_CONFIG_FIELD_READ 0xf84227c0 0x000f0000 16]
    incr TempData1 1
    DDRC_CONFIG_FIELD_WRITE 0xf84227c0 0x000f0000 16 $TempData1
    DDRC_CONFIG_FIELD_WRITE 0xf8422780 0x000001ff 0 0x0
    }
    set TempData1 [DDRC_CONFIG_FIELD_READ 0xf8422880 0x000001ff 0]
    if {$TempData1 > $TempData0} {
    set TempData1 [DDRC_CONFIG_FIELD_READ 0xf84228c0 0x000f0000 16]
    incr TempData1 1
    DDRC_CONFIG_FIELD_WRITE 0xf84228c0 0x000f0000 16 $TempData1
    DDRC_CONFIG_FIELD_WRITE 0xf8422880 0x000001ff 0 0x0
    }
    set TempData1 [DDRC_CONFIG_FIELD_READ 0xf8422980 0x000001ff 0]
    if {$TempData1 > $TempData0} {
    set TempData1 [DDRC_CONFIG_FIELD_READ 0xf84229c0 0x000f0000 16]
    incr TempData1 1
    DDRC_CONFIG_FIELD_WRITE 0xf84229c0 0x000f0000 16 $TempData1
    DDRC_CONFIG_FIELD_WRITE 0xf8422980 0x000001ff 0 0x0
    }
    set TempData1 [DDRC_CONFIG_FIELD_READ 0xf8422a80 0x000001ff 0]
    if {$TempData1 > $TempData0} {
    set TempData1 [DDRC_CONFIG_FIELD_READ 0xf8422ac0 0x000f0000 16]
    incr TempData1 1
    DDRC_CONFIG_FIELD_WRITE 0xf8422ac0 0x000f0000 16 $TempData1
    DDRC_CONFIG_FIELD_WRITE 0xf8422a80 0x000001ff 0 0x0
    }
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00004001 0 0x4001
    DDRC_CONFIG_FULL_WRITE 0xf8422004 $InstRegVal
    DDRC_CONFIG_FIELD_WAIT 0xf8422034 0x00000400 10 0x1 -1
    DDRC_CONFIG_FIELD_WAIT 0xf8422004 0x00000001 0 0x0 -1
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8422004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00008001 0 0x8001
    DDRC_CONFIG_FULL_WRITE 0xf8422004 $InstRegVal
    DDRC_CONFIG_FIELD_WAIT 0xf8422034 0x00000800 11 0x1 -1
    DDRC_CONFIG_FIELD_WAIT 0xf8422004 0x00000001 0 0x0 -1
    DDRC_CONFIG_REG_INFO 0xf8422034
    DDRC_CONFIG_REG_INFO 0xf84227c0
    DDRC_CONFIG_REG_INFO 0xf8422780
    DDRC_CONFIG_REG_INFO 0xf8422784
    DDRC_CONFIG_REG_INFO 0xf8422788
    DDRC_CONFIG_REG_INFO 0xf842278c
    DDRC_CONFIG_REG_INFO 0xf8422790
    DDRC_CONFIG_REG_INFO 0xf84228c0
    DDRC_CONFIG_REG_INFO 0xf8422880
    DDRC_CONFIG_REG_INFO 0xf8422884
    DDRC_CONFIG_REG_INFO 0xf8422888
    DDRC_CONFIG_REG_INFO 0xf842288c
    DDRC_CONFIG_REG_INFO 0xf8422890
    DDRC_CONFIG_REG_INFO 0xf84229c0
    DDRC_CONFIG_REG_INFO 0xf8422980
    DDRC_CONFIG_REG_INFO 0xf8422984
    DDRC_CONFIG_REG_INFO 0xf8422988
    DDRC_CONFIG_REG_INFO 0xf842298c
    DDRC_CONFIG_REG_INFO 0xf8422990
    DDRC_CONFIG_REG_INFO 0xf8422ac0
    DDRC_CONFIG_REG_INFO 0xf8422a80
    DDRC_CONFIG_REG_INFO 0xf8422a84
    DDRC_CONFIG_REG_INFO 0xf8422a88
    DDRC_CONFIG_REG_INFO 0xf8422a8c
    DDRC_CONFIG_REG_INFO 0xf8422a90
    DDRC_CONFIG_FIELD_WRITE 0xf8422014 0x00000040 6 0x0
    DDRC_CONFIG_FULL_WRITE 0xf8421320 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf84211b0 0x00000051
    DDRC_CONFIG_FIELD_WAIT 0xf84211bc 0x00000001 0 0x1 -1
    DDRC_CONFIG_FULL_WRITE 0xf8421320 0x00000001
    DDRC_CONFIG_FIELD_WAIT 0xf8421324 0x00000001 0 0x1 -1
    DDRC_CONFIG_FIELD_WAIT 0xf8421004 0x00000007 0 0x1 -1
    DDRC_CONFIG_FULL_WRITE 0xf8421320 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf8421060 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf8421030 0x00000080
    DDRC_CONFIG_FULL_WRITE 0xf84211b0 0x00000053
    DDRC_CONFIG_FULL_WRITE 0xf8421320 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf8421060 0x00000000
    DDRC_CONFIG_FULL_WRITE 0xf8421030 0x00000088
    DDRC_CONFIG_FULL_WRITE 0xf8421490 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf8421540 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf84215f0 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf84216a0 0x00000001
    DDRC_CONFIG_FULL_WRITE 0xf8421304 0x00000000
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf840e004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000001 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf840e004 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf840f004]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00000001 0 0x0
    DDRC_CONFIG_FULL_WRITE 0xf840f004 $InstRegVal
    set InstRegVal [DDRC_CONFIG_FULL_READ 0xf8801074]
    DDRC_CONFIG_FIELD_SET InstRegVal 0x00004000 14 0x1
    DDRC_CONFIG_FULL_WRITE 0xf8801074 $InstRegVal
    
}

# (4) config ddr
proc config_ddr { } {
	try {
		if {$::DDRPS_ENABLE == 0 } {
			puts "Info : Config DDR: DDR is disabled"
		}
		
		if {$::DDRPS_ENABLE == 1 } {
			set DFISTAT [expr {[mrw 0xf84211bc] & 0x1}]
			set STAT [expr {[mrw 0xf8421004] & 0x7}]
			
			if {($DFISTAT == 1) && ($STAT != 0)} {
				puts "info : Config DDR, Skip, DDR is ready."
			} else {
				puts "info : DDR initialization... "
                if {([info exists ::DDR_INIT_V2])} {
                    ddr_init_v2
                } else {
                    ddr_init
                }
				puts "info : DDR initialization: Completed"
            }
        } 
		
	} on error {code options} {
		puts $code
		puts $options
		puts "Error : DDR initialization Failed"
	} finally {
	}
}
proc disable_timer_and_release_cur_core { } {
	# get cur core num
	regexp {result\s+([0-9a-fA-F]{8})} [capture "instr_rd 0xc005"] -> hex_str
	set CURCORE 0x$hex_str
	set CURCORE [expr {$CURCORE & 0xff}]
	puts "info : cur core is $CURCORE"

	# write sys reg: disable core timer
	instr_wr 0xdf11 0x0

	puts "info: target select pstap"
	targets dr1m90.pstap

	puts "info: reset release cur core"
	set val [expr {[mrw 0xf8806334] & (~(0x1 << $CURCORE))}]
	mww 0xf8806334 $val

	puts "info: target select cur core"
	targets dr1m90.core.$CURCORE

	# halt cur core
	halt
}

proc platform_init { } {
	halt
	try {
		disable_timer_and_release_cur_core
	} on error {code options} {
		puts $code
		puts $options
		puts "Error : disable_timer_and_release_cur_core Failed"
	} on return {res options} {
		puts $res
		puts $options
		puts "Error : disable_timer_and_release_cur_core Failed"
	} finally {
	}

	try {
		# (1) config psio
		puts "info : Config PSIO register"
		config_psio

		# (2) config clock
		puts "info : Config PLL register"
		config_clock
		
		# (3) config ddr
		config_ddr

		# (4) config ps_pl
		puts "info : Config PS-PL interface register"
		config_ps_pl

		# (5) config peripheral
		puts "info : Config Peripheral register"
		config_peripheral

		# (6) config debug
		puts "info : Config System register"
		config_debug
		config_system
		puts "info : Platfrom initialization Succeed"

	} on error {code options} {
		puts $code
		puts $options
		puts "Error : Platfrom initialization Failed"
	} on return {res options} {
		puts $res
		puts $options
		puts "Error : Platfrom initialization Failed"
	} finally {
	}

}

platform_init
