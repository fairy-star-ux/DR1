#ifndef AL_FD_DDR_INIT_H_
#define AL_FD_DDR_INIT_H_
#ifdef __cplusplus
extern "C" {
#endif
#include "soc_plat.h"
#include "dr1x90_ddrc_init.h"

// Add the following marco to support the old hpf files
#ifndef FD_PARA_DRAM_DRV
#define FD_PARA_DRAM_DRV        40
#endif

#ifndef FD_PARA_DRAM_ODT
#define FD_PARA_DRAM_ODT        40
#endif

#ifndef FD_PARA_HOST_DRV_AC
#define FD_PARA_HOST_DRV_AC     40
#endif

#ifndef FD_PARA_HOST_DRV_DX
#define FD_PARA_HOST_DRV_DX     40
#endif

#ifndef FD_PARA_HOST_ODT_DX
#define FD_PARA_HOST_ODT_DX     40
#endif

typedef struct ddr_params_t
{
    u32 osc_clk          ;
    u32 type             ;
    u32 speed            ; 
    u32 dq_width         ;
    float io_vol         ;
    u32 verf             ;
    u32 pzq              ;
    u32 dram_width       ;
    u32 speed_bin_index  ;
    u32 wdbi             ;
    u32 rdbi             ;
    u32 dram_density     ;
    u32 ecc              ;
    u32 addr_map         ;
    u32 training         ;
    float byte0_ac_dely  ;
    float byte0_dqs_dely ;
    float byte1_ac_dely  ;
    float byte1_dqs_dely ;
    float byte2_ac_dely  ;
    float byte2_dqs_dely ;
    float byte3_ac_dely  ;
    float byte3_dqs_dely ;
    u32 dram_drv         ;
    u32 dram_odt         ;
    u32 host_drv_ac      ;
    u32 host_drv_dx      ;
    u32 host_odt_dx      ;
} ddr_params_t;

// Call dr1x90_ddrc_init(...)
// Used By FSBL
int fd_ddr_init();


#ifdef __cplusplus
}
#endif
#endif
